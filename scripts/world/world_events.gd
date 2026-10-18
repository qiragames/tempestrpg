extends Node2D
## World events (M11d, user request): every so often something happens near the players —
##   meteor shower: red circles warn where meteors strike (they hurt whoever stands there); each
##     leaves a glowing meteorite to collect (F) for star metal, a gem, Zeni and XP;
##   town invasion: creatures of the region march on the nearest town's plaza; defeat them all in
##     time and everyone near the town is rewarded (Zeni, XP, a Rare-or-better piece);
##   treasure goblin: a goblin with a sack of gold appears and runs from everyone; catch it before
##     it escapes for a heap of Zeni and an Epic-or-better piece.
## Host-authoritative; the event's state reaches every peer with the snapshots (it is never saved:
## a reload calls it off). Event creatures (ids "event_…") are not saved and do not respawn.
const MAP := preload("res://scripts/world/world_map.gd")
const REGION := preload("res://scripts/world/region_content.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const GNASHER := preload("res://scripts/enemies/forest_gnasher.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
const AUTHORITY := preload("res://scripts/network/authority.gd")

const KINDS := ["meteors", "invasion", "goblin"]
const NAMES := {"meteors": "Meteor shower", "invasion": "Town invasion", "goblin": "Treasure goblin"}
## Seconds before the first event and between events (random within the range).
const FIRST_DELAY := 900.0
const GAP := [600.0, 1200.0]
const DURATION := {"meteors": 75.0, "invasion": 180.0, "goblin": 45.0}
const METEORS := 6
const METEOR_WARN := 2.5
const METEOR_RADIUS := 30.0
const METEOR_DAMAGE := 0.2
const COLLECT_REACH := 26.0
const INVADERS := 8
const GOBLIN_SPEED := 72.0

var world: Node2D
var state: Dictionary = initial_state()
var _rng := RandomNumberGenerator.new()

static func initial_state() -> Dictionary:
    return {"kind": "", "clock": 0.0, "next": FIRST_DELAY, "at": [0.0, 0.0], "town": "", "meteors": [], "serial": 0}

func _init(owner_world: Node2D = null) -> void:
    world = owner_world
    name = "WorldEvents"
    z_index = 4
    _rng.randomize()

func session() -> Node:
    return get_node("/root/GameSession")

func capture() -> Dictionary:
    return state.duplicate(true)

func restore(value: Dictionary) -> void:
    state = value.duplicate(true)

func active() -> bool:
    return not String(state.kind).is_empty()

func creatures() -> Array:
    return get_tree().get_nodes_in_group("enemies").filter(func(node): return String(node.entity_id).begins_with("event_") and not node.is_queued_for_deletion())

func _alive() -> Array:
    return creatures().filter(func(node): return node.get_node("Health").current > 0)

func _players() -> Array:
    return get_tree().get_nodes_in_group("player").filter(func(actor): return actor.get_parent() == world and actor.get_node("Health").current > 0)

func _tell_all(message: String) -> void:
    for actor in get_tree().get_nodes_in_group("player"):
        if actor.get_parent() == world:
            session().notify_character(actor.character_id, message)

func at() -> Vector2:
    return Vector2(float(state.at[0]), float(state.at[1]))

## The HUD line while an event runs ("" otherwise).
func banner() -> String:
    if not active():
        return ""
    var left := int(ceil(float(state.clock)))
    match String(state.kind):
        "meteors":
            return "☄ Meteor shower nearby — collect the meteorites (F) · %d:%02d" % [left / 60, left % 60]
        "invasion":
            return "⚔ %s is under attack: %d invaders left · %d:%02d" % [MAP.town(state.town)[1] if not MAP.town(state.town).is_empty() else "A town", _alive().size(), left / 60, left % 60]
        "goblin":
            return "💰 A treasure goblin is running loose — catch it! · %d:%02d" % [left / 60, left % 60]
    return ""

## --- Host.
func _physics_process(delta: float) -> void:
    if world == null or session().replica_world or not session().active:
        return
    if not active():
        if _players().is_empty():
            return
        state.next = float(state.next) - delta
        if float(state.next) <= 0.0:
            start(KINDS[_rng.randi_range(0, KINDS.size() - 1)])
        return
    state.clock = float(state.clock) - delta
    match String(state.kind):
        "meteors":
            _meteors(delta)
        "invasion":
            if _alive().is_empty() and float(state.clock) < DURATION.invasion - 1.0:
                _invasion_won()
                return
        "goblin":
            _goblin_run(delta)
    if float(state.clock) <= 0.0:
        _finish(String(state.kind) == "goblin" and not _alive().is_empty() and true)

## Start an event now (tests, the owner's dev menu, or the timer). Returns whether it began.
func start(kind: String, near: Node2D = null) -> bool:
    if active() or not kind in KINDS:
        return false
    var players := _players()
    if near == null and players.is_empty():
        return false
    var target: Node2D = near if near != null else players[_rng.randi_range(0, players.size() - 1)]
    state.kind = kind
    state.clock = DURATION[kind]
    state.meteors = []
    match kind:
        "meteors":
            var centre: Vector2 = _open_near(target.global_position, 140.0)
            state.at = [centre.x, centre.y]
            for index in range(METEORS):
                var spot: Vector2 = _open_near(centre, 110.0)
                state.meteors.append([spot.x, spot.y, METEOR_WARN + index * 1.6, false, false])
            _tell_all("A meteor shower is falling nearby! Stay out of the red circles, then collect the meteorites (F).")
        "invasion":
            var town: Array = _nearest_town(target.global_position)
            if town.is_empty():
                state.kind = ""
                return false
            state.town = town[0]
            var plaza: Vector2 = MAP.to_world(Vector2(town[3])) + Vector2(8, 8)
            state.at = [plaza.x, plaza.y]
            _spawn_invaders(plaza, town)
            _tell_all("%s is under attack! Defeat the invaders before they plunder the town." % town[1])
        "goblin":
            var spot: Vector2 = _open_near(target.global_position, 120.0)
            state.at = [spot.x, spot.y]
            var goblin := _spawn("treasure_goblin", spot, 1, int(target.progression.get("level", 1)))
            goblin.get_node("Health").maximum *= 3
            goblin.get_node("Health").current = goblin.get_node("Health").maximum
            goblin.damage = 0
            _tell_all("A treasure goblin appeared! Catch it before it escapes.")
    state.next = _rng.randf_range(GAP[0], GAP[1])
    return true

func _spawn(kind: String, spot: Vector2, difficulty: int, level: int) -> Node2D:
    var creature = load(CODEC.enemy_scene(kind)).instantiate()
    state.serial = int(state.serial) + 1
    creature.entity_id = "event_%s_%d" % [kind, int(state.serial)]
    creature.kind = kind
    creature.position = spot
    world.add_child(creature)
    world.wire_enemy(creature)
    creature.set_difficulty(difficulty)
    creature.level = level
    creature.get_node("Health").maximum = GNASHER.scaled_health(difficulty, level)
    creature.get_node("Health").current = creature.get_node("Health").maximum
    creature.damage = GNASHER.scaled_damage(difficulty, level)
    return creature

func _spawn_invaders(plaza: Vector2, town: Array) -> void:
    var region: String = MAP.REGION_NAMES[town[2]]
    var kinds: Array = []
    for entry in REGION.CREATURES:
        if MAP.region_name(REGION.at(entry[2])) == region and not entry[1] in kinds:
            kinds.append(entry[1])
    if kinds.is_empty():
        kinds = ["gnasher"]
    var range: Array = REGION.level_range(region if region != "Harrowmere" else "Verdant Isle")
    var level: int = int(range[1]) if not range.is_empty() else 5
    for index in range(INVADERS):
        var spot: Vector2 = _open_near(plaza + Vector2.from_angle(index * TAU / INVADERS) * 220.0, 30.0)
        var creature := _spawn(kinds[index % kinds.size()], spot, 2 if index % 4 == 0 else 1, level)
        creature.home = plaza
        creature.leash_radius = 4000.0

func _nearest_town(from: Vector2) -> Array:
    var best: Array = []
    var distance := INF
    for town in MAP.TOWNS:
        if town[4] != "town":
            continue
        var gap: float = from.distance_to(MAP.to_world(Vector2(town[3])))
        if gap < distance:
            best = town
            distance = gap
    return best if distance < 2400.0 else []

## An open (walkable) spot near a point.
func _open_near(centre: Vector2, radius: float) -> Vector2:
    for _try in range(24):
        var spot: Vector2 = centre + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(radius * 0.3, radius)
        var tile: Vector2i = MAP.to_tile(spot)
        if not MAP.solid(tile.x, tile.y):
            return spot
    return centre

func _meteors(_delta: float) -> void:
    var elapsed: float = DURATION.meteors - float(state.clock)
    for meteor in state.meteors:
        if bool(meteor[3]) or elapsed < float(meteor[2]):
            continue
        meteor[3] = true
        var spot := Vector2(float(meteor[0]), float(meteor[1]))
        for actor in _players():
            if actor.global_position.distance_to(spot) <= METEOR_RADIUS:
                var health: Node = actor.get_node("Health")
                health.take_damage(maxi(1, int(round(health.maximum * METEOR_DAMAGE))), null)
        for creature in get_tree().get_nodes_in_group("enemies"):
            if creature.global_position.distance_to(spot) <= METEOR_RADIUS and creature.get_node("Health").current > 0:
                creature.get_node("Health").take_damage(maxi(1, int(creature.get_node("Health").maximum * 0.3)), null)

## Host: F at a landed meteorite.
func collect(actor: Node2D, index: int) -> bool:
    if not AUTHORITY.can_mutate(actor) or String(state.kind) != "meteors" or index < 0 or index >= state.meteors.size():
        return false
    var meteor: Array = state.meteors[index]
    var spot := Vector2(float(meteor[0]), float(meteor[1]))
    if not bool(meteor[3]) or bool(meteor[4]) or actor.global_position.distance_to(spot) > COLLECT_REACH + 4.0:
        return false
    meteor[4] = true
    var level := int(actor.progression.get("level", 1))
    var bag: Node = actor.get_node("Inventory")
    var got: Array = []
    if bag.add_material("ore_starmetal", 1 + _rng.randi_range(0, 1)) > 0:
        got.append("star metal")
    var gem: String = ["gem_sapphire", "gem_emerald", "gem_ruby"][_rng.randi_range(0, 2)]
    if bag.add_material(gem, 1) > 0:
        got.append(TRADE.good_info(gem)[0])
    var zeni: int = TRADE.zeni_for(level, 1) * 6
    actor.gain_zeni(zeni, "meteorite")
    actor.gain_experience(LEVELING.defeat_xp(level, 1) * 4, "meteorite")
    if world.get("quests") != null:
        world.quests.on_event(actor, "event", {"what": "meteorite"})
    session().notify_character(actor.character_id, "Meteorite: %s and %d Zeni." % [", ".join(got) if not got.is_empty() else "(bag full)", zeni])
    session().queue_save()
    return true

## The meteorite a character stands at (-1 for none).
func nearest_meteorite(actor: Node2D) -> int:
    if String(state.kind) != "meteors":
        return -1
    for index in range(state.meteors.size()):
        var meteor: Array = state.meteors[index]
        if bool(meteor[3]) and not bool(meteor[4]) and actor.global_position.distance_to(Vector2(float(meteor[0]), float(meteor[1]))) <= COLLECT_REACH:
            return index
    return -1

func _invasion_won() -> void:
    var town: Array = MAP.town(state.town)
    for actor in _players():
        if actor.global_position.distance_to(at()) > 700.0:
            continue
        var level := int(actor.progression.get("level", 1))
        actor.gain_zeni(TRADE.zeni_for(level, 2) * 20, "invasion")
        actor.gain_experience(LEVELING.defeat_xp(level, 2) * 15, "invasion")
        _give_gear(actor, 2, level)
        if world.get("quests") != null:
            world.quests.on_event(actor, "event", {"what": "invasion"})
    _tell_all("%s is saved! Its people reward the defenders." % (town[1] if not town.is_empty() else "The town"))
    _clear()

func _goblin_run(delta: float) -> void:
    for goblin in _alive():
        goblin.set_physics_process(false)
        var nearest: Node2D = null
        var gap := INF
        for actor in _players():
            var distance: float = actor.global_position.distance_to(goblin.global_position)
            if distance < gap:
                nearest = actor
                gap = distance
        if nearest == null:
            continue
        var away: Vector2 = (goblin.global_position - nearest.global_position).normalized() if gap < 220.0 else Vector2.from_angle(Time.get_ticks_msec() / 900.0)
        goblin.velocity = away * GOBLIN_SPEED * (1.0 if gap < 220.0 else 0.4)
        goblin.move_and_slide()

## Host: an event creature fell (QuestLog passes defeats on): the goblin's sack.
func on_event(actor: Node, kind: String, data: Dictionary) -> void:
    if kind != "kill" or not String(data.get("id", "")).begins_with("event_treasure_goblin"):
        return
    var level := int(actor.progression.get("level", 1))
    var zeni: int = TRADE.zeni_for(level, 2) * 40
    actor.gain_zeni(zeni, "goblin")
    _give_gear(actor, 3, level)
    session().notify_character(actor.character_id, "The goblin's sack bursts: %d Zeni!" % zeni)
    if world.get("quests") != null and actor.has_method("gain_zeni"):
        world.quests.on_event(actor, "event", {"what": "goblin"})
    if String(state.kind) == "goblin" and _alive().is_empty():
        _clear()

func _give_gear(actor: Node, rarity: int, level: int) -> void:
    var gear := preload("res://scripts/items/gear_catalogue.gd")
    var sources := preload("res://scripts/items/gear_sources.gd")
    var item: Dictionary = gear.roll(sources._base(_rng, [], rarity, level), rarity, _rng)
    if not actor.add_item(item):
        world.drop_gear(item, actor.global_position + Vector2(0, 12), "", actor.character_id)

func _finish(_escaped: bool) -> void:
    match String(state.kind):
        "invasion":
            _tell_all("The invaders plundered %s and withdrew." % (MAP.town(state.town)[1] if not MAP.town(state.town).is_empty() else "the town"))
        "goblin":
            if not _alive().is_empty():
                _tell_all("The treasure goblin escaped with its gold!")
        "meteors":
            _tell_all("The last meteorites cool and crumble to dust.")
    _clear()

func _clear() -> void:
    for creature in creatures():
        creature.get_parent().remove_child(creature)
        creature.queue_free()
    var next: float = float(state.next)
    state = initial_state()
    state.next = next

## --- Every peer: the warnings, meteorites and the invaded town's marker.
func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    if world == null or String(state.kind) != "meteors":
        return
    var me: Node2D = world.get_local_player() if world.has_method("get_local_player") else null
    if me == null or me.global_position.distance_to(at()) > 900.0:
        return
    var elapsed: float = DURATION.meteors - float(state.clock)
    var font := ThemeDB.fallback_font
    for meteor in state.meteors:
        var spot := Vector2(float(meteor[0]), float(meteor[1]))
        if not bool(meteor[3]):
            var until: float = float(meteor[2]) - elapsed
            if until <= METEOR_WARN:
                var grow: float = 1.0 - clampf(until / METEOR_WARN, 0.0, 1.0)
                draw_circle(spot, METEOR_RADIUS, Color(1, 0.15, 0.1, 0.12 + 0.18 * grow))
                draw_arc(spot, METEOR_RADIUS, 0, TAU, 32, Color(1, 0.3, 0.2, 0.8), 1.5)
                # The meteor itself, falling in from the upper right.
                var falling: Vector2 = spot + Vector2(1, -1.4) * 160.0 * (1.0 - grow)
                draw_line(falling, falling + Vector2(18, -24), Color(1, 0.7, 0.3, 0.6), 3.0)
                draw_circle(falling, 4.0, Color(1, 0.85, 0.5))
        elif not bool(meteor[4]):
            # A glowing meteorite in a small crater.
            draw_circle(spot, 10.0, Color(0.15, 0.1, 0.12, 0.7))
            draw_circle(spot, 5.0, Color(0.55, 0.45, 0.85))
            draw_circle(spot, 2.5 + sin(Time.get_ticks_msec() / 200.0) * 0.8, Color(0.9, 0.8, 1.0))
            draw_string(font, spot + Vector2(-22, -12), "Meteorite", HORIZONTAL_ALIGNMENT_CENTER, 44, 8, Color(0.9, 0.85, 1.0, 0.9))
