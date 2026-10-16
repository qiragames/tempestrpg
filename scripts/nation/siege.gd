extends Node
## The wave-defence siege (M5d, user decision): once your settlement is a village with three
## citizens, a monster horde gathers every SIEGE_INTERVAL seconds (or when you call it from the
## nation window). A warning, then WAVES waves march on the camp flag from one side; guards and
## characters fight them (normal XP and loot; they never respawn). Each creature that reaches the
## flag is a breach; MAX_BREACHES lose the siege (half the food and half the treasury are lost),
## clearing every wave wins it (Zeni for the treasury). Host decides; saved and replicated.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const GNASHER := preload("res://scripts/enemies/forest_gnasher.gd")

const SIEGE_INTERVAL := 1800.0
const FIRST_SIEGE := 900.0
const WARNING_SECONDS := 60.0
const WAVE_SECONDS := 90.0
const WAVES := 3
const MAX_BREACHES := 8
const BREACH_REACH := 28.0
const MIN_POPULATION := 3
## Horde kinds by settlement tier (village, town) and their difficulty.
const HORDES := [
    [],
    [["gnasher", 1], ["thornback", 1], ["gnasher", 2]],
    [["thornback", 2], ["frost_bear", 2], ["dune_viper", 2], ["salamander", 2]],
]
const DIRECTIONS := ["north", "east", "south", "west"]

var state: Dictionary = initial_state()
var world: Node

static func initial_state() -> Dictionary:
    return {"phase": "calm", "clock": 0.0, "wave": 0, "breaches": 0, "side": 0, "won": 0, "lost": 0, "serial": 0}

func _ready() -> void:
    name = "Siege"
    world = get_parent()

func camp() -> Node2D:
    return world.camp

func session() -> Node:
    return get_node("/root/GameSession")

func eligible() -> bool:
    return camp().state.founded and camp().tier() >= 1 and camp().population() >= MIN_POPULATION

func active() -> bool:
    return state.phase != "calm"

func creatures() -> Array:
    return get_tree().get_nodes_in_group("enemies").filter(func(node): return String(node.entity_id).begins_with("siege_") and not node.is_queued_for_deletion())

func _alive() -> Array:
    return creatures().filter(func(node): return node.get_node("Health").current > 0)

func _announce(message: String) -> void:
    for actor in get_tree().get_nodes_in_group("player"):
        session().notify_character(actor.character_id, message)

## Host: call the horde now (from the nation window, at the flag).
func call_now(actor: Node2D) -> bool:
    if not AUTHORITY.can_mutate(self) or active() or not eligible() or not camp().can_reach(actor, camp().SITE, 55):
        return false
    _warn()
    return true

func _warn() -> void:
    # The last horde's remains are gone by now (they could be absorbed until the next siege).
    for creature in creatures():
        if creature.get_node("Health").current <= 0:
            world.remove_child(creature)
            creature.queue_free()
    state.phase = "warning"
    state.clock = WARNING_SECONDS
    state.wave = 0
    state.breaches = 0
    state.side = (int(state.won) + int(state.lost) + int(state.serial)) % DIRECTIONS.size()
    _announce("A monster horde gathers to the %s! It marches on your %s in %d s." % [DIRECTIONS[state.side], NATION.tier_name(camp().tier()).to_lower(), int(WARNING_SECONDS)])
    session().queue_save()

func _physics_process(delta: float) -> void:
    if not AUTHORITY.can_mutate(self) or session().replica_world or world == null:
        return
    match String(state.phase):
        "calm":
            if not eligible():
                return
            state.clock = float(state.clock) + delta
            var due: float = FIRST_SIEGE if int(state.won) + int(state.lost) == 0 else SIEGE_INTERVAL
            if state.clock >= due:
                state.clock = 0.0
                _warn()
        "warning":
            state.clock = float(state.clock) - delta
            if state.clock <= 0.0:
                _next_wave()
        "wave":
            state.clock = float(state.clock) - delta
            _check_breaches()
            if String(state.phase) != "wave":
                return
            if _alive().is_empty() or state.clock <= 0.0:
                if int(state.wave) >= WAVES:
                    if _alive().is_empty():
                        _finish(true)
                else:
                    _next_wave()

## Where a wave comes from: the ring's edge on the horde's side, a little outside.
func _gate() -> Vector2:
    var directions := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
    return camp().SITE + directions[int(state.side)] * (NATION.radius(camp().tier()) + 60.0)

func _level() -> int:
    var total := 0
    var count := 0
    for actor in get_tree().get_nodes_in_group("player"):
        total += int(actor.progression.get("level", 1))
        count += 1
    return clampi(int(round(float(total) / maxf(1.0, count))), 4, 20)

func _next_wave() -> void:
    state.phase = "wave"
    state.wave = int(state.wave) + 1
    state.clock = WAVE_SECONDS
    var tier: int = clampi(camp().tier(), 1, HORDES.size() - 1)
    var size: int = 2 + tier * 2 + int(state.wave)
    # M11h: larger invasions for a nation with an army.
    var army: Node = world.get("army")
    if army != null:
        size += int(army.state().soldiers.size())
    var gate := _gate()
    for index in range(size):
        var pick: Array = HORDES[tier][(index + int(state.wave)) % HORDES[tier].size()]
        var creature = load(CODEC.ENEMY_SCENES[pick[0]]).instantiate()
        state.serial = int(state.serial) + 1
        creature.entity_id = "siege_%d" % int(state.serial)
        creature.position = gate + Vector2.from_angle(index * 2.4) * (12.0 + index * 4.0)
        world.add_child(creature)
        world.wire_enemy(creature)
        creature.set_difficulty(int(pick[1]))
        creature.level = _level()
        creature.get_node("Health").maximum = GNASHER.scaled_health(int(pick[1]), creature.level)
        creature.get_node("Health").current = creature.get_node("Health").maximum
        creature.damage = GNASHER.scaled_damage(int(pick[1]), creature.level)
        # They march on the flag (their "home") and fight whoever stands in the way.
        creature.home = camp().SITE
        creature.leash_radius = 4000.0
    _announce("Wave %d of %d: %d creatures from the %s!" % [state.wave, WAVES, size, DIRECTIONS[state.side]])
    session().queue_save()

func _check_breaches() -> void:
    for creature in _alive():
        if creature.global_position.distance_to(camp().SITE) <= BREACH_REACH:
            state.breaches = int(state.breaches) + 1
            world.remove_child(creature)
            creature.queue_free()
            if int(state.breaches) >= MAX_BREACHES:
                _finish(false)
                return
            _announce("The horde broke through at the flag! (%d of %d)" % [state.breaches, MAX_BREACHES])

## Win: Zeni into the treasury. Loss: half the food and half the treasury are lost.
func _finish(won: bool) -> void:
    var nation: Dictionary = camp().state.nation
    if won:
        var prize: int = mini(250 * (camp().tier() + 1), NATION.MAX_ZENI - int(nation.treasury))
        nation.treasury = int(nation.treasury) + prize
        nation.earned = int(nation.earned) + prize
        state.won = int(state.won) + 1
        _announce("The horde is beaten! %d Zeni flow into the treasury." % prize)
    else:
        var food_lost: int = int(nation.food) / 2
        nation.food = int(nation.food) - food_lost
        nation.eaten = int(nation.eaten) + food_lost
        var zeni_lost: int = int(nation.treasury) / 2
        nation.treasury = int(nation.treasury) - zeni_lost
        nation.withdrawn = int(nation.withdrawn) + zeni_lost
        state.lost = int(state.lost) + 1
        for creature in creatures():
            world.remove_child(creature)
            creature.queue_free()
        _announce("The horde overran the flag: %d food and %d Zeni were plundered." % [food_lost, zeni_lost])
    state.phase = "calm"
    state.clock = 0.0
    state.wave = 0
    state.breaches = 0
    session().queue_save()

func capture() -> Dictionary:
    return state.duplicate(true)

## A reloaded world never resumes a siege: the horde is called off.
func restore(value: Dictionary, replica: bool = false) -> void:
    state = value.duplicate(true)
    if not replica and active():
        state.phase = "calm"
        state.clock = 0.0
        state.wave = 0
        state.breaches = 0
        _clear.call_deferred()

func _clear() -> void:
    for creature in creatures():
        creature.get_parent().remove_child(creature)
        creature.queue_free()

static func valid_state(value: Variant) -> bool:
    if not value is Dictionary or value.size() != 8 or not value.get("phase") in ["calm", "warning", "wave"]:
        return false
    if not (value.get("clock") is float or value.get("clock") is int) or value.clock < 0 or value.clock > SIEGE_INTERVAL:
        return false
    for key in ["wave", "breaches", "side", "won", "lost", "serial"]:
        var number: Variant = value.get(key)
        if not (number is int or number is float) or number != floor(number) or number < 0 or number > 100000000:
            return false
    return int(value.wave) <= WAVES and int(value.breaches) < MAX_BREACHES and int(value.side) < DIRECTIONS.size()

## The HUD banner ("" when calm).
func banner() -> String:
    match String(state.phase):
        "warning":
            return "SIEGE · the horde arrives from the %s in %d s" % [DIRECTIONS[int(state.side)], int(ceil(float(state.clock)))]
        "wave":
            return "SIEGE · wave %d / %d · breaches %d / %d" % [int(state.wave), WAVES, int(state.breaches), MAX_BREACHES]
    return ""
