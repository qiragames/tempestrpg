extends "res://scripts/enemies/forest_gnasher.gd"
## A regional raid boss (M7a, see BossCatalogue). Its kind is its boss ID (so saves and snapshots
## restore it); it is drawn with its catalogue sprite, much larger and tinted. Host: it fights
## inside its arena, bites like any creature, and every few seconds winds up a telegraphed attack
## (BossFx draws the red zones on every peer and resolves them); below 66% and 33% health it
## enters a new phase (faster, more attacks, an immediate ring). When every character has left
## the arena it heals and resets. Its defeat gives every helper personal loot, XP and Zeni.
const BOSS := preload("res://scripts/bosses/boss_catalogue.gd")
const BOSS_ITEMS := preload("res://scripts/bosses/boss_items.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const SOURCES := preload("res://scripts/items/gear_sources.gd")
const DRAWN_SCALE := 2.4
## Personal drops: Epic, Legendary, Mythic weights.
const LOOT_RARITY := [0, 0, 0, 60, 32, 8]

var phase := 0
var _attack_in := 3.0
var _dash_to := Vector2.INF
var _attack_rng := RandomNumberGenerator.new()

func _ready() -> void:
    kind = entity_id
    # The parent draws sprite_kind() (the boss's catalogue sprite).
    super._ready()
    _attack_rng.randomize()
    add_to_group("raid_bosses")
    set_difficulty(Difficulty.ELITE)
    detection_radius = BOSS.radius(entity_id)
    leash_radius = BOSS.radius(entity_id)
    attack_range = 34.0
    $CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
    $CollisionShape2D.shape.radius = 14.0

func sprite_kind() -> String:
    return BOSS.RAID[entity_id][2] if BOSS.is_boss(entity_id) else "gnasher"

func boss_name() -> String:
    return BOSS.display_name(entity_id)

## Elite stats at the boss's level, times the catalogue's factors.
func set_difficulty(value: int) -> void:
    difficulty = Difficulty.ELITE if value != Difficulty.ELITE else value
    level = BOSS.level(entity_id)
    health.maximum = full_health(1)
    health.current = health.maximum
    restore_stats()
    queue_redraw()

func full_health(characters: int) -> int:
    return int(round(scaled_health(Difficulty.ELITE, level) * BOSS.HEALTH_FACTOR * (1.0 + BOSS.GROUP_BONUS * maxi(0, characters - 1))))

func restore_stats() -> void:
    level = BOSS.level(entity_id)
    damage = int(round(scaled_damage(Difficulty.ELITE, level) * BOSS.DAMAGE_FACTOR))
    speed = 62.0
    phase = BOSS.phase_for(float(health.current) / float(maxi(1, health.maximum)))

## Characters inside the arena (alive).
func challengers() -> Array:
    var centre := BOSS.centre(entity_id)
    var reach := BOSS.radius(entity_id) + BOSS.LEASH_MARGIN
    return get_tree().get_nodes_in_group("player").filter(func(actor): return actor.get_node("Health").current > 0 and actor.global_position.distance_to(centre) <= reach)

func _scale_for_group() -> void:
    if _group_scaled or health.current < health.maximum:
        return
    _group_scaled = true
    health.maximum = full_health(clampi(challengers().size(), 1, 8))
    health.current = health.maximum
    health.changed.emit(health.current, health.maximum)

## Bosses shrug off stuns and roots (slows and damage over time still work).
func apply_status(fx: Dictionary, source: Node) -> void:
    var softened := fx.duplicate()
    softened.erase("stun")
    softened.erase("root")
    super.apply_status(softened, source)

func qualifying() -> Array:
    var total := 0
    for id in credit:
        total += int(credit[id])
    var ranked: Array = []
    for id in credit:
        var share: float = float(credit[id]) / float(total) if total > 0 else 0.0
        if share >= BOSS.HELP_SHARE - 0.000001:
            ranked.append([id, share])
    ranked.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and String(a[0]) < String(b[0])))
    return ranked

func _fx() -> Node:
    return get_parent().get("boss_fx") if get_parent() != null else null

func _physics_process(delta: float) -> void:
    if not AUTHORITY.can_mutate(self) or state == State.DEFEATED:
        return
    var inside := challengers()
    # Everyone left: heal, go home, forget the fight.
    if inside.is_empty():
        if _group_scaled or health.current < health.maximum or not credit.is_empty():
            _reset()
        super._physics_process(delta)
        return
    # A dash (charge) in progress.
    if _dash_to != Vector2.INF:
        var step := 520.0 * delta
        if global_position.distance_to(_dash_to) <= step:
            global_position = _dash_to
            _dash_to = Vector2.INF
        else:
            velocity = global_position.direction_to(_dash_to) * 520.0
            move_and_slide()
            if get_slide_collision_count() > 0:
                _dash_to = Vector2.INF
        return
    var now_phase := BOSS.phase_for(float(health.current) / float(maxi(1, health.maximum)))
    if now_phase > phase:
        phase = now_phase
        _announce_near(inside, "%s grows furious! (phase %d)" % [BOSS.RAID[entity_id][0], phase + 1])
        _start_attack("ring")
        return
    if state == State.WINDUP and state_time > 0.0 and _attack_in > 900.0:
        # Standing still while a telegraphed attack winds up.
        state_time = maxf(0.0, state_time - delta)
        if state_time <= 0.0:
            state = State.RECOVER
            state_time = 0.6
            _attack_in = BOSS.ATTACK_GAP[phase]
        return
    _attack_in -= delta
    if _attack_in <= 0.0 and state != State.WINDUP:
        var attacks: Array = BOSS.RAID[entity_id][7]
        var unlocked: int = clampi(2 + phase, 1, attacks.size())
        _start_attack(attacks[_attack_rng.randi_range(0, unlocked - 1)])
        return
    super._physics_process(delta)

## Telegraph an attack: red zones now, damage when the wind-up ends (BossFx resolves it).
func _start_attack(attack: String) -> void:
    var fx: Node = _fx()
    if fx == null:
        return
    var spec: Array = BOSS.ATTACKS[attack]
    var windup: float = float(spec[0]) * (1.0 if phase == 0 else 0.85)
    var hit := int(round(damage * float(spec[1])))
    var size: float = spec[2]
    var target_actor: Node2D = _nearest_player()
    match attack:
        "slam":
            fx.add_zone(self, "circle", global_position, size, Vector2.ZERO, windup, hit)
        "ring":
            fx.add_zone(self, "ring", global_position, size, Vector2(size * 0.4, 0), windup, hit)
        "rain":
            for actor in challengers():
                fx.add_zone(self, "circle", actor.global_position, size, Vector2.ZERO, windup, hit)
        "charge":
            var aim: Vector2 = target_actor.global_position if is_instance_valid(target_actor) else global_position + Vector2.RIGHT * 100.0
            var direction := global_position.direction_to(aim)
            var end := global_position + direction * minf(200.0, global_position.distance_to(aim) + 40.0)
            fx.add_zone(self, "line", global_position, size, end, windup, hit)
            fx.on_resolve(self, func(): _dash_to = end)
    velocity = Vector2.ZERO
    state = State.WINDUP
    state_time = windup
    _attack_in = 999.0

func _reset() -> void:
    credit = {}
    _group_scaled = false
    health.maximum = full_health(1)
    health.current = health.maximum
    health.changed.emit(health.current, health.maximum)
    phase = 0
    _attack_in = 3.0
    _dash_to = Vector2.INF
    state = State.IDLE
    var fx: Node = _fx()
    if fx != null:
        fx.clear_boss(self)

func _announce_near(actors: Array, message: String) -> void:
    var session: Node = get_node_or_null("/root/GameSession")
    if session == null:
        return
    for actor in actors:
        session.notify_character(actor.character_id, message)

## Every helper: XP, Zeni and a personal drop (a unique or Epic+ gear); everyone hears of it.
func _defeat() -> void:
    if not AUTHORITY.can_mutate(self) or state == State.DEFEATED:
        return
    state = State.DEFEATED
    velocity = Vector2.ZERO
    $CollisionShape2D.set_deferred("disabled", true)
    var fx: Node = _fx()
    if fx != null:
        fx.clear_boss(self)
    var world := get_parent()
    var ranked := qualifying()
    _drop_magicules.call_deferred(ranked)
    var rng: RandomNumberGenerator = world.loot_rng if world != null and world.get("loot_rng") != null else _attack_rng
    var uniques: Array = BOSS.RAID[entity_id][8]
    var index := 0
    for entry in ranked:
        var actor: Node = world.player_by_id(entry[0]) if world != null and world.has_method("player_by_id") else null
        if not is_instance_valid(actor):
            continue
        actor.gain_experience(LEVELING.defeat_xp(level, Difficulty.ELITE) * BOSS.XP_FACTOR, "boss")
        actor.gain_zeni(TRADE.zeni_for(level, Difficulty.ELITE) * BOSS.ZENI_FACTOR, "boss")
        var item: Dictionary
        if rng.randf() < BOSS.UNIQUE_CHANCE and not uniques.is_empty():
            var base: String = uniques[rng.randi_range(0, uniques.size() - 1)]
            var rarity: int = maxi(int(GEAR.BASES[base].min_rarity), 4 if rng.randf() < 0.7 else 5)
            item = GEAR.roll(base, rarity, rng)
        else:
            item = SOURCES._item(rng, LOOT_RARITY, level)
        # Personal loot: only this helper can pick it up (for a long while).
        var spot := position + Vector2.from_angle(TAU * index / maxf(1.0, ranked.size())) * 26.0
        if world.has_method("drop_gear"):
            world.drop_gear.call_deferred(item, spot, "", actor.character_id, (world.progression.get("world_time", 0.0) + 1800.0))
        index += 1
    if world != null and world.has_method("_announce"):
        world._announce("%s has fallen!" % BOSS.RAID[entity_id][0])
    queue_redraw()

## Runs on every peer: a big, tinted sprite and its phase glow.
func _process(_delta: float) -> void:
    super._process(_delta)
    if not is_instance_valid(body_sprite):
        return
    var drawn: float = 1.0 if SPRITES.is_side(sprite_kind()) and sprite_kind() != "gnasher" and sprite_kind() != "thornback" else DRAWN_SCALE
    body_sprite.scale = Vector2.ONE * drawn
    body_sprite.position.y = SPRITES.FEET_Y * (1.0 - drawn)
    if state == State.DEFEATED:
        return
    var tint: Color = BOSS.RAID[entity_id][6] if BOSS.is_boss(entity_id) else Color.WHITE
    if state == State.WINDUP:
        tint = Color(1.0, 0.45, 0.4)
    body_sprite.modulate = tint

func _draw() -> void:
    if state == State.DEFEATED or not is_instance_valid(health):
        return
    var width := 48.0
    draw_rect(Rect2(-width / 2.0, -52, width, 4), Color("352d36"))
    draw_rect(Rect2(-width / 2.0, -52, width * health.current / maxi(1, health.maximum), 4), Color("e05a4a"))
    draw_string(ThemeDB.fallback_font, Vector2(-width / 2.0, -56), "Lv %d %s" % [level, BOSS.RAID[entity_id][0] if BOSS.is_boss(entity_id) else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.8, 0.6))
