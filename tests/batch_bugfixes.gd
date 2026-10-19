extends SceneTree
## User reports after v1.3.1: the goblin ally is back at your side right away after you respawn
## (or travel) far away, so founding the camp works again; the Old Master lives at the camp site
## in every world (also before the camp is founded, e.g. in a friend's world); joining with one of
## your own characters hides the race picker.
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
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-bugs-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24881, dir.path_join("bugs.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var camp: Node = world.camp
    # --- The Old Master before the camp is founded.
    _check(not camp.state.founded and world.class_master.present(), "The Old Master is there before the camp is founded")
    me.global_position = world.class_master.position_in_world() + Vector2(0, 20)
    _check(world.class_master.near(me), "...and can be talked to")
    # --- The goblin catches up.
    var ally = world.get_node("GoblinAlly")
    ally.owner_id = me.character_id
    ally.display_name = "Aster"
    ally.race = "Hobgoblin"
    ally.work_role = "follow"
    ally.global_position = Vector2(480, 340)
    me.global_position = Vector2(480, 340) + Vector2(900, 0)
    await _frames(3)
    _check(ally.global_position.distance_to(me.global_position) < 40.0, "Far from you (a respawn, a ferry), the goblin is at your side at once")
    var before: Vector2 = ally.global_position
    me.global_position += Vector2(60, 0)
    await _frames(3)
    _check(ally.global_position.distance_to(before) < 20.0, "Close by it still walks")
    # --- Founding the camp with the goblin that came along.
    me.global_position = camp.SITE + Vector2(0, 30)
    await _frames(4)
    _check(ally.global_position.distance_to(camp.SITE) <= 80.0, "The goblin is at the camp site with you")
    _check(camp.can_found(me) and camp.transact(me, "found", String(camp.state.id)), "The camp can be founded")
    camp.restore(camp.initial_state(world.layout.deposits))
    # --- The join screen.
    var menu: Control = load("res://scenes/menu/title_menu.tscn").instantiate() if ResourceLoader.exists("res://scenes/menu/title_menu.tscn") else null
    if menu != null:
        root.add_child(menu)
        await _frames(2)
        menu._own_characters = [{"race": "Human", "level": 20, "world": "Home", "path": "x"}]
        menu._join_character.clear()
        menu._join_character.add_item("New character (race below)")
        menu._join_character.add_item("Human, level 20")
        menu._join_character.select(1)
        menu._join_character.item_selected.emit(1)
        _check(not menu._join_race.visible, "Your own character keeps its race: no race picker")
        menu._join_character.select(0)
        menu._join_character.item_selected.emit(0)
        _check(menu._join_race.visible, "A new character picks its race")
        menu.queue_free()
    else:
        _check(false, "Title menu scene found")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Batch bug fix checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
