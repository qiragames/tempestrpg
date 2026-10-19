extends SceneTree
## Key icons and mouse bindings (user request): every action can be bound to a key or a mouse
## button (Options → Keys, saved on this computer), and the HUD shows the bound key or mouse as an
## icon where it belongs — hotbar slots, the controls line, the "F" prompt at trees and rocks.
const ICONS := preload("res://scripts/ui/key_icons.gd")
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

func _frames(count: int = 3) -> void:
    for _i in range(count):
        await physics_frame
        await process_frame

func _run() -> void:
    _check(ICONS.icon(KEY_F) != null and ICONS.icon(KEY_F).get_width() == 16 and ICONS.icon(KEY_SHIFT).get_width() == 32 and ICONS.icon(KEY_SPACE).get_width() == 48, "Keys have icons; wide keys keep their width")
    var mouse4: int = ICONS.MOUSE_BASE + MOUSE_BUTTON_XBUTTON1
    _check(ICONS.icon(ICONS.MOUSE_BASE + MOUSE_BUTTON_LEFT) != null and ICONS.icon(mouse4) != null and ICONS.name_of(mouse4) == "Mouse 8" or ICONS.name_of(mouse4) == "Mouse %d" % MOUSE_BUTTON_XBUTTON1, "Mouse buttons have icons and names")
    _check(ICONS.has_own_icon(KEY_Q) and ICONS.has_own_icon(mouse4) and not ICONS.has_own_icon(KEY_F13), "Unknown keys fall back to a blank key")
    # Binding a hotbar slot to a mouse button.
    var before: int = INPUT.key_of("skill_4")
    _check(INPUT.rebind("skill_4", mouse4) and INPUT.key_of("skill_4") == mouse4 and InputMap.action_get_events("skill_4").any(func(event): return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_XBUTTON1), "Skill 4 can be bound to a mouse button")
    _check(not InputMap.action_get_events("skill_4").any(func(event): return event is InputEventKey), "...which replaces its key")
    _check(not INPUT.rebind("skill_4", ICONS.MOUSE_BASE + 40), "Nonsense mouse buttons are refused")
    var press := InputEventMouseButton.new()
    press.button_index = MOUSE_BUTTON_XBUTTON1
    press.pressed = true
    _check(InputMap.event_is_action(press, "skill_4"), "Pressing that mouse button triggers the slot")
    # Saved and restored.
    var values: Dictionary = {}
    values["keys"] = {"skill_4": mouse4}
    InputMap.action_erase_events("skill_4")
    INPUT.install(values.keys)
    _check(INPUT.key_of("skill_4") == mouse4, "The mouse binding comes back from the settings")
    # The HUD follows the binding.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-keys-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    session.start_host(24901, dir.path_join("keys.json"), false)
    await _frames(10)
    var hud: CanvasLayer = world.get_node("HUD")
    var badge: TextureRect = hud.get_node("SlotKey4")
    await _frames(40)
    _check(badge.texture == ICONS.icon(mouse4) and badge.tooltip_text == ICONS.name_of(mouse4), "Hotbar slot 4 shows the mouse icon")
    _check(hud.get_node("SlotKey1").texture == ICONS.icon(KEY_1), "Slot 1 shows its key")
    INPUT.rebind("skill_4", before if before > 0 else KEY_4)
    await _frames(40)
    _check(badge.texture == ICONS.icon(INPUT.key_of("skill_4")), "Rebinding again updates the icon")
    var keys: Node = hud.get_node("Controls/Keys")
    _check(keys.get_children().filter(func(child): return child is TextureRect).size() >= 10, "The controls line shows key icons")
    var me = world.get_local_player()
    me.global_position = world.nodes.work_point(world.nodes.DECOR_BASE) + Vector2(0, 6)
    hud.dialog_panel.close()
    await _frames(6)
    var prompt_key: TextureRect = hud.get_node_or_null("NodePromptKey")
    _check(prompt_key != null and prompt_key.visible and prompt_key.texture == ICONS.action_icon("interact") and not String(hud.get_node("NodePrompt").text).begins_with("F:"), "At a tree the prompt shows the interact key's icon")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Key icon checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
