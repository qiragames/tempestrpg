extends SceneTree
## Multi-process integration actor; assertions are collected by network_integration.py.

const CODEC := preload("res://scripts/persistence/state_codec.gd")
var session: Node
var options: Dictionary = {}
var world: Node2D
var report_path: String
var deadline: int
var failed: bool = false

func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        var pair := argument.trim_prefix("--").split("=", true, 1)
        options[pair[0]] = pair[1] if pair.size() == 2 else ""
    report_path = options.report
    deadline = Time.get_ticks_msec() + 35000
    call_deferred("_run")

func _report(data: Dictionary) -> void:
    var file := FileAccess.open(report_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()

func _finish_error(message: String) -> void:
    if failed:
        return
    failed = true
    _report({"error": message})
    session.stop_session(false)
    quit(1)

func _process(_delta: float) -> bool:
    if Time.get_ticks_msec() > deadline:
        _finish_error("Integration process timed out")
    if options.mode == "server" and FileAccess.file_exists(options.stop):
        var saved: Error = session.save_world()
        var data: Dictionary = session.document()
        for record in data.players.values():
            record.erase("token_hash")
        _report({"saved": saved == OK, "state": data, "rejected": session.rejected_requests, "connections": session.owners.size()})
        session.stop_session(true)
        quit(0)
    return false

func _wait(seconds: float) -> void:
    await create_timer(seconds).timeout

func _run() -> void:
    session = root.get_node("GameSession")
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    if options.mode == "server":
        var result: Error = session.start_host(int(options.port), options.save)
        if result != OK:
            _finish_error("Host startup failed: %d" % result)
            return
        if not options.has("reload"):
            var host = world.get_local_player()
            host.position = Vector2(100, 340)
            host.get_node("Health").current = 77
            host.get_node("Magicules").maximum = 150
            host.get_node("Magicules")._current = 120
            host.get_node("Magicules").regeneration_per_second = 0
            host.progression.level = 3
            host.progression.experience = 45
            host.get_node("Inventory").add_specimen(load(CODEC.SPECIMEN))
            world.progression.quests = {"intro": {"complete": true}}
            world.progression.settlements = {"camp": {"wood": 7}}
            world.get_node("ForestGnasher").position = Vector2(510, 340)
            world.get_node("ForestGnasher").home = Vector2(510, 340)
            world.get_node("ForestGnasher/Health").current = 10
            world.get_node("GoblinAlly").position = Vector2(510, 340)
        for actor in world.get_children():
            if actor.is_in_group("enemies"):
                actor.set_physics_process(false)
        session.player_joined.connect(func(actor: Node2D):
            if actor.progression.level == 1:
                actor.progression.level = 2
                actor.progression.experience = 20
                actor.position = Vector2(480, 340)
                actor.get_node("Magicules").regeneration_per_second = 0
        )
        _report({"ready": true})
        return
    session.session_failed.connect(func(message: String):
        if options.get("case") == "denied":
            _report({"denied": true})
            quit(0)
        else:
            _finish_error(message)
    )
    var error: Error = session.join_host("127.0.0.1", int(options.port), options.identity)
    if error != OK:
        _finish_error("Join startup failed")
        return
    await session.character_assigned
    while session.latest_snapshot.is_empty():
        await process_frame
    if options.get("case") == "capacity":
        _report({"joined": true, "id": session.local_character_id})
        while not FileAccess.file_exists(options.stop):
            await _wait(0.05)
        session.stop_session(false)
        quit(0)
        return
    if options.get("case") == "denied":
        _finish_error("Unverified or over-capacity client was admitted")
        return
    if options.get("case") == "resume":
        await _wait(0.3)
        _report({"state": CODEC.capture_player(world.get_local_player()), "world": session.latest_snapshot.progression, "allies": session.latest_snapshot.allies})
        session.stop_session(false)
        quit(0)
        return
    var actor = world.get_local_player()
    var position_before: Vector2 = actor.position
    Input.action_press("move_right")
    await _wait(0.12)
    Input.action_release("move_right")
    await _wait(0.12)
    var moved: bool = actor.position.x > position_before.x + 4
    session.request_action("attack")
    await _wait(0.3)
    Input.action_press("move_right")
    await _wait(0.08)
    Input.action_release("move_right")
    await _wait(0.15)
    var guards: bool = not actor.get_node("Health").take_damage(999) and not actor.get_node("Magicules").try_spend(10) and not actor.get_node("Inventory").add_specimen(load(CODEC.SPECIMEN))
    session._request_action.rpc_id(1, "discard", {"id": "gnasher_essence", "character_id": "host"})
    session._move_input.rpc_id(1, Vector2(NAN, 0))
    session.request_action("absorb")
    await _wait(1.6)
    session.request_action("recruit", {"id": "ally_goblin_1"})
    await _wait(0.2)
    var hud = world.get_node("HUD")
    hud.open_inventory()
    var time_before: float = session.latest_snapshot.progression.world_time
    await _wait(0.3)
    var local_menu: bool = not paused and session.latest_snapshot.progression.world_time > time_before + 0.1
    hud.close_inventory()
    await _wait(0.2)
    var snapshot: Dictionary = session.latest_snapshot
    var secrets_absent: bool = true
    for state in snapshot.players.values():
        secrets_absent = secrets_absent and not state.has("token_hash")
    _report({"moved": moved, "guards": guards, "menu_local": local_menu, "no_credentials": secrets_absent, "state": CODEC.capture_player(actor), "allies": snapshot.allies})
    session.stop_session(false)
    quit(0)
