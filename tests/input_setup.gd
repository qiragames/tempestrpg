extends SceneTree
## Controller support and key rebinding (M11g): gamepad events reach the actions (once, however
## often installed), keys can be rebound (keeping the gamepad), clashes are found, the choices are
## saved with the settings and come back at start, and the keys list rebinds by a key press.
const INPUT := preload("res://scripts/ui/input_setup.gd")
const SETTINGS := preload("res://scripts/ui/settings.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _count(action: String, kind: String) -> int:
    return InputMap.action_get_events(action).filter(func(event): return event.get_class() == kind).size()

func _run() -> void:
    INPUT.install()
    INPUT.install()
    _check(_count("attack", "InputEventJoypadButton") == 1 and _count("move_left", "InputEventJoypadMotion") == 1 and _count("skill_4", "InputEventJoypadMotion") == 1, "Gamepad buttons and sticks are added once")
    var press := InputEventJoypadButton.new()
    press.button_index = JOY_BUTTON_A
    press.pressed = true
    _check(InputMap.event_is_action(press, "attack"), "A strikes")
    var stick := InputEventJoypadMotion.new()
    stick.axis = JOY_AXIS_LEFT_X
    stick.axis_value = -0.9
    _check(InputMap.event_is_action(stick, "move_left"), "The left stick moves")
    var before := INPUT.key_of("attack")
    _check(INPUT.rebind("attack", KEY_K) and INPUT.key_of("attack") == KEY_K and _count("attack", "InputEventKey") == 1 and _count("attack", "InputEventJoypadButton") == 1, "Strike rebound to K (the gamepad stays)")
    _check(not INPUT.rebind("ui_accept", KEY_K) and not INPUT.rebind("attack", 0), "Only listed actions and real keys")
    _check("attack" in INPUT.clashes() and "skill_tree" in INPUT.clashes(), "K is also the skill tree's key: a clash")
    # Settings round trip.
    var dir := OS.get_temp_dir().path_join("tempestrpg-keys-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    SETTINGS.path = dir.path_join("settings.cfg")
    var values := SETTINGS.load_settings()
    values["keys"] = {"attack": KEY_H, "not_an_action": KEY_Q}
    _check(SETTINGS.save_settings(values) == OK, "Keys saved with the settings")
    var loaded := SETTINGS.load_settings()
    _check(loaded.keys.get("attack") == KEY_H and not loaded.keys.has("not_an_action"), "Saved keys come back (unknown actions dropped)")
    SETTINGS.apply(loaded)
    _check(INPUT.key_of("attack") == KEY_H, "...and apply at start")
    # The keys list.
    var panel := Panel.new()
    panel.size = Vector2(300, 280)
    root.add_child(panel)
    var overlay: Control = SETTINGS.open_keys(panel, loaded)
    await process_frame
    var grid: GridContainer = overlay.get_child(1)
    _check(grid.get_child_count() == INPUT.REBINDABLE.size() * 2, "Every rebindable action is listed")
    var catcher: Control = overlay.get_children().filter(func(node): return node.get_script() == preload("res://scripts/ui/key_catcher.gd"))[0]
    (grid.get_child(1) as Button).pressed.emit()
    _check(catcher.on_key.call(KEY_I) and INPUT.key_of("move_up") == KEY_I and SETTINGS.load_settings().keys.get("move_up") == KEY_I, "Change, then a key: Move up is I (saved)")
    INPUT.rebind("attack", before)
    INPUT.rebind("move_up", KEY_W)
    panel.queue_free()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Input checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
