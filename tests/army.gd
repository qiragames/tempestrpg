extends SceneTree
## Armies (M11h): soldiers need a founded nation and the village; two per tier; they cost Zeni,
## follow their recruiter, fight creatures near them, rise in rank, recover after falling, obey
## orders; sieges grow with the army; saved with the world; the intent and the window.
const ARMY := preload("res://scripts/nation/army.gd")
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
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-army-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24824, dir.path_join("army.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var army: Node = world.army
    var camp: Node = world.camp
    me.global_position = camp.SITE + Vector2(20, 0)
    me.progression["zeni"] = 100000
    _check(army.capacity() == 0 and not army.recruit(me), "No nation, no soldiers")
    camp.state.founded = true
    camp.state.founder = "host"
    _check(army.capacity() == ARMY.PER_TIER, "A founded nation fields two soldiers")
    me.global_position = camp.SITE + Vector2(5000, 0)
    _check(not army.recruit(me), "Recruiting happens inside the village")
    me.global_position = camp.SITE + Vector2(20, 0)
    var zeni: int = int(me.progression.zeni)
    _check(session.apply_action(me, "army", {"operation": "recruit"}) and army.soldiers_of("host").size() == 1 and int(me.progression.zeni) == zeni - army.price(me), "A recruit for Zeni")
    _check(army.recruit(me) and not army.recruit(me) and army.state().soldiers.size() == 2, "Two per tier, no more")
    await _frames(3)
    _check(army._bodies.size() == 2, "Soldiers are drawn")
    # Following.
    me.global_position = camp.SITE + Vector2(200, 0)
    for _i in range(120):
        army._physics_process(1.0 / 30.0)
    var soldier: Dictionary = army.state().soldiers[0]
    _check(Vector2(float(soldier.pos[0]), float(soldier.pos[1])).distance_to(me.global_position) < 60.0, "Soldiers follow their recruiter")
    # Fighting (the only creature nearby).
    for other in get_nodes_in_group("enemies"):
        if other.global_position.distance_to(me.global_position) < 500.0:
            other.get_parent().remove_child(other)
            other.queue_free()
    await _frames(1)
    var foe = load("res://scenes/enemies/forest_gnasher.tscn").instantiate()
    foe.entity_id = "army_test_gnasher"
    foe.position = me.global_position + Vector2(40, 0)
    world.add_child(foe)
    world.wire_enemy(foe)
    foe.set_physics_process(false)
    var hp: int = foe.get_node("Health").current
    for _i in range(90):
        army._physics_process(1.0 / 30.0)
    _check(foe.get_node("Health").current < hp, "Soldiers attack a creature near them")
    # Ranks and falling.
    soldier.kills = 30
    _check(ARMY.rank_of(soldier)[0] == "Champion" and ARMY.stats(soldier)[1] > ARMY.stats({"level": soldier.level, "kills": 0})[1], "Champions hit harder")
    soldier.hp = 0
    soldier.down = 0.0
    soldier.hp = -1
    soldier["down"] = 0.0
    # A fallen soldier recovers at the camp.
    soldier.down = 0.5
    army._physics_process(1.0)
    _check(float(soldier.down) == 0.0 and int(soldier.hp) == ARMY.stats(soldier)[0] and Vector2(float(soldier.pos[0]), float(soldier.pos[1])).distance_to(camp.SITE) < 40.0, "A fallen soldier recovers at the camp")
    # Orders.
    _check(session.apply_action(me, "army", {"operation": "command", "order": "hold"}) and army.state().soldiers.all(func(entry): return entry.order == "hold"), "Hold here")
    _check(not session.apply_action(me, "army", {"operation": "command", "order": "dance"}) and not session.apply_action(me, "army", {"operation": "conquer"}), "Unknown orders are refused")
    # Larger sieges.
    var siege: Node = world.siege
    var before: int = world.get_tree().get_nodes_in_group("enemies").size()
    siege.state.side = 0
    siege._next_wave()
    var spawned: int = siege.creatures().size()
    _check(spawned >= 2 + 2 * maxi(1, camp.tier()) + 1 + army.state().soldiers.size() - 2, "Siege waves grow with the army (%d invaders)" % spawned)
    siege._clear()
    # Saved, the window, sending home.
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("army.json")))
    _check(raw.progression.army.soldiers.size() == 2, "Soldiers are saved with the world")
    var hud: CanvasLayer = world.get_node("HUD")
    hud.quest_panel._queue.clear()
    hud.dialog_panel.close()
    hud.army_panel.open()
    await _frames(2)
    _check(hud.army_panel.visible and hud.army_panel._list.get_child_count() == 2, "C opens the army window")
    hud.army_panel.close_panel()
    _check(session.apply_action(me, "army", {"operation": "dismiss"}) and army.state().soldiers.is_empty(), "Sending them home")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Army checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
