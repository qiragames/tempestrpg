extends SceneTree
## Host/client actor for network_trial.py: personal trial start, replication and credit.
var session: Node
var options: Dictionary = {}
var world: Node2D
var deadline: int
var acted := false
var joined := 0
var active_time := 0.0
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
func _evidence(players: Dictionary) -> Dictionary:
    var result := {}
    for id in players:
        result[id] = {"trials": players[id].skill_evidence.trials, "skills": players[id].skill_ids}
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
            # The first guest qualifies (knows Piercing Fang); the second only helps.
            session.player_joined.connect(func(actor: Node2D):
                joined += 1
                actor.position = world.trial.STONE + Vector2(joined * 16 - 24, 24)
                if joined == 1:
                    actor.get_node("SkillBook").record_analysis(&"forest_gnasher")
                    actor.get_node("SkillBook").record_analysis(&"thornback_gnasher")
            )
        _report({"ready": true, "evidence": _evidence(session.persistent_document().players)})
    else:
        session.join_host("127.0.0.1", int(options.port), options.identity)
        await session.character_assigned
        while session.latest_snapshot.is_empty():
            await process_frame
        _report({"ready": true, "id": session.local_character_id})
func _process(delta: float) -> bool:
    if Time.get_ticks_msec() > deadline:
        _report({"error": "Trial integration timed out"})
        quit(1)
        return false
    if world == null or session == null or not session.active:
        return false
    if FileAccess.file_exists(options.stop):
        if options.mode == "server":
            var saved: Dictionary = session.persistent_document()
            _report({"saved": session.save_world() == OK, "evidence": _evidence(saved.players), "trial_enemies": saved.enemies.filter(func(e): return String(e.id).begins_with("trial_")).size(), "has_trial": saved.has("trial")})
        session.stop_session(true)
        quit(0)
        return false
    if options.mode == "server" and world.trial.state.active:
        # Host-side stand-in for the fight: after the clients observed the trial, defeat its creatures.
        active_time += delta
        if active_time > 1.2:
            for creature in world.trial.creatures():
                creature.get_node("Health").take_damage(999)
    if options.mode == "client" and not acted and FileAccess.file_exists(options.phase):
        acted = true
        _act()
    return false
func _act() -> void:
    var me: String = session.local_character_id
    var qualified: bool = "piercing_fang" in session.latest_snapshot.players[me].skill_ids
    var guard: bool = not world.trial.try_start(world.get_local_player())
    if qualified:
        session.request_action("trial", {"operation": "start"})
        session.request_action("trial", {"operation": "start"})
    else:
        await create_timer(0.3).timeout
        session.request_action("trial", {"operation": "start"})
    await create_timer(0.7).timeout
    var during: Dictionary = session.latest_snapshot.get("trial", {})
    var creatures: int = session.latest_snapshot.enemies.filter(func(e): return String(e.id).begins_with("trial_")).size()
    var start := Time.get_ticks_msec()
    while session.latest_snapshot.get("trial", {}).get("active", false) and Time.get_ticks_msec() - start < 6000:
        await process_frame
    await create_timer(0.4).timeout
    var mine: Dictionary = session.latest_snapshot.players[me]
    _report({"phase": true, "id": me, "qualified": qualified, "guard": guard, "during": during, "creatures": creatures, "trials": mine.skill_evidence.trials, "skills": mine.skill_ids, "slots": mine.slots, "after_active": session.latest_snapshot.trial.active})
