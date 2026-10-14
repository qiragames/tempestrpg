extends CharacterBody2D
const AUTHORITY := preload("res://scripts/network/authority.gd")
## Simple local encounter AI. Navigation around complex terrain comes later.

enum State { IDLE, CHASE, WINDUP, RECOVER, DEFEATED }
enum Difficulty { EASY, STANDARD, ELITE }
const TIER_STATS := {
    Difficulty.EASY: {"health": 20, "damage": 8, "speed": 45.0, "drop": 8.0, "absorb_heal": 15.0},
    Difficulty.STANDARD: {"health": 30, "damage": 12, "speed": 55.0, "drop": 16.0, "absorb_heal": 25.0},
    Difficulty.ELITE: {"health": 60, "damage": 20, "speed": 65.0, "drop": 32.0, "absorb_heal": 40.0},
}
const PICKUP_SCENE := preload("res://scenes/pickups/magicule_pickup.tscn")
const LEVELING := preload("res://scripts/progression/leveling.gd")
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
const REGION := preload("res://scripts/world/region_content.gd")
const CLAIM := preload("res://scripts/pickups/claim.gd")
## 24a (user decisions): characters with at least this share of a creature's damage get its full
## XP, may absorb it and take part in its loot; loot goes out by damage rank.
const CREDIT_SHARE := 0.1
## Extra HP per additional living character within GROUP_RADIUS when a fight starts (max 8).
const GROUP_HP_BONUS := 0.25
const GROUP_RADIUS := 300.0
## Sprites are drawn smaller than the art (it is ~26 px tall next to 16 px characters).
const SPRITE_SCALE := 0.75
const ELITE_SPRITE_SCALE := 0.85
## Character id -> damage dealt (host only; a respawned creature starts fresh).
var credit: Dictionary = {}
## Level from RegionContent (shown above the health bar).
var level: int = 1
var _group_scaled := false
## Tier tints: Easy creatures look paler, Elites redder and a little larger.
const TIER_TINT := {0: Color(0.82, 1.0, 0.82), 1: Color.WHITE, 2: Color(1.0, 0.72, 0.72)}
var body_sprite: AnimatedSprite2D
var _last_position := Vector2.INF
@export var difficulty: Difficulty = Difficulty.STANDARD
@export var specimen: Resource = preload("res://data/specimens/forest_gnasher.tres")
## Stable saved creature kind; selects the scene on restore (see StateCodec.ENEMY_SCENES).
@export var kind: String = "gnasher"
## Trial creatures drop nothing (and carry no specimen) so trials cannot be farmed.
@export var drops_rewards: bool = true
var being_analyzed: bool = false
@export var entity_id: String = ""
var speed: float = 55.0
@export var detection_radius: float = 180.0
@export var leash_radius: float = 220.0
@export var attack_range: float = 24.0
var damage: int = 12
var state: State = State.IDLE
var state_time: float = 0.0
var home: Vector2
@onready var health = $Health
var target: CharacterBody2D

func _ready() -> void:
    add_to_group("enemies")
    if entity_id.is_empty():
        entity_id = "enemy_" + Crypto.new().generate_random_bytes(16).hex_encode()
    set_difficulty(difficulty)
    home = global_position
    body_sprite = SPRITES.make(kind if SPRITES.has_set(kind) else "gnasher")
    add_child(body_sprite)
    health.changed.connect(func(_current: int, _maximum: int): queue_redraw())
    health.defeated.connect(_defeat)
    health.damaged.connect(_credit)
    level = REGION.level_of(entity_id, int(difficulty))

func _credit(amount: int, source: Node) -> void:
    if is_instance_valid(source) and source.is_in_group("player") and amount > 0:
        credit[source.character_id] = int(credit.get(source.character_id, 0)) + amount

## [character id, share] of everyone with at least CREDIT_SHARE of the damage, most damage first.
func qualifying() -> Array:
    var total := 0
    for id in credit:
        total += int(credit[id])
    var ranked: Array = []
    for id in credit:
        var share: float = float(credit[id]) / float(total) if total > 0 else 0.0
        if share >= CREDIT_SHARE - 0.000001:
            ranked.append([id, share])
    ranked.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and String(a[0]) < String(b[0])))
    return ranked

## Absorbing needs a share of the damage (anyone may absorb a creature no character hurt).
func may_absorb(character_id: String) -> bool:
    return credit.is_empty() or qualifying().any(func(entry): return entry[0] == character_id)

## When a fight starts at full health, more HP for each extra character nearby.
func _scale_for_group() -> void:
    if _group_scaled or health.current < health.maximum:
        return
    _group_scaled = true
    var nearby := 0
    for actor in get_tree().get_nodes_in_group("player"):
        if actor.get_node("Health").current > 0 and actor.global_position.distance_to(global_position) <= GROUP_RADIUS:
            nearby += 1
    var extra: int = clampi(nearby, 1, 8) - 1
    if extra > 0:
        health.maximum = int(round(TIER_STATS[difficulty].health * (1.0 + GROUP_HP_BONUS * extra)))
        health.current = health.maximum
        health.changed.emit(health.current, health.maximum)

## Apply a tier's stats at full health (fresh creatures; restores set health from the save).
func set_difficulty(value: int) -> void:
    difficulty = value
    var stats: Dictionary = TIER_STATS[difficulty]
    health.maximum = stats.health
    health.current = health.maximum
    damage = stats.damage
    speed = stats.speed
    queue_redraw()

func _physics_process(delta: float) -> void:
    if not AUTHORITY.can_mutate(self):
        return
    velocity = Vector2.ZERO
    state_time = maxf(0.0, state_time - delta)
    if state == State.DEFEATED:
        return
    if state != State.WINDUP or not is_instance_valid(target) or not target.is_inside_tree():
        target = _nearest_player()
    if not is_instance_valid(target):
        state = State.IDLE
        if global_position.distance_to(home) > 3.0:
            velocity = global_position.direction_to(home) * speed
            move_and_slide()
        return
    var distance := global_position.distance_to(target.global_position)
    var target_alive: bool = target.get_node("Health").current > 0
    var nearby: bool = distance <= detection_radius and target.global_position.distance_to(home) <= leash_radius
    match state:
        State.IDLE:
            if nearby and target_alive:
                _scale_for_group()
                state = State.CHASE
            elif global_position.distance_to(home) > 3.0:
                velocity = global_position.direction_to(home) * speed
        State.CHASE:
            if not nearby or not target_alive:
                state = State.IDLE
            elif distance <= attack_range:
                state = State.WINDUP
                state_time = 0.35
            else:
                velocity = global_position.direction_to(target.global_position) * speed
        State.WINDUP:
            if state_time <= 0.0:
                var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
                if target_alive and distance <= attack_range and get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
                    target.get_node("Health").take_damage(damage, self)
                state = State.RECOVER
                state_time = 0.9
        State.RECOVER:
            if state_time <= 0.0:
                state = State.IDLE
    move_and_slide()
    queue_redraw()

func _defeat() -> void:
    if not AUTHORITY.can_mutate(self):
        return
    if state == State.DEFEATED:
        return
    state = State.DEFEATED
    add_to_group("absorbable_creatures")
    velocity = Vector2.ZERO
    $CollisionShape2D.set_deferred("disabled", true)
    # Defer creation because defeat can originate during a physics callback.
    if drops_rewards:
        var world := get_parent()
        var ranked := qualifying()
        # Magicules split by damage share into personal pickups (one unowned pickup if no
        # character took part); everyone with a share gets the full XP (24a).
        _drop_magicules.call_deferred(ranked)
        # One gear roll (17g); its item goes to the top damage dealer.
        if world != null and world.has_method("drop_gear"):
            var item: Dictionary = world.SOURCES.roll_drop(difficulty, world.loot_rng)
            if not item.is_empty():
                world.drop_gear.call_deferred(item, position + Vector2(10, 6), "", ranked[0][0] if not ranked.is_empty() else "")
        var rewarded := false
        for entry in ranked:
            var actor: Node = world.player_by_id(entry[0]) if world != null and world.has_method("player_by_id") else null
            if is_instance_valid(actor):
                actor.gain_experience(LEVELING.DEFEAT_XP[difficulty], "defeat")
                rewarded = true
        # A creature no character damaged keeps the old last-hit rule.
        var victor: Node = health.last_hit_by
        if not rewarded and is_instance_valid(victor) and victor.is_in_group("player"):
            victor.gain_experience(LEVELING.DEFEAT_XP[difficulty], "defeat")
    # Retain the defeated creature for the next absorption milestone.
    queue_redraw()

func _drop_magicules(ranked: Array = []) -> void:
    # Deferred: the creature may have been removed in the same frame (e.g. a respawn replaced it).
    if not is_inside_tree():
        return
    var world := get_parent()
    var shares: Array = ranked if not ranked.is_empty() else [["", 1.0]]
    var total_share := 0.0
    for entry in shares:
        total_share += float(entry[1])
    for index in range(shares.size()):
        var pickup = PICKUP_SCENE.instantiate()
        pickup.amount = TIER_STATS[difficulty].drop * float(shares[index][1]) / total_share
        # Respawned creatures reuse their ID, so each drop gets its own suffix.
        pickup.entity_id = "drop_%s_%s" % [entity_id, Crypto.new().generate_random_bytes(4).hex_encode()]
        pickup.position = position + Vector2(index * 8 - (shares.size() - 1) * 4, 0)
        pickup.owner_id = shares[index][0]
        pickup.claim_until = CLAIM.until(world) if not String(pickup.owner_id).is_empty() else 0.0
        if world.has_method("announce_magicule_pickup"):
            pickup.collected_by.connect(world.announce_magicule_pickup)
        world.add_child(pickup)

func _nearest_player() -> CharacterBody2D:
    var nearest: CharacterBody2D
    var distance: float = detection_radius + 1.0
    for actor in get_tree().get_nodes_in_group("player"):
        if actor.get_node("Health").current <= 0:
            continue
        var candidate: float = global_position.distance_to(actor.global_position)
        if candidate < distance:
            nearest = actor
            distance = candidate
    return nearest

## Runs on every peer (replicas only see positions and state).
func _process(_delta: float) -> void:
    if not is_instance_valid(body_sprite):
        return
    var moved: bool = _last_position != Vector2.INF and position.distance_to(_last_position) > 0.05
    if moved:
        body_sprite.flip_h = position.x < _last_position.x
    elif is_instance_valid(target):
        body_sprite.flip_h = target.position.x < position.x
    _last_position = position
    var drawn: float = ELITE_SPRITE_SCALE if difficulty == Difficulty.ELITE else SPRITE_SCALE
    body_sprite.scale = Vector2.ONE * drawn
    # Keep the feet where they were at full size.
    body_sprite.position.y = SPRITES.FEET_Y * (1.0 - drawn)
    if state == State.DEFEATED:
        body_sprite.modulate = Color(0.5, 1.0, 1.0) if being_analyzed else Color(0.85, 0.85, 0.85)
        SPRITES.play(body_sprite, "death")
        return
    # The wind-up flashes red so players can read the coming bite.
    body_sprite.modulate = Color(1.0, 0.45, 0.4) if state == State.WINDUP else TIER_TINT[difficulty]
    SPRITES.play(body_sprite, "run" if moved or state == State.CHASE else "idle")

func _draw() -> void:
    if is_instance_valid(body_sprite):
        if state != State.DEFEATED and is_instance_valid(health):
            draw_rect(Rect2(-12, -22, 24, 3), Color("352d36"))
            draw_rect(Rect2(-12, -22, 24.0 * health.current / health.maximum, 3), Color("c6d58a"))
            draw_string(ThemeDB.fallback_font, Vector2(-12, -25), "Lv %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.92, 0.75, 0.95))
        return
    if state == State.DEFEATED:
        draw_rect(Rect2(-10, 0, 20, 5), Color("71e4d4") if being_analyzed else Color("656653"))
        return
    var color := Color("d7b16d") if state != State.WINDUP else Color("f08065")
    if state != State.WINDUP and difficulty == Difficulty.ELITE:
        color = Color("b99fd5")
    elif state != State.WINDUP and difficulty == Difficulty.EASY:
        color = Color("99b87d")
    if kind == "thornback" and state != State.WINDUP:
        color = Color("8f7fb0")
    draw_rect(Rect2(-9, -8, 18, 14), color)
    if kind == "thornback":
        # Quills along the back distinguish the variant from ordinary Gnashers.
        for x in [-7, -2, 3]:
            draw_colored_polygon(PackedVector2Array([Vector2(x, -8), Vector2(x + 2, -15), Vector2(x + 4, -8)]), Color("e8dcc0"))
    draw_rect(Rect2(-11, -12, 5, 8), color)
    draw_rect(Rect2(6, -12, 5, 8), color)
    draw_rect(Rect2(-6, -4, 3, 3), Color("352d36"))
    draw_rect(Rect2(3, -4, 3, 3), Color("352d36"))
    draw_rect(Rect2(-4, 2, 8, 3), Color("f4edca"))
    if is_instance_valid(health):
        draw_rect(Rect2(-12, -19, 24, 3), Color("352d36"))
        draw_rect(Rect2(-12, -19, 24.0 * health.current / health.maximum, 3), Color("c6d58a"))
