extends SceneTree
## Actor for network_import.py (M10): a friend's own character in a host's world, with real
## processes. Modes: "make" (the friend's own world with a strong character), "server" (the host,
## with or without guests' own characters), "client" (the friend bringing their character).
var session: Node
var options: Dictionary = {}
var world: Node2D
var deadline: int
func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        var pair := argument.trim_prefix("--").split("=", true, 1)
        options[pair[0]] = pair[1] if pair.size() == 2 else ""
    deadline = Time.get_ticks_msec() + 30000
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
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    if options.mode == "make":
        var meta := {"name": "Home", "seed": 7, "created": 1, "last_played": 1}
        if session.start_host(int(options.port), options.save, false, meta, "Demon") != OK:
            _report({"error": "Own world could not start"})
            quit(1)
            return
        var me = world.get_local_player()
        me.gain_experience(preload("res://scripts/progression/leveling.gd").xp_for_level(20), "test")
        me.progression.zeni = 12345
        me.progression.fish_log = {"leviathan": 1}
        me.progression.chests = ["chest_keep"]
        world.quests.unlock(me)
        session.apply_action(me, "title", {"id": "leviathan"})
        me.get_node("Inventory").add_material("ore_iron", 7)
        var rng := RandomNumberGenerator.new()
        rng.seed = 5
        me.add_item(preload("res://scripts/items/gear_catalogue.gd").roll("padded_vest", 2, rng))
        me.position = Vector2(321, 222)
        _report({"made": session.save_world() == OK})
        session.stop_session(false)
        quit(0)
        return
    if options.mode == "server":
        var meta := {"name": "Friend World", "seed": 99, "created": 1, "last_played": 1}
        if session.start_host(int(options.port), options.save, true, meta) != OK:
            _report({"error": "Host could not start"})
            quit(1)
            return
        session.set_imports(options.get("imports", "") == "yes")
        _report({"ready": true, "imports": session.world_meta.get("imports", false)})
        while not FileAccess.file_exists(options.stop):
            if Time.get_ticks_msec() > deadline:
                _report({"error": "Host timed out"})
                quit(1)
                return
            await process_frame
        var saved: Dictionary = session.persistent_document()
        _report({"saved": session.save_world() == OK, "records": saved.players.keys(), "players": saved.players})
        session.stop_session(true)
        quit(0)
        return
    session.session_failed.connect(func(message: String):
        _report({"denied": message})
        quit(0)
    )
    session.import_path = options.own
    session.join_host("127.0.0.1", int(options.port), options.identity, "Slime")
    await session.character_assigned
    while session.latest_snapshot.is_empty() or not session.latest_snapshot.players.has(session.local_character_id):
        await process_frame
    await create_timer(0.3).timeout
    var mine: Dictionary = session.latest_snapshot.players[session.local_character_id]
    var arrived := {"level": mine.progression.level, "race": mine.progression.race, "zeni": mine.progression.zeni, "items": mine.gear.items.map(func(item): return item.id), "title": mine.progression.get("title", ""), "chests": mine.progression.get("chests", []), "points": mine.progression.skill_points}
    # Spend a skill point in the friend's world, then take the character home.
    session.request_action("tree", {"operation": "buy", "id": "demon_hunger"})
    await create_timer(0.6).timeout
    session._request_sync.rpc_id(1)
    await session.character_synced
    _report({"joined": true, "arrived": arrived, "id": session.local_character_id})
    session.stop_session(false)
    quit(0)
func _process(_delta: float) -> bool:
    if Time.get_ticks_msec() > deadline:
        _report({"error": "Import integration timed out"})
        quit(1)
    return false
