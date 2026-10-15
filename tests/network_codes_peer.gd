extends SceneTree
## Host or friend for network_codes.py: they connect only by swapping join codes through files.
var options: Dictionary = {}
func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        var pair := argument.trim_prefix("--").split("=", true, 1)
        options[pair[0]] = pair[1] if pair.size() == 2 else ""
    call_deferred("_run")
func _write(path: String, text: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(text)
    file.close()
func _read_when_ready(path: String) -> String:
    while not FileAccess.file_exists(path):
        await create_timer(0.1).timeout
    await create_timer(0.2).timeout
    return FileAccess.get_file_as_string(path)
func _run() -> void:
    var session: Node = root.get_node("GameSession")
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await process_frame
    if options.mode == "host":
        if session.start_host(24000, options.save, false) != OK or session.open_with_codes() != OK:
            _write(options.report, JSON.stringify({"error": "host could not open with codes"}))
            quit(1)
            return
        var invite: String = await session.create_invite()
        _write(options.dir + "/invite.txt", invite)
        var reply := await _read_when_ready(options.dir + "/reply.txt")
        var accepted: bool = session.accept_reply(reply)
        var waited := 0.0
        while session.owners.size() < 2 and waited < 30.0:
            await create_timer(0.2).timeout
            waited += 0.2
        await create_timer(1.0).timeout
        _write(options.report, JSON.stringify({"ready": true, "invite_length": invite.length(), "accepted": accepted, "owners": session.owners.values(), "bad_reply": session.accept_reply("TRPG1-garbage")}))
        while not FileAccess.file_exists(options.dir + "/stop"):
            await create_timer(0.1).timeout
        session.stop_session(true)
        quit(0)
    else:
        session.session_failed.connect(func(message: String):
            _write(options.report, JSON.stringify({"error": message}))
            quit(0)
        )
        var invite := await _read_when_ready(options.dir + "/invite.txt")
        var reply: String = await session.join_with_code(invite, options.identity)
        _write(options.dir + "/reply.txt", reply)
        await session.character_assigned
        while session.latest_snapshot.is_empty():
            await process_frame
        await create_timer(0.5).timeout
        _write(options.report, JSON.stringify({"ready": true, "id": session.local_character_id, "players": session.latest_snapshot.players.keys(), "reply_length": reply.length()}))
        while not FileAccess.file_exists(options.dir + "/stop"):
            await create_timer(0.1).timeout
        session.stop_session(false)
        quit(0)
