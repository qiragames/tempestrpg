extends Node2D
## Armies (M11h, user request, lowest priority): your nation trains soldiers. Inside your village a
## character recruits them for Zeni (two per nation tier for the whole world); each soldier follows
## the character who recruited them and fights creatures near it. Orders (the army window, C):
## Follow me, Hold here, Charge (the nearest creature in sight). Soldiers rise in rank from their
## defeats (Recruit → Veteran → Champion: more health and damage); a fallen soldier recovers at the
## camp after two minutes. Sieges on the village grow with the army (larger invasions).
## Host-authoritative; the soldiers live in the world's progression ("army": {"soldiers": [...],
## "serial": n}) — saved, and sent to every peer, which draws them.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
const GNASHER := preload("res://scripts/enemies/forest_gnasher.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")

const PER_TIER := 2
const MAX_SOLDIERS := 10
## Zeni per soldier: this much per recruiting character's level (at least 300).
const PRICE_PER_LEVEL := 60
const RANKS := [["Recruit", 0, 1.0], ["Veteran", 10, 1.4], ["Champion", 30, 1.9]]
const SPEED := 80.0
const REACH := 22.0
const SIGHT := 150.0
const ATTACK_SECONDS := 1.0
const DOWN_SECONDS := 120.0
const ORDERS := ["follow", "hold", "charge"]
const LOOKS := ["gi_fighter", "citizen_2", "citizen_5"]

var world: Node2D
var _bodies: Dictionary = {}
var _cooldowns: Dictionary = {}

func _init(owner_world: Node2D = null) -> void:
    world = owner_world
    name = "Army"
    y_sort_enabled = true

func session() -> Node:
    return get_node("/root/GameSession")

func state() -> Dictionary:
    if not world.progression.get("army") is Dictionary:
        world.progression["army"] = {"soldiers": [], "serial": 0}
    return world.progression.army

func soldiers_of(id: String) -> Array:
    return state().soldiers.filter(func(soldier): return soldier.owner == id)

func capacity() -> int:
    var camp: Node = world.get("camp")
    if camp == null or not camp.state.founded:
        return 0
    return mini(MAX_SOLDIERS, PER_TIER * maxi(1, camp.tier()))

func price(actor: Node) -> int:
    return maxi(300, PRICE_PER_LEVEL * int(actor.progression.get("level", 1)))

static func rank_of(soldier: Dictionary) -> Array:
    var best: Array = RANKS[0]
    for rank in RANKS:
        if int(soldier.get("kills", 0)) >= int(rank[1]):
            best = rank
    return best

## Health and damage of a soldier at its level and rank.
static func stats(soldier: Dictionary) -> Array:
    var factor: float = float(rank_of(soldier)[2])
    var level := int(soldier.level)
    return [int(round(GNASHER.scaled_health(1, level) * 1.5 * factor)), int(round(GNASHER.scaled_damage(1, level) * 1.2 * factor))]

## --- Host operations (the "army" intent).
func recruit(actor: Node2D) -> bool:
    if not AUTHORITY.can_mutate(actor):
        return false
    var camp: Node = world.get("camp")
    if camp == null or not camp.state.founded or not camp.in_settlement(actor.global_position):
        session().notify_character(actor.character_id, "Soldiers are recruited inside your nation's village.")
        return false
    if state().soldiers.size() >= capacity():
        session().notify_character(actor.character_id, "Your nation can field %d soldiers (two per tier). Grow the nation for more." % capacity())
        return false
    if not actor.spend_zeni(price(actor)):
        session().notify_character(actor.character_id, "A soldier costs %d Zeni." % price(actor))
        return false
    state().serial = int(state().serial) + 1
    var soldier := {"id": "soldier_%d" % int(state().serial), "owner": actor.character_id, "level": int(actor.progression.get("level", 1)), "kills": 0, "order": "follow", "anchor": [actor.global_position.x, actor.global_position.y], "pos": [actor.global_position.x + 12.0, actor.global_position.y + 8.0], "hp": 0, "down": 0.0, "look": int(state().serial) % LOOKS.size()}
    soldier.hp = stats(soldier)[0]
    state().soldiers.append(soldier)
    session().notify_character(actor.character_id, "A recruit joins your army (%d / %d)." % [state().soldiers.size(), capacity()])
    session().queue_save()
    return true

func command(actor: Node2D, order: String) -> bool:
    if not AUTHORITY.can_mutate(actor) or not order in ORDERS or soldiers_of(actor.character_id).is_empty():
        return false
    for soldier in soldiers_of(actor.character_id):
        soldier.order = order
        soldier.anchor = [actor.global_position.x, actor.global_position.y]
    session().notify_character(actor.character_id, {"follow": "Soldiers: follow me!", "hold": "Soldiers: hold this ground!", "charge": "Soldiers: charge!"}[order])
    return true

func dismiss(actor: Node2D) -> bool:
    if not AUTHORITY.can_mutate(actor) or soldiers_of(actor.character_id).is_empty():
        return false
    state().soldiers = state().soldiers.filter(func(soldier): return soldier.owner != actor.character_id)
    session().notify_character(actor.character_id, "Your soldiers return to their homes.")
    session().queue_save()
    return true

## --- Host simulation.
func _physics_process(delta: float) -> void:
    if world == null or session().replica_world:
        return
    var camp: Node = world.get("camp")
    for soldier in state().soldiers:
        var at := Vector2(float(soldier.pos[0]), float(soldier.pos[1]))
        if float(soldier.down) > 0.0:
            soldier.down = maxf(0.0, float(soldier.down) - delta)
            if float(soldier.down) <= 0.0:
                soldier.hp = stats(soldier)[0]
                var home: Vector2 = camp.SITE if camp != null else at
                soldier.pos = [home.x, home.y + 20.0]
            continue
        var leader: Node2D = world.player_by_id(String(soldier.owner))
        var anchor := Vector2(float(soldier.anchor[0]), float(soldier.anchor[1]))
        if soldier.order == "follow" and leader != null:
            anchor = leader.global_position
            soldier.anchor = [anchor.x, anchor.y]
        var foe: Node2D = _target(at, anchor if soldier.order != "charge" else at, SIGHT * (2.0 if soldier.order == "charge" else 1.0))
        var goal: Vector2 = anchor + Vector2(12, 10).rotated(float(int(String(soldier.id).trim_prefix("soldier_")) % 6) * 1.05)
        if foe != null:
            goal = foe.global_position
            if at.distance_to(goal) <= REACH:
                var key := String(soldier.id)
                if float(_cooldowns.get(key, 0.0)) <= 0.0:
                    _cooldowns[key] = ATTACK_SECONDS
                    var health: Node = foe.get_node("Health")
                    var damage: int = stats(soldier)[1]
                    health.take_damage(damage, leader if leader != null else null)
                    if health.current <= 0:
                        soldier.kills = int(soldier.kills) + 1
                        var before: String = String(rank_of({"kills": int(soldier.kills) - 1})[0])
                        if String(rank_of(soldier)[0]) != before and leader != null:
                            session().notify_character(leader.character_id, "A soldier rose to %s!" % rank_of(soldier)[0])
                # Creatures in a melee hit back.
                soldier.hp = int(soldier.hp) - int(maxf(1.0, float(foe.get("damage")) * 0.5)) if randf() < delta * 1.5 else int(soldier.hp)
                if int(soldier.hp) <= 0:
                    soldier.down = DOWN_SECONDS
                    if leader != null:
                        session().notify_character(leader.character_id, "A soldier fell; they recover at the camp in two minutes.")
                    continue
        var gap: float = at.distance_to(goal)
        if gap > 4.0:
            if gap > 900.0 and leader != null and soldier.order == "follow":
                at = leader.global_position + Vector2(10, 10)
            else:
                at = at.move_toward(goal, SPEED * delta * (1.6 if gap > 200.0 else 1.0))
            soldier.pos = [at.x, at.y]
    for key in _cooldowns.keys():
        _cooldowns[key] = float(_cooldowns[key]) - delta

func _target(at: Vector2, centre: Vector2, sight: float) -> Node2D:
    var best: Node2D = null
    var distance := INF
    for creature in get_tree().get_nodes_in_group("enemies"):
        if creature.get_node("Health").current <= 0 or (creature.has_method("dormant") and creature.dormant()):
            continue
        var gap: float = creature.global_position.distance_to(centre)
        if gap <= sight and creature.global_position.distance_to(at) < distance:
            best = creature
            distance = creature.global_position.distance_to(at)
    return best

## --- Every peer: the soldiers' bodies.
func _process(_delta: float) -> void:
    if world == null:
        return
    var seen := {}
    for soldier in state().soldiers:
        var id := String(soldier.id)
        seen[id] = true
        var body: Node2D = _bodies.get(id)
        if body == null:
            body = Node2D.new()
            var sprite := SPRITES.make(LOOKS[int(soldier.get("look", 0)) % LOOKS.size()])
            sprite.name = "Sprite"
            body.add_child(sprite)
            add_child(body)
            _bodies[id] = body
        var target := Vector2(float(soldier.pos[0]), float(soldier.pos[1]))
        var moving: bool = body.position.distance_to(target) > 0.5
        if moving and absf(target.x - body.position.x) > 0.1:
            body.get_node("Sprite").flip_h = target.x < body.position.x
        body.position = target
        body.visible = float(soldier.down) <= 0.0
        var rank: String = String(rank_of(soldier)[0])
        body.modulate = Color(1.0, 0.85, 0.55) if rank == "Champion" else (Color(0.8, 0.9, 1.0) if rank == "Veteran" else Color.WHITE)
        SPRITES.play(body.get_node("Sprite"), "walk_down" if moving else "idle_down")
    for id in _bodies.keys():
        if not seen.has(id):
            _bodies[id].queue_free()
            _bodies.erase(id)
