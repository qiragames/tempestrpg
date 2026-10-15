extends SceneTree
## Client for network_server.py: joins the console server on 127.0.0.1 and reports who it plays.
var options: Dictionary = {}
func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        var pair := argument.trim_prefix("--").split("=", true, 1)
        options[pair[0]] = pair[1] if pair.size() == 2 else ""
    call_deferred("_run")
func _report(data: Dictionary) -> void:
    var file := FileAccess.open(options.report, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()
func _run() -> void:
    var session: Node = root.get_node("GameSession")
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    session.session_failed.connect(func(message: String):
        _report({"denied": message})
        quit(0)
    )
    session.join_host("127.0.0.1", int(options.port), options.identity)
    await session.character_assigned
    while session.latest_snapshot.is_empty():
        await process_frame
    await create_timer(0.5).timeout
    _report({"joined": true, "id": session.local_character_id, "players": session.latest_snapshot.players.keys()})
    while not FileAccess.file_exists(options.stop):
        await create_timer(0.1).timeout
    _report({"joined": true, "left": true, "id": session.local_character_id, "players": session.latest_snapshot.players.keys()})
    session.stop_session(false)
    await process_frame
    quit(0)
