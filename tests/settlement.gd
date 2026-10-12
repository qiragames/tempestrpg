extends SceneTree
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
var checks := 0
var failures := 0
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
func _run() -> void:
    var world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var session = root.get_node("GameSession")
    var actor = world.get_local_player()
    var camp = world.camp
    var ally = world.get_node("GoblinAlly")
    ally.set_physics_process(false)
    actor.position = camp.SITE
    await _frames()
    _check(InputMap.has_action("camp") and not camp.state.founded and camp.state.wood == 0, "Camp begins empty with menu binding")
    _check(not camp.transact(actor, "found", "camp_1"), "Founding requires an evolved owned ally")
    ally.owner_id = "host"
    _check(not camp.can_found(actor), "Nameless recruit cannot found the camp")
    ally.display_name = "Aster"
    ally.race = "Hobgoblin"
    ally.maximum_hp = 60
    ally.power = 8
    ally.follow_speed = 65
    ally.position = Vector2(100, 350)
    _check(not camp.can_found(actor), "Evolved ally must accompany founder")
    ally.position = Vector2(330, 370)
    actor.begin_exhaustion(8)
    _check(not camp.transact(actor, "found", "camp_1"), "Sleeping players cannot found settlements")
    actor.exhaustion_active = false
    actor.exhaustion_left = 0
    _check(not session.apply_action(actor, "camp", {"operation": "found", "id": "camp_1", "wood": 999}), "Host rejects forged resource payloads")
    var dialog = world.get_node("HUD")._camp_dialog
    dialog.open_dialog()
    _check(paused and dialog.visible and dialog._stock.text.contains("0 wood") and not dialog._found.disabled, "Offline menu shows real resources and founding prerequisites")
    _check(session.apply_action(actor, "camp", {"operation": "found", "id": "camp_1"}) and camp.state.founder == "host", "Founding records stable founder")
    _check(not camp.transact(actor, "found", "camp_1"), "Founding resolves once")
    _check(not camp.transact(actor, "build", "hut_1"), "Building requires materials")
    world.get_node("HUD").open_inventory()
    _check(not world.get_node("HUD")._modal.visible, "Camp menu prevents overlapping inventory")
    dialog.close_dialog()
    _check(not paused, "Closing camp menu restores offline simulation")
    actor.position = Vector2(100, 350)
    _check(not camp.transact(actor, "gather", "wood_1"), "Gathering requires deposit proximity")
    actor.position = Vector2(280, 350)
    world._add_obstacle(Rect2(289, 338, 2, 24))
    var wall = world.get_child(world.get_child_count() - 1)
    await _frames()
    _check(not camp.transact(actor, "gather", "wood_1"), "Terrain blocks gathering")
    wall.queue_free()
    await _frames()
    _check(camp.transact(actor, "gather", "wood_1") and camp.state.wood == 8 and camp.state.deposits.wood_1 == 0, "Gathering transfers finite material into shared stock")
    _check(not camp.transact(actor, "gather", "wood_1") and camp.state.wood == 8, "Duplicate gathering cannot create materials")
    _check(not camp.transact(actor, "gather", "unknown"), "Unknown deposit IDs fail")
    var guest = load("res://scenes/player/player.tscn").instantiate()
    guest.character_id = "guest"
    guest.local_controlled = false
    guest.position = Vector2(350, 300)
    world.add_child(guest)
    _check(camp.transact(guest, "gather", "wood_2") and camp.state.wood == 16, "Other characters contribute to the same shared camp")
    guest.position = Vector2(410, 350)
    _check(camp.transact(guest, "gather", "stone_1") and camp.state.stone == 8, "Stone uses finite shared stock")
    actor.position = camp.SITE
    guest.position = camp.HUT_SITE
    _check(not camp.can_build(actor), "Building cannot enclose another player")
    guest.position = Vector2(500, 340)
    _check(not camp.transact(actor, "build", "unknown"), "Unknown structure IDs fail")
    _check(camp.transact(actor, "build", "hut_1") and camp.state.hut and camp.state.wood == 4 and camp.state.stone == 2, "Build consumes exactly the recipe once")
    _check(not camp.transact(actor, "build", "hut_1") and camp.state.wood == 4, "Repeated builds cannot spend twice")
    await _frames()
    var ray := PhysicsRayQueryParameters2D.create(camp.HUT_SITE - Vector2(30, 0), camp.HUT_SITE + Vector2(30, 0), 1)
    _check(not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "Built hut has real terrain collision")
    guest.queue_free()
    await _frames()
    var document: Dictionary = CODEC.capture_entities(world)
    document.merge({"version": STORE.VERSION, "world_id": "settlement_test", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    _check(STORE.validate(document), "Actual camp snapshot validates")
    var path := "/tmp/tempestrpg-camp-" + Crypto.new().generate_random_bytes(8).hex_encode() + "/world.json"
    _check(STORE.write_world(path, document) == OK, "Camp world saves atomically")
    var loaded: Dictionary = STORE.load_world(path)
    camp.restore(camp.initial_state())
    CODEC.apply_entities(world, loaded.data, false)
    _check(camp.state == loaded.data.camp and camp.state.hut and camp.state.wood == 4 and camp.state.stone == 2 and camp.state.deposits.wood_1 == 0, "Reload restores resources, depleted nodes and built hut together")
    var bad := document.duplicate(true)
    bad.camp.wood = 999
    _check(not STORE.validate(bad), "Save resource conservation rejects fabricated stock")
    bad = document.duplicate(true)
    bad.camp.deposits.stone_1 = -1
    _check(not STORE.validate(bad), "Save validation rejects invalid deposits")
    bad = document.duplicate(true)
    bad.camp.founder = "missing_player"
    _check(not STORE.validate(bad), "Founder must be a saved stable character")
    bad = document.duplicate(true)
    bad.camp.founded = false
    _check(not STORE.validate(bad), "A hut cannot exist before founding")
    var legacy := document.duplicate(true)
    legacy.version = 3
    legacy.erase("camp")
    var migrated: Dictionary = STORE.migrate(legacy)
    _check(STORE.validate(migrated) and migrated.camp == camp.initial_state(), "Version-3 worlds migrate without losing existing characters")
    session.replica_world = true
    _check(not camp.transact(actor, "gather", "wood_1"), "Client replicas cannot mutate camp resources")
    session.replica_world = false
    camp.restore(camp.initial_state())
    actor.position = Vector2(300, 350)
    actor.get_node("Health").current = 0
    _check(not camp.transact(actor, "gather", "wood_1"), "Dead characters cannot gather")
    print("Settlement checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
