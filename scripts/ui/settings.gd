extends RefCounted
## Local settings: display (step 22: fullscreen, window scale) and sound/effects (step 23: music
## and effects volume 0..1, mute, reduced effects). Stored per machine in user://settings.cfg,
## never in world saves, and never sent to the host.
const DEFAULTS := {"fullscreen": false, "scale": 2, "music": 0.7, "sfx": 0.8, "muted": false, "reduced": false, "hud": 0.75, "controls": true}
const SCALES := [1, 2, 3]
## HUD size (user request: the HUD was too big) and whether the controls line is shown.
const HUD_SIZES := [0.65, 0.75, 0.85, 1.0]
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
        for key in ["music", "sfx"]:
            var volume: Variant = file.get_value("sound", key, DEFAULTS[key])
            values[key] = clampf(float(volume), 0.0, 1.0) if (volume is int or volume is float) and is_finite(float(volume)) else DEFAULTS[key]
        for key in ["muted", "reduced"]:
            var flag: Variant = file.get_value("sound", key, DEFAULTS[key])
            values[key] = flag is bool and flag
        var hud: Variant = file.get_value("display", "hud", DEFAULTS.hud)
        values.hud = float(hud) if (hud is int or hud is float) and HUD_SIZES.has(snappedf(float(hud), 0.01)) else DEFAULTS.hud
        var controls: Variant = file.get_value("display", "controls", DEFAULTS.controls)
        values.controls = controls if controls is bool else DEFAULTS.controls
    return values

static func save_settings(values: Dictionary) -> Error:
    var file := ConfigFile.new()
    file.set_value("display", "fullscreen", bool(values.fullscreen))
    file.set_value("display", "scale", int(values.scale))
    file.set_value("display", "hud", float(values.get("hud", DEFAULTS.hud)))
    file.set_value("display", "controls", bool(values.get("controls", DEFAULTS.controls)))
    for key in ["music", "sfx", "muted", "reduced"]:
        file.set_value("sound", key, values.get(key, DEFAULTS[key]))
    return file.save(path)

## Apply to the game window (integer scaling of the 640x360 view), the audio buses and effects.
static func apply(values: Dictionary) -> void:
    preload("res://scripts/visual/effects.gd").reduced = bool(values.get("reduced", false))
    var tree := Engine.get_main_loop() as SceneTree
    if tree != null and tree.root.has_node("Audio"):
        tree.root.get_node("Audio").apply_settings(values)
    if tree != null:
        tree.call_group("hud_settings", "apply_hud_settings", values)
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
    # Sound (step 23): two volume sliders, mute and reduced effects.
    for entry in [["music", "Music", 126], ["sfx", "Effects", 146]]:
        var label := Label.new()
        label.text = entry[1]
        label.position = Vector2(14, entry[2])
        label.add_theme_font_size_override("font_size", 10)
        panel.add_child(label)
        var slider := HSlider.new()
        slider.name = entry[0].capitalize() + "Volume"
        slider.min_value = 0.0
        slider.max_value = 1.0
        slider.step = 0.05
        slider.value = values[entry[0]]
        slider.position = Vector2(70, entry[2] + 2)
        slider.size = Vector2(196, 14)
        slider.value_changed.connect(func(volume: float):
            values[entry[0]] = volume
            change.call()
        )
        panel.add_child(slider)
    for entry in [["muted", "Mute", 14], ["reduced", "Reduced effects", 120]]:
        var check := CheckButton.new()
        check.name = entry[0].capitalize()
        check.text = entry[1]
        check.position = Vector2(entry[2], 166)
        check.size = Vector2(104 if entry[0] == "muted" else 150, 24)
        check.add_theme_font_size_override("font_size", 10)
        check.button_pressed = values[entry[0]]
        check.toggled.connect(func(on: bool):
            values[entry[0]] = on
            change.call()
        )
        panel.add_child(check)
    # HUD size and the controls line (user request).
    var hud_label := Label.new()
    hud_label.text = "HUD size"
    hud_label.position = Vector2(14, 196)
    hud_label.add_theme_font_size_override("font_size", 10)
    panel.add_child(hud_label)
    var hud_buttons: Array = []
    for index in range(HUD_SIZES.size()):
        var button := Button.new()
        button.name = "Hud%d" % int(round(HUD_SIZES[index] * 100))
        button.text = "%d%%" % int(round(HUD_SIZES[index] * 100))
        button.toggle_mode = true
        button.button_pressed = is_equal_approx(values.hud, HUD_SIZES[index])
        button.position = Vector2(76 + index * 54, 192)
        button.size = Vector2(50, 22)
        button.add_theme_font_size_override("font_size", 10)
        panel.add_child(button)
        hud_buttons.append(button)
        button.pressed.connect(func():
            values.hud = HUD_SIZES[index]
            for other in range(hud_buttons.size()):
                hud_buttons[other].set_pressed_no_signal(other == index)
            change.call()
        )
    var controls := CheckButton.new()
    controls.name = "Controls"
    controls.text = "Show the controls line (F1)"
    controls.position = Vector2(14, 218)
    controls.size = Vector2(240, 24)
    controls.add_theme_font_size_override("font_size", 10)
    controls.button_pressed = values.controls
    controls.toggled.connect(func(on: bool):
        values.controls = on
        change.call()
    )
    panel.add_child(controls)
    var back := Button.new()
    back.name = "Back"
    back.text = "Back"
    back.position = Vector2(14, 246)
    back.size = Vector2(96, 24)
    back.pressed.connect(on_back)
    panel.add_child(back)
    return fullscreen
