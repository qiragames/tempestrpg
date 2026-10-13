extends SceneTree
## Host/client actor for network_worlds.py: solo-hosted world opened to friends mid-game.
var session: Node
var options: Dictionary = {}
var world: Node2D
var deadline: int
var opened := false
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
## What a player sees of the seeded layout (16d), comparable between host and friend.
func _layout() -> Dictionary:
    return {"seed": world.layout.seed, "stone": str(world.trial.stone), "wood_3": str(world.camp.sites.wood_3.position), "trees": str(world.layout.trees), "decorations": world.get_node("Decorations").get_child_count()}
func _run() -> void:
    session = root.get_node("GameSession")
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    if options.mode == "server":
        var meta := {"name": "Friends Test", "seed": 4242, "created": 1, "last_played": 1}
        if session.start_host(int(options.port), options.save, false, meta) != OK:
            _report({"error": "Solo host could not start"})
            quit(1)
            return
        _report({"ready": true, "listening": session.listening, "offline_peer": session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "records": session.records.keys(), "meta": session.world_meta, "layout": _layout()})
    else:
        session.session_failed.connect(func(message: String):
            _report({"denied": message})
            quit(0)
        )
        session.join_host("127.0.0.1", int(options.port), options.identity, options.get("race", "Slime"))
        await session.character_assigned
        while session.latest_snapshot.is_empty():
            await process_frame
        await create_timer(0.3).timeout
        _report({"joined": true, "id": session.local_character_id, "meta": session.latest_snapshot.get("meta", {}), "players": session.latest_snapshot.players.keys(), "layout": _layout(), "race": session.latest_snapshot.players[session.local_character_id].progression.race, "max_hp": session.latest_snapshot.players[session.local_character_id].health.maximum, "magicules": session.latest_snapshot.players[session.local_character_id].magicules.maximum})
func _process(_delta: float) -> bool:
    if Time.get_ticks_msec() > deadline:
        _report({"error": "Worlds integration timed out"})
        quit(1)
        return false
    if world == null or session == null or not session.active:
        return false
    if options.mode == "server" and not opened and FileAccess.file_exists(options.phase):
        opened = true
        var result: Error = session.open_to_friends(int(options.port))
        _report({"ready": true, "opened": result == OK, "listening": session.listening, "world_id": session.world_id})
    if FileAccess.file_exists(options.stop):
        if options.mode == "server":
            var saved: Dictionary = session.persistent_document()
            _report({"saved": session.save_world() == OK, "players": saved.players.keys(), "meta": saved.meta, "world_id": session.world_id})
        session.stop_session(true)
        quit(0)
        return false
    return false
