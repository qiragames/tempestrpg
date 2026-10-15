extends SceneTree
## M5d rival nations and the siege (user decisions): seven rival nations in the archipelago's
## towns that only exist (banners, leaders to talk to, the world map); a monster horde that
## besieges a village with three citizens (warning, three waves marching on the flag, breaches,
## win or loss), never respawning, called off by a reload; saves, forgeries, the v29 -> v30
## migration and the HUD banner.
const MAP := preload("res://scripts/world/world_map.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const RIVALS := preload("res://scripts/nation/rival_nations.gd")
const SIEGE := preload("res://scripts/nation/siege.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
var checks := 0
var failures := 0
var world: Node2D
var session: Node
var actor: CharacterBody2D
var camp: Node2D
var siege: Node

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _frames(count: int = 3) -> void:
    for _i in range(count):
        await physics_frame
        await process_frame

func _stock(rounds: int) -> void:
    for _round in range(rounds):
        for id in camp.sites:
            if camp.state.deposits[id] > 0:
                camp.harvest(id)
        camp._refill(camp.REFILL_SECONDS + 1.0)

func _spot(kind: String) -> Vector2i:
    var centre: Vector2i = MAP.to_tile(camp.SITE)
    for ring in range(2, 22):
        for dy in range(-ring, ring + 1):
            for dx in range(-ring, ring + 1):
                if maxi(absi(dx), absi(dy)) == ring and camp.place_problem(null, kind, centre + Vector2i(dx, dy)).is_empty():
                    return centre + Vector2i(dx, dy)
    return Vector2i(9999, 9999)

func _document() -> Dictionary:
    var data: Dictionary = CODEC.capture_entities(world)
    data.merge({"version": STORE.VERSION, "world_id": "siege", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    return data

func _run() -> void:
    session = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-siege-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24760, dir.path_join("siege.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    actor = world.get_local_player()
    camp = world.camp
    siege = world.siege
    # --- Rival nations
    var capitals := {}
    var open := true
    for entry in RIVALS.RIVALS:
        capitals[entry[3]] = true
        for at in [RIVALS.leader_position(entry), RIVALS.banner_position(entry)]:
            var tile := MAP.to_tile(at)
            open = open and not MAP.solid(tile.x, tile.y) and MAP.town(entry[3])[4] == "town"
    _check(RIVALS.RIVALS.size() == 7 and capitals.size() == 7 and open, "Seven rival nations, each in its own town, leader and banner on open ground")
    var first: Array = RIVALS.RIVALS[0]
    actor.global_position = RIVALS.leader_position(first) + Vector2(0, 14)
    await _frames(1)
    _check(world.rivals.nearest_leader(actor) == first[0], "Standing before the %s's leader" % first[1])
    var hud = world.get_node("HUD")
    hud._ally_dialog.open_nearest()
    await _frames(1)
    _check(hud.dialog_panel.is_open() and hud.dialog_panel._title.text.contains(first[1]), "F talks to the leader (neither friend nor foe)")
    hud.dialog_panel.close()
    # --- Building up to a village with citizens
    camp.state.founded = true
    camp.state.founder = "host"
    _stock(4)
    camp.complete("hut_1")
    camp.complete("storehouse_1")
    for kind in ["house", "house", "well", "banner", "watchtower"]:
        if kind == "watchtower":
            camp.rank_up()
        camp.place(null, kind, _spot(kind))
    var nation: Dictionary = camp.state.nation
    nation.food = 40
    nation.grown = int(nation.eaten) + 40
    _check(not siege.eligible(), "No siege before three citizens")
    for _i in range(4):
        camp._tick_nation(NATION.ARRIVAL_SECONDS)
    _check(camp.tier() == 1 and camp.population() >= 3 and siege.eligible(), "A village with %d citizens draws the horde" % camp.population())
    # --- Calling the horde
    actor.global_position = camp.SITE + Vector2(0, 30)
    await _frames(1)
    _check(session.apply_action(actor, "camp", {"operation": "siege", "id": "now"}) and siege.state.phase == "warning", "Face the horde: a warning")
    _check(not siege.call_now(actor), "Only one siege at a time")
    await _frames(2)
    _check(hud.get_node("SiegeBanner").text.begins_with("SIEGE"), "The HUD shows the siege")
    siege._physics_process(SIEGE.WARNING_SECONDS)
    var horde: Array = siege.creatures()
    _check(siege.state.phase == "wave" and siege.state.wave == 1 and horde.size() == 2 + 2 + 1 and horde.all(func(node): return node.home == camp.SITE), "Wave 1: five creatures march on the flag")
    # A breach.
    horde[0].global_position = camp.SITE + Vector2(5, 0)
    siege._physics_process(0.1)
    _check(siege.state.breaches == 1 and siege.creatures().size() == horde.size() - 1, "One reached the flag: a breach")
    # Defeat the rest: the next wave comes; they never respawn.
    for creature in siege.creatures():
        creature.get_node("Health").take_damage(99999, actor)
    await _frames(2)
    _check(world.respawner.pending.all(func(entry): return not String(entry.id).begins_with("siege_")), "Siege creatures never respawn")
    siege._physics_process(0.1)
    _check(siege.state.wave == 2, "Wave 2")
    for creature in siege.creatures():
        creature.get_node("Health").take_damage(99999, actor)
    siege._physics_process(0.1)
    for creature in siege.creatures():
        creature.get_node("Health").take_damage(99999, actor)
    var treasury: int = int(nation.treasury)
    siege._physics_process(0.1)
    _check(siege.state.phase == "calm" and int(siege.state.won) == 1 and int(nation.treasury) > treasury, "Three waves beaten: the siege is won (Zeni for the treasury)")
    # --- A lost siege
    nation.treasury = int(nation.treasury) + 400
    nation.earned = int(nation.earned) + 400
    var food_before: int = int(nation.food)
    var zeni_before: int = int(nation.treasury)
    siege.call_now(actor)
    siege._physics_process(SIEGE.WARNING_SECONDS)
    for _i in range(SIEGE.MAX_BREACHES):
        var left: Array = siege.creatures().filter(func(node): return node.get_node("Health").current > 0)
        if left.is_empty():
            siege._next_wave()
            left = siege.creatures().filter(func(node): return node.get_node("Health").current > 0)
        left[0].global_position = camp.SITE
        siege._check_breaches()
    _check(siege.state.phase == "calm" and int(siege.state.lost) == 1 and int(nation.food) == food_before - food_before / 2 and int(nation.treasury) == zeni_before - zeni_before / 2 and siege.creatures().is_empty(), "Eight breaches lose it: half the food and treasury plundered, the horde leaves")
    # --- Timer
    siege.state.clock = 0.0
    siege._physics_process(SIEGE.SIEGE_INTERVAL)
    _check(siege.state.phase == "warning", "Every %d minutes the horde returns" % int(SIEGE.SIEGE_INTERVAL / 60))
    siege._physics_process(SIEGE.WARNING_SECONDS)
    await _frames(1)
    # --- Saves
    var document := _document()
    _check(STORE.validate(document.duplicate(true)), "A world mid-siege saves")
    var forged: Dictionary = document.duplicate(true)
    forged.siege.phase = "victory"
    var forged_two: Dictionary = document.duplicate(true)
    forged_two.siege.breaches = 99
    _check(not STORE.validate(forged) and not STORE.validate(forged_two), "Unknown phases and impossible breaches are rejected")
    siege.restore(document.siege, false)
    await _frames(2)
    _check(siege.state.phase == "calm" and siege.creatures().is_empty(), "A reload calls the siege off")
    var old: Dictionary = document.duplicate(true)
    old.version = 29
    old.erase("siege")
    var migrated: Variant = STORE.migrate(old)
    _check(migrated is Dictionary and migrated.version == STORE.VERSION and migrated.siege == SIEGE.initial_state(), "v29 worlds: no siege yet")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Siege checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
