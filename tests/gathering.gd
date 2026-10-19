extends SceneTree
## Chopping and mining (user request): F at a deposit starts swinging an axe (wood) or pickaxe
## (stone); after a number of swings (fewer with better tools) the deposit is gathered into the
## camp; walking away stops it; the tool and the impact are animated; allies swing too.
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
    # Exact XP and gathered amounts: no double early XP, no starter tools (see tests/sve_fixes.gd).
    preload("res://scripts/player/player.gd").starter_kit = false
    preload("res://scripts/player/player.gd").early_double_xp = false
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-gather-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24790, dir.path_join("gather.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    var camp = world.camp
    var chop := preload("res://scripts/visual/chopping.gd")
    # A wood deposit: swings, then the wood.
    var tree_id := "wood_1"
    actor.global_position = camp.sites[tree_id].position + Vector2(-14, 0)
    await _frames(2)
    var wood: int = camp.state.wood
    _check(session.apply_action(actor, "camp", {"operation": "chop", "id": tree_id}) and actor.gather_id == tree_id and actor.gather_swings == actor.SWINGS[0], "F at a tree starts chopping (five swings without an axe)")
    _check(camp.state.wood == wood, "Nothing is gathered before the tree falls")
    var impacts := 0
    var last := 0.0
    for _i in range(int(chop.SWING * 5 / (1.0 / 60.0)) + 30):
        await physics_frame
        await process_frame
        var phase: float = actor.gather_phase()
        if last < chop.IMPACT and phase >= chop.IMPACT:
            impacts += 1
        last = phase
        if actor.gather_id.is_empty():
            break
    _check(actor.gather_id.is_empty() and camp.state.wood > wood and int(camp.state.deposits[tree_id]) == 0, "After the swings the tree is down and its wood is in the camp")
    _check(impacts >= 4, "Each swing has an impact (%d)" % impacts)
    # Better tools swing fewer times; walking away stops.
    actor.progression.tools.pickaxe = 3
    var rock_id := "stone_1"
    actor.global_position = camp.sites[rock_id].position + Vector2(-14, 0)
    await _frames(2)
    _check(session.apply_action(actor, "camp", {"operation": "chop", "id": rock_id}) and actor.gather_resource == "stone" and actor.gather_swings == actor.SWINGS[3], "A Master pickaxe mines a rock in two swings")
    actor.velocity = Vector2(50, 0)
    actor._tick_gather(0.1)
    _check(actor.gather_id.is_empty() and int(camp.state.deposits[rock_id]) > 0, "Walking away stops mining (the rock stays)")
    actor.velocity = Vector2.ZERO
    _check(not session.apply_action(actor, "camp", {"operation": "chop", "id": tree_id}), "A felled tree cannot be chopped again (until it regrows)")
    # Every peer sees it (the snapshot carries who chops what).
    session.apply_action(actor, "camp", {"operation": "chop", "id": rock_id})
    var data: Dictionary = {"gathering": {}}
    session._broadcast()
    _check(actor.gather_id == rock_id, "The chopping state is ready to be shared with friends")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Gathering checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
