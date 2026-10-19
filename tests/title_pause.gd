extends SceneTree
## Title and pause flow (step 22): title menu entries and keyboard focus with the slime marker,
## Continue = most recent valid world (damaged saves skipped), credits (required Kyrise line),
## local settings file, ornamented frames, and the pause overlay (card values, shortcuts into
## windows and back, Options, Resume) without granting anything.
const SETTINGS := preload("res://scripts/ui/settings.gd")
const HUD := preload("res://scripts/ui/game_hud.gd")
var checks := 0
var failures := 0
var session: Node
var dir: String
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
func _until(condition: Callable, seconds: float = 5.0) -> bool:
    var start := Time.get_ticks_msec()
    while not condition.call():
        if Time.get_ticks_msec() - start > seconds * 1000:
            return false
        await process_frame
    return true
func _menu() -> Control:
    var menu = load("res://scenes/menu/title_menu.tscn").instantiate()
    menu.worlds_dir = dir
    var old := current_scene
    root.add_child(menu)
    current_scene = menu
    if is_instance_valid(old) and old != menu:
        old.queue_free()
    await _frames(2)
    menu._show("main")
    await _frames(2)
    return menu
func _cancel(menu: Control) -> void:
    var event := InputEventAction.new()
    event.action = "ui_cancel"
    event.pressed = true
    menu._unhandled_input(event)

func _run() -> void:
    session = root.get_node("GameSession")
    dir = OS.get_temp_dir().path_join("tempestrpg-title-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    SETTINGS.path = dir.path_join("settings.cfg")
    # --- Settings file (local only)
    _check(SETTINGS.load_settings() == SETTINGS.DEFAULTS, "Without a settings file the defaults apply (windowed, 1280x720)")
    var custom := {"fullscreen": true, "scale": 3, "music": 0.25, "sfx": 0.5, "muted": true, "reduced": true, "hud": 0.65, "controls": false, "own_name": false, "keys": {}}
    SETTINGS.save_settings(custom)
    _check(SETTINGS.load_settings() == custom, "Settings (display and sound) are saved and read back")
    var bad := ConfigFile.new()
    bad.set_value("display", "scale", 7)
    bad.set_value("display", "fullscreen", "yes")
    bad.save(SETTINGS.path)
    _check(SETTINGS.load_settings() == SETTINGS.DEFAULTS, "Invalid settings fall back to the defaults")
    DirAccess.remove_absolute(SETTINGS.path)
    # --- Title menu
    var menu = await _menu()
    var labels: Array = []
    for key in ["new", "continue", "settings", "credits", "quit"]:
        labels.append(menu._entries[key].text)
    _check(labels == ["PLAY", "CONTINUE", "SETTINGS", "CREDITS", "QUIT"], "Title menu entries (user request: PLAY opens your characters first)")
    _check(menu.get_child(0).get_script() == load("res://scripts/menu/title_backdrop.gd") and menu._panels.main.get_theme_stylebox("panel").get("texture") != null, "Storm backdrop and an ornamented menu frame")
    _check(menu._entries["continue"].disabled and menu._continue_hint.text.is_empty(), "Continue is unavailable without a saved world")
    menu.continue_last()
    _check(menu._status.text.contains("No saved world") and session.pending_launch.is_empty(), "Continue without a save explains itself and launches nothing")
    _check(root.gui_get_focus_owner() == menu._entries.new, "Keyboard focus starts on Play")
    await _frames(1)
    _check(menu._marker.visible and menu._marker.target == menu._entries.new, "The slime marks the focused entry")
    menu._entries.settings.grab_focus()
    await _frames(1)
    _check(menu._marker.target == menu._entries.settings, "The marker follows the focus")
    menu._show("credits")
    var credits := ""
    for child in menu._panels.credits.get_children():
        if child is Label:
            credits += child.text + "\n"
        elif child is RichTextLabel:
            credits += child.get_parsed_text() + "\n"
    _check(credits.contains("Gear icons by Kyrise (https://kyrise.itch.io/)") and credits.contains("Ninja Adventure") and credits.contains("Pixel Crawler") and credits.contains("Kenney") and credits.contains("Dogobongocat") and credits.contains("Daniel Linssen"), "Credits name every art pack and font, with the required Kyrise attribution")
    _cancel(menu)
    _check(menu._panels.main.visible and not menu._panels.credits.visible, "Esc steps back to the main menu")
    menu._show("settings")
    var fullscreen: CheckButton = menu._panels.settings.find_child("Fullscreen", true, false)
    fullscreen.button_pressed = true
    _check(SETTINGS.load_settings().fullscreen and FileAccess.file_exists(SETTINGS.path) and menu._panels.settings.find_child("Scale2", true, false).disabled, "Settings toggles are written to the local file at once")
    fullscreen.button_pressed = false
    _check(not SETTINGS.load_settings().fullscreen and not menu._panels.settings.find_child("Scale2", true, false).disabled, "Turning fullscreen off re-enables the window sizes")
    # --- Create a world, quit, then Continue picks it (damaged newer files are skipped)
    menu._show("new")
    menu._name_field.text = "Continue World"
    menu._seed_field.text = "77"
    menu.create_world()
    _check(await _until(func(): return session.active and current_scene != null and current_scene.scene_file_path == session.WORLD_SCENE), "New Game opens a world")
    await _frames()
    var world = current_scene
    var hud = world.get_node("HUD")
    var actor = world.get_local_player()
    # --- Pause overlay
    hud.open_pause()
    await _frames(1)
    _check(paused and hud._pause_panel.visible and hud._pause_menu.visible and root.gui_get_focus_owner() == hud._pause_buttons.resume, "Esc pause: frozen solo world, menu shown, focus on Resume")
    _check(hud._pause_card.hp_text.text == "HP %d / %d" % [actor.get_node("Health").current, actor.get_node("Health").maximum] and hud._pause_card.world[1].text == "Continue World" and hud._pause_card.zone[1].text == "The First Clearing", "The pause card shows the character's live values and the world")
    _check(HUD.play_time_text(3725.0) == "1h 02m" and hud._pause_card.time[0].text == "WORLD TIME", "World time is shown in hours and minutes")
    var health_before: int = actor.get_node("Health").current
    var magicules_before: float = actor.get_node("Magicules").current
    hud._pause_buttons.bag.pressed.emit()
    await _frames(1)
    _check(hud._modal.visible and not hud._pause_panel.visible, "Inventory & Equipment opens the bag from the pause menu")
    hud.close_inventory()
    _check(await _until(func(): return hud._pause_panel.visible and paused), "Closing the bag returns to the pause menu")
    hud._pause_buttons.tree.pressed.emit()
    await _frames(1)
    _check(hud.skill_tree.visible and not hud._pause_panel.visible, "Skill Tree opens from the pause menu")
    hud.skill_tree.close()
    _check(await _until(func(): return hud._pause_panel.visible), "Closing the skill tree returns to the pause menu")
    hud._pause_buttons.options.pressed.emit()
    _check(hud._pause_options.visible and not hud._pause_menu.visible, "Options shows the settings inside the pause overlay")
    hud._pause_options.find_child("Back", true, false).pressed.emit()
    _check(hud._pause_menu.visible and not hud._pause_options.visible and root.gui_get_focus_owner() == hud._pause_buttons.options, "Back returns to the pause menu")
    _check(actor.get_node("Health").current == health_before and is_equal_approx(actor.get_node("Magicules").current, magicules_before), "Browsing the menus grants nothing")
    hud._pause_buttons.resume.pressed.emit()
    await _frames(1)
    _check(not paused and not hud._pause_panel.visible and not hud.menu_open(), "Resume continues the world")
    hud.open_pause()
    hud._pause_buttons.quit.pressed.emit()
    _check(await _until(func(): return not session.active and current_scene != null and current_scene.scene_file_path == session.TITLE_SCENE), "Save & quit returns to the title")
    var broken := FileAccess.open(dir.path_join("zz_broken.json"), FileAccess.WRITE)
    broken.store_string("{ not json")
    broken.close()
    menu = current_scene
    menu.worlds_dir = dir
    menu._show("main")
    await _frames(2)
    _check(menu.last_world().get("name", "") == "Continue World" and not menu._entries["continue"].disabled and menu._continue_hint.text.begins_with("Continue: Continue World"), "Continue offers the last valid world; the damaged file is skipped")
    _check(root.gui_get_focus_owner() == menu._entries["continue"], "With a save, focus starts on Continue")
    menu.continue_last()
    _check(await _until(func(): return session.active and current_scene.scene_file_path == session.WORLD_SCENE), "Continue opens the world")
    await _frames()
    _check(session.world_meta.name == "Continue World" and not session.listening, "Continue restores the same world, solo")
    session.quit_to_title()
    await _until(func(): return current_scene != null and current_scene.scene_file_path == session.TITLE_SCENE)
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Title and pause checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
