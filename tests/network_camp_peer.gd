extends SceneTree
var session: Node
var options: Dictionary = {}
var world: Node2D
var phase_seen := ""
var busy := false
var deadline: int
func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        var pair := argument.trim_prefix("--").split("=", true, 1)
        options[pair[0]] = pair[1] if pair.size() == 2 else ""
    deadline = Time.get_ticks_msec() + 25000
    call_deferred("_run")
func _report(data: Dictionary) -> void:
    var file := FileAccess.open(options.report, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()
func _run() -> void:
    session = root.get_node("GameSession")
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    if options.mode == "server":
        if session.start_host(int(options.port), options.save) != OK:
            _report({"error": "Host could not load camp world"})
            quit(1)
            return
        for enemy in get_nodes_in_group("enemies"):
            enemy.set_physics_process(false)
        if not options.has("reload"):
            var actor = world.get_local_player()
            var ally = world.get_node("GoblinAlly")
            actor.position = world.camp.SITE
            ally.owner_id = "host"
            ally.display_name = "Aster"
            ally.race = "Hobgoblin"
            ally.maximum_hp = 60
            ally.power = 8
            ally.follow_speed = 65
            ally.position = Vector2(330, 370)
            if not world.camp.transact(actor, "found", "camp_1"):
                _report({"error": "Fixture founding failed"})
                quit(1)
                return
            actor.position = Vector2(100, 340)
        if options.has("work"):
            if not options.has("reload"):
                session.player_joined.connect(func(actor: Node2D):
                    var ally = world.get_node("GoblinAlly")
                    if ally.owner_id == "host":
                        ally.owner_id = actor.character_id
                )
        else:
            world.get_node("GoblinAlly").set_physics_process(false)
            if not options.has("reload"):
                # Each guest brings one absorbed essence to offer.
                session.player_joined.connect(func(actor: Node2D):
                    actor.get_node("Inventory").add_specimen(load("res://data/specimens/forest_gnasher.tres"))
                )
        _report({"ready": true, "camp": world.camp.state, "work": _work_state()})
    else:
        session.join_host("127.0.0.1", int(options.port), options.identity)
        await session.character_assigned
        while session.latest_snapshot.is_empty():
            await process_frame
        if options.has("reload"):
            await create_timer(0.2).timeout
            _report({"restored": true, "camp": world.camp.state, "work": _work_state()})
            session.stop_session(false)
            quit(0)
        else:
            _report({"ready": true})
func _process(_delta: float) -> bool:
    if Time.get_ticks_msec() > deadline:
        _report({"error": "Camp integration timed out"})
        quit(1)
        return false
    if world == null or session == null or not session.active:
        return false
    if options.mode == "server" and options.has("work") and world.camp.state.wood == 16 and world.camp.state.stone == 8 and world.get_node("GoblinAlly").work_role == "follow":
        _report({"gathered": true, "camp": world.camp.state, "work": _work_state()})
    if FileAccess.file_exists(options.stop):
        if options.mode == "server":
            _report({"saved": session.save_world() == OK, "camp": world.camp.state, "work": _work_state()})
        session.stop_session(true)
        quit(0)
        return false
    if not FileAccess.file_exists(options.phase):
        return false
    var phase: String = FileAccess.get_file_as_string(options.phase)
    if phase == phase_seen or busy:
        return false
    var positions := {"wood_1": Vector2(300, 350), "wood_2": Vector2(350, 300), "stone_1": Vector2(410, 350), "hut_1": Vector2(350, 350), "work_gather": Vector2(350, 350), "work_build": Vector2(350, 350),
        "wood_3": Vector2(700, 440), "stone_2": Vector2(860, 200), "stone_3": Vector2(200, 540), "storehouse_1": Vector2(350, 350), "offer": Vector2(350, 350), "shrine_1": Vector2(350, 350)}
    if not positions.has(phase):
        return false
    if options.mode == "server":
        phase_seen = phase
        # Deliberately position test actors at each target; movement has its own integration suite.
        for actor in get_nodes_in_group("player"):
            if actor.character_id != "host":
                actor.position = positions[phase]
    elif not session.latest_snapshot.is_empty() and world.get_local_player().position.distance_to(positions[phase]) < 2:
        phase_seen = phase
        busy = true
        _act(phase)
    return false
func _act(phase: String) -> void:
    var hud = world.get_node("HUD")
    hud._camp_dialog.open_dialog()
    var operation := "build" if world.camp.STRUCTURES.has(phase) else "offer" if phase == "offer" else "gather"
    var target := "gnasher_essence" if phase == "offer" else phase
    var guard: bool = not world.camp.transact(world.get_local_player(), operation, target)
    if phase.begins_with("work_"):
        var role := phase.trim_prefix("work_")
        # Work is only assigned at the camp: give the following ally time to walk back (the
        # world now takes longer to build at startup, so it may have wandered after its owner).
        var ally = world.get_node("GoblinAlly")
        var waited := 0.0
        while ally.global_position.distance_to(world.camp.SITE) > 90.0 and waited < 6.0:
            await create_timer(0.1).timeout
            waited += 0.1
        guard = not world.get_node("GoblinAlly").assign_work(world.get_local_player(), role)
        session.request_action("ally_work", {"id": "ally_goblin_1", "role": role})
        session.request_action("ally_work", {"id": "ally_goblin_1", "role": role})
    else:
        session.request_action("camp", {"operation": operation, "id": target})
        session.request_action("camp", {"operation": operation, "id": target})
    var before: float = session.latest_snapshot.progression.world_time
    await create_timer(0.5).timeout
    _report({"phase": phase, "camp": world.camp.state, "guard": guard, "menu_local": not paused and session.latest_snapshot.progression.world_time > before, "work": _work_state()})
    hud._camp_dialog.close_dialog()
    busy = false

func _work_state() -> Dictionary:
    var ally = world.get_node("GoblinAlly")
    return {"owner": ally.owner_id, "role": ally.work_role, "target": ally.work_target, "remaining": ally.work_left}
