extends SceneTree
## Host/client actor for network_forms.py: owned transformation requests and replicated forms.
var session: Node
var options: Dictionary = {}
var world: Node2D
var deadline: int
var acted := false
var joined := 0
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
func _forms(players: Dictionary) -> Dictionary:
    var result := {}
    for id in players:
        result[id] = players[id].form.id
    return result
func _run() -> void:
    session = root.get_node("GameSession")
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    if options.mode == "server":
        if session.start_host(int(options.port), options.save) != OK:
            _report({"error": "Host could not start"})
            quit(1)
            return
        if not options.has("reload"):
            # Only the first guest has analyzed a Gnasher, so only it may take Gnasher Form.
            session.player_joined.connect(func(actor: Node2D):
                joined += 1
                actor.position = Vector2(440 + joined * 40, 340)
                if joined == 1:
                    actor.get_node("SkillBook").record_analysis(&"forest_gnasher")
            )
        _report({"ready": true, "forms": _forms(session.document().players)})
    else:
        session.join_host("127.0.0.1", int(options.port), options.identity)
        await session.character_assigned
        while session.latest_snapshot.is_empty():
            await process_frame
        _report({"ready": true, "id": session.local_character_id})
func _process(_delta: float) -> bool:
    if Time.get_ticks_msec() > deadline:
        _report({"error": "Form integration timed out"})
        quit(1)
        return false
    if world == null or session == null or not session.active:
        return false
    if FileAccess.file_exists(options.stop):
        if options.mode == "server":
            _report({"saved": session.save_world() == OK, "forms": _forms(session.document().players)})
        session.stop_session(true)
        quit(0)
        return false
    if options.mode == "client" and not acted and FileAccess.file_exists(options.phase):
        acted = true
        _act()
    return false
func _act() -> void:
    var actor = world.get_local_player()
    var guard: bool = not actor.try_transform("gnasher")
    session.request_action("transform", {"form": "gnasher"})
    session.request_action("transform", {"form": "gnasher"})
    await create_timer(0.8).timeout
    var me: Dictionary = session.latest_snapshot.players[session.local_character_id]
    _report({"phase": true, "id": session.local_character_id, "guard": guard, "forms": _forms(session.latest_snapshot.players), "magicules": me.magicules.current, "analyzed": me.skill_evidence.analyzed, "local_form": actor.form})
