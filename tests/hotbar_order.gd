extends SceneTree
## Sorting the hotbar (user request): drag a skill onto another slot and they swap (onto an empty
## slot it moves), right click clears a slot, and the skill menu puts an active skill on the
## hotbar or moves it one slot further per click. Host-checked through the assign_slot intent.
const TREE := preload("res://scripts/skills/skill_tree.gd")
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
    var dir := OS.get_temp_dir().path_join("tempestrpg-hotbar-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24931, dir.path_join("hotbar.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    var me = world.get_local_player()
    var hud: CanvasLayer = world.get_node("HUD")
    var book = me.get_node("SkillBook")
    var ids: Array = TREE.SKILLS.keys().slice(0, 2)
    for id in ids:
        book.grant_tree_skill(StringName(id))
    var a := StringName(ids[0])
    var b := StringName(ids[1])
    var slot_a: int = book._slots.find(a)
    var slot_b: int = book._slots.find(b)
    _check(slot_a >= 0 and slot_b >= 0 and slot_a != slot_b, "Two skills on the hotbar")
    # Dragging A onto B's slot swaps them.
    var data: Variant = hud._slot_drag(Vector2.ZERO, slot_a)
    _check(data is Dictionary and data.hotbar_skill == String(a) and hud._slot_can_drop(Vector2.ZERO, data, slot_b) and not hud._slot_can_drop(Vector2.ZERO, data, slot_a), "A skill can be dragged onto another slot")
    hud._slot_drop(Vector2.ZERO, data, slot_b)
    _check(book._slots[slot_b] == a and book._slots[slot_a] == b, "Dropping onto a taken slot swaps the two")
    var empty: int = book._slots.find(&"")
    hud._slot_drop(Vector2.ZERO, hud._slot_drag(Vector2.ZERO, slot_b), empty)
    _check(book._slots[empty] == a and book._slots[slot_b] == &"", "Onto an empty slot it moves")
    _check(hud._slot_drag(Vector2.ZERO, slot_b) == null, "Empty slots cannot be dragged")
    # Right click clears; the skill menu puts it back and moves it along.
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_RIGHT
    click.pressed = true
    hud._slots[empty].gui_input.emit(click)
    _check(not a in book._slots, "Right click clears a slot")
    session.apply_action(me, "assign_slot", {"slot": 7, "id": String(a)})
    _check(book._slots[7] == a, "The assign intent places a skill")
    _check(not session.apply_action(me, "assign_slot", {"slot": 9, "id": String(a)}) and not session.apply_action(me, "assign_slot", {"slot": 0, "id": "not_a_skill"}), "Nonsense slots and unknown skills are refused")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Hotbar order checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
