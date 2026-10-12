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
func _frames(count: int) -> void:
    for _i in range(count):
        await physics_frame
        await process_frame
func _run() -> void:
    var world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var session = root.get_node("GameSession")
    var actor = world.get_local_player()
    var ally = world.get_node("GoblinAlly")
    var camp = world.camp
    ally.set_physics_process(false)
    actor.position = camp.SITE
    ally.position = Vector2(330, 370)
    ally.owner_id = "host"
    _check(not ally.assign_work(actor, "gather"), "Recruit must evolve before working")
    ally.display_name = "Aster"
    ally.race = "Hobgoblin"
    ally.maximum_hp = 60
    ally.power = 8
    ally.follow_speed = 65
    _check(not ally.assign_work(actor, "gather"), "Work requires founded camp")
    _check(camp.transact(actor, "found", "camp_1"), "Working camp prerequisite")
    _check(not ally.assign_work(actor, "build"), "Construction assignment requires recipe funds")
    var guest = load("res://scenes/player/player.tscn").instantiate()
    guest.character_id = "guest"
    guest.local_controlled = false
    guest.position = camp.SITE
    world.add_child(guest)
    _check(not ally.assign_work(guest, "gather"), "Only owner can command worker")
    _check(not session.apply_action(actor, "ally_work", {"id": ally.entity_id, "role": "gather", "owner": "guest"}), "Host rejects forged assignment payloads")
    actor.position = Vector2(100, 100)
    _check(not ally.assign_work(actor, "gather"), "Commands require proximity to camp")
    actor.position = camp.SITE
    actor.begin_exhaustion(8)
    _check(not ally.assign_work(actor, "gather"), "Exhausted owner cannot assign")
    actor.exhaustion_active = false
    actor.exhaustion_left = 0
    _check(not ally.assign_work(actor, "invented"), "Unknown role cannot be assigned")
    var dialog = world.get_node("HUD")._camp_dialog
    dialog.open_dialog()
    _check(not dialog._work_buttons.gather.disabled and dialog._work_buttons.build.disabled, "UI reflects worker and material prerequisites")
    dialog._assign("gather")
    _check(ally.work_role == "gather" and ally.work_target == "wood_1" and ally.work_left == 3, "Gather assignment selects nearest finite deposit")
    _check(not ally.assign_work(actor, "gather") and ally.work_left == 3, "Repeated assignments cannot reset progress")
    dialog.close_dialog()
    ally.position = camp.DEPOSITS.wood_1.position
    ally._physics_process(1)
    _check(ally.work_left == 2 and camp.state.wood == 0, "Gathering takes time before reward")
    var saved: Dictionary = CODEC.capture_entities(world)
    saved.merge({"version": STORE.VERSION, "world_id": "work_test", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    _check(STORE.validate(saved), "Partial job snapshot validates")
    var path := "/tmp/tempestrpg-work-" + Crypto.new().generate_random_bytes(8).hex_encode() + "/world.json"
    _check(STORE.write_world(path, saved) == OK, "Partial job saves atomically")
    var loaded: Dictionary = STORE.load_world(path)
    ally.work_role = "follow"
    ally.work_target = ""
    ally.work_left = 0
    CODEC.apply_entities(world, loaded.data, false)
    ally.set_physics_process(false)
    _check(ally.work_role == "gather" and ally.work_target == "wood_1" and ally.work_left == 2, "Reload restores job and remaining work time")
    session.replica_world = true
    var before: float = ally.work_left
    ally._physics_process(1)
    _check(not ally.assign_work(actor, "follow") and ally.work_left == before, "Client replicas cannot assign or progress work")
    session.replica_world = false
    world.remove_child(actor)
    ally._physics_process(2)
    _check(camp.state.wood == 8 and camp.state.deposits.wood_1 == 0, "World citizen keeps working after owner disconnect")
    world.add_child(actor)
    world.bind_local_player(actor)
    ally._physics_process(0)
    _check(ally.work_target == "wood_2", "Worker selects next remaining deposit")
    _check(camp.transact(guest, "gather", "wood_2") == false, "Manual claims still require range")
    guest.position = camp.DEPOSITS.wood_2.position
    _check(camp.transact(guest, "gather", "wood_2"), "Another player can finish the worker's target")
    ally._physics_process(0)
    _check(ally.work_target == "stone_1" and camp.state.wood == 16, "Worker skips depleted target without duplicating reward")
    ally.position = camp.DEPOSITS.stone_1.position
    ally._physics_process(3)
    ally._physics_process(0)
    _check(ally.work_role == "follow" and camp.state.stone == 8, "Gather job ends when all deposits are empty")
    actor.position = camp.SITE
    ally.position = camp.SITE
    _check(ally.assign_work(actor, "build"), "Funded hut can be assigned to worker")
    guest.position = camp.HUT_SITE
    ally._physics_process(2)
    _check(ally.work_left == 4 and not camp.state.hut, "Blocked footprint pauses construction without spending")
    guest.position = Vector2(500, 340)
    ally._physics_process(2)
    _check(ally.work_left == 2 and camp.state.wood == 16, "Construction timer advances before charging resources")
    _check(ally.assign_work(actor, "follow") and camp.state.wood == 16, "Recall cancels unpaid work safely")
    _check(ally.assign_work(actor, "build"), "Canceled work can be reassigned")
    ally._physics_process(4)
    _check(camp.state.hut and camp.state.wood == 4 and camp.state.stone == 2 and ally.work_role == "follow", "Worker completes hut, charges once and returns to follow")
    _check(not ally.assign_work(actor, "build"), "Built hut cannot be ordered again")
    var legacy := saved.duplicate(true)
    legacy.version = 4
    legacy.allies[0].erase("work")
    var migrated: Dictionary = STORE.migrate(legacy)
    _check(STORE.validate(migrated) and migrated.allies[0].work.role == "follow", "Version-4 saves migrate to idle/follow workers")
    var bad := saved.duplicate(true)
    bad.allies[0].work.target = "unknown"
    _check(not STORE.validate(bad), "Invalid saved work target rejected")
    bad = saved.duplicate(true)
    bad.allies[0].work.remaining = -1
    _check(not STORE.validate(bad), "Invalid work timer rejected")
    # Real scene frames verify walking and work scheduling, not only direct timer calls.
    camp.restore(camp.initial_state())
    camp.state.founded = true
    camp.state.founder = "host"
    ally.position = camp.SITE
    _check(ally.assign_work(actor, "gather"), "New finite-work fixture starts")
    ally.set_physics_process(true)
    await _frames(260)
    _check(camp.state.wood >= 8 and ally.position.distance_to(camp.SITE) > 10, "Real physics frames move worker and gather first deposit")
    guest.queue_free()
    print("Ally work checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
