extends RefCounted
## Local display settings (step 22): fullscreen and window scale. Stored per machine in
## user://settings.cfg, never in world saves, and never sent to the host.
const DEFAULTS := {"fullscreen": false, "scale": 2}
const SCALES := [1, 2, 3]
const UI := preload("res://scripts/ui/ui_style.gd")
## Tests point this at a temporary file.
static var path: String = "user://settings.cfg"

static func load_settings() -> Dictionary:
    var values: Dictionary = DEFAULTS.duplicate()
    var file := ConfigFile.new()
    if file.load(path) == OK:
        var fullscreen: Variant = file.get_value("display", "fullscreen", DEFAULTS.fullscreen)
        values.fullscreen = fullscreen is bool and fullscreen
        var scale: Variant = file.get_value("display", "scale", DEFAULTS.scale)
        values.scale = int(scale) if (scale is int or scale is float) and int(scale) in SCALES else DEFAULTS.scale
    return values

static func save_settings(values: Dictionary) -> Error:
    var file := ConfigFile.new()
    file.set_value("display", "fullscreen", bool(values.fullscreen))
    file.set_value("display", "scale", int(values.scale))
    return file.save(path)

## Apply to the game window (integer scaling of the 640x360 view).
static func apply(values: Dictionary) -> void:
    if DisplayServer.get_name() == "headless":
        return
    if values.fullscreen:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        return
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
    var size := Vector2i(640, 360) * int(values.scale)
    DisplayServer.window_set_size(size)
    var screen: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
    DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)

## Settings controls inside `panel` (used by the title menu and the pause menu's Options).
## Returns the first focusable control.
static func build(panel: Control, on_back: Callable) -> Control:
    var values := load_settings()
    var heading := Label.new()
    heading.text = "SETTINGS"
    heading.position = Vector2(14, 10)
    heading.add_theme_font_size_override("font_size", 13)
    UI.heading(heading)
    panel.add_child(heading)
    var fullscreen := CheckButton.new()
    fullscreen.name = "Fullscreen"
    fullscreen.text = "Fullscreen"
    fullscreen.position = Vector2(14, 40)
    fullscreen.size = Vector2(260, 26)
    fullscreen.button_pressed = values.fullscreen
    panel.add_child(fullscreen)
    var scale_label := Label.new()
    scale_label.text = "Window size"
    scale_label.position = Vector2(14, 76)
    scale_label.add_theme_font_size_override("font_size", 10)
    panel.add_child(scale_label)
    var scale_buttons: Array = []
    for index in range(SCALES.size()):
        var button := Button.new()
        button.name = "Scale%d" % SCALES[index]
        button.text = "%dx%d" % [640 * SCALES[index], 360 * SCALES[index]]
        button.toggle_mode = true
        button.position = Vector2(14 + index * 90, 94)
        button.size = Vector2(84, 26)
        button.add_theme_font_size_override("font_size", 10)
        panel.add_child(button)
        scale_buttons.append(button)
    var refresh := func():
        for index in range(SCALES.size()):
            scale_buttons[index].set_pressed_no_signal(values.scale == SCALES[index])
            scale_buttons[index].disabled = values.fullscreen
    var change := func():
        save_settings(values)
        apply(values)
        refresh.call()
    fullscreen.toggled.connect(func(on: bool):
        values.fullscreen = on
        change.call()
    )
    for index in range(SCALES.size()):
        scale_buttons[index].pressed.connect(func():
            values.scale = SCALES[index]
            change.call()
        )
    refresh.call()
    var note := Label.new()
    note.text = "Saved on this computer only; worlds and friends are not affected."
    note.position = Vector2(14, 128)
    note.size = Vector2(260, 30)
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_font_size_override("font_size", 9)
    note.add_theme_color_override("font_color", UI.TEXT_DIM)
    panel.add_child(note)
    var back := Button.new()
    back.name = "Back"
    back.text = "Back"
    back.position = Vector2(14, 166)
    back.size = Vector2(96, 30)
    back.pressed.connect(on_back)
    panel.add_child(back)
    return fullscreen
