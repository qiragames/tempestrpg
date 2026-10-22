extends SceneTree
## Mouse aim and the dash (user requests): strikes, skills and dashes go where the mouse points
## (guests send the aim; nonsense is refused), the character faces the mouse while it is used,
## left click strikes, right click dashes about three tiles for a third of the stamina with a
## moment of invulnerability and a short cooldown.
var world: Node2D
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
    _check(InputMap.action_get_events("dash").any(func(event): return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT), "Dash is on right click")
    _check(InputMap.action_get_events("attack").any(func(event): return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT), "Left click strikes")
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-aim-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24921, dir.path_join("aim.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    if world.get_node("HUD").dialog_panel.is_open():
        world.get_node("HUD").dialog_panel.close()
    me.input_blocked = false
    me.global_position = Vector2(480, 330)
    await _frames(2)
    # Facing: the mouse wins while it is used, else the walking direction.
    me._face(Vector2.RIGHT, Vector2.UP)
    _check(me.facing == Vector2.UP, "The character faces the mouse")
    me._face(Vector2.RIGHT, Vector2.ZERO)
    _check(me.facing == Vector2.RIGHT, "Without a mouse it faces where it walks")
    # Aimed strikes (what a guest sends).
    me.get_node("MeleeAttack").cooldown_left = 0.0
    _check(session.apply_action(me, "attack", {"aim": [0.0, -1.0]}) and me.facing.is_equal_approx(Vector2.UP), "A strike goes where the mouse points")
    var rejected: int = session.rejected_requests
    session.apply_action(me, "attack", {"aim": [NAN, 0.0]})
    session.apply_action(me, "attack", {"aim": [40.0, 0.0]})
    session.apply_action(me, "attack", {"aim": "left"})
    _check(session.rejected_requests == rejected + 3, "Nonsense aims are refused")
    # The dash.
    me.stamina = 1.0
    var start: Vector2 = me.global_position
    _check(me.dash(Vector2.RIGHT) and me.get_node("Health").immunity_left > 0.0, "Dashing: a moment of invulnerability")
    await _frames(20)
    var moved: float = me.global_position.distance_to(start)
    _check(moved > 36.0 and moved < 60.0 and me.stamina < 0.75, "About three tiles for a third of the stamina (%.0f px)" % moved)
    _check(not me.dash(Vector2.RIGHT), "A short cooldown between dashes")
    await _frames(40)
    me.stamina = 0.2
    _check(not me.dash(Vector2.LEFT), "Too tired to dash below a third")
    me.stamina = 1.0
    me._dash_ready_msec = 0
    _check(session.apply_action(me, "dash", {"aim": [0.0, 1.0]}), "Guests dash through the dash intent")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Aim and dash checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
