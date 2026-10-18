extends Control
## A small talking window (M4.7): who speaks, what they say, and a few options to choose from.
## Each option runs its own callback (usually a request to the host) and closes the window.
const UI := preload("res://scripts/ui/ui_style.gd")
const FRAME := Rect2(105, 96, 430, 244)

var hud: CanvasLayer
var _title: Label
var _text: Label
var _options: VBoxContainer
## M9c: the speaker's face (Ninja Adventure facesets), when there is one.
var _face: TextureRect
var _paused_before := false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "DialogPanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var window := Control.new()
    window.name = "Window"
    window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(window)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.55)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    window.add_child(backdrop)
    var frame := Panel.new()
    frame.position = FRAME.position
    frame.size = FRAME.size
    frame.add_theme_stylebox_override("panel", UI.ornate())
    window.add_child(frame)
    _title = UI.heading(hud._label("", FRAME.position + Vector2(14, 10), Vector2(FRAME.size.x - 28, 20), window, 14))
    # M13b: the words on a parchment page.
    var page := Panel.new()
    page.position = FRAME.position + Vector2(10, 32)
    page.size = Vector2(FRAME.size.x - 20, 80)
    page.add_theme_stylebox_override("panel", UI.piece("paper", 4.0))
    page.mouse_filter = Control.MOUSE_FILTER_IGNORE
    window.add_child(page)
    _text = hud._label("", FRAME.position + Vector2(14, 34), Vector2(FRAME.size.x - 28, 76), window, 10)
    _text.add_theme_color_override("font_color", UI.PAPER_INK)
    _text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _face = TextureRect.new()
    _face.position = FRAME.position + Vector2(14, 36)
    _face.size = Vector2(38, 38)
    _face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    window.add_child(_face)
    _options = VBoxContainer.new()
    _options.position = FRAME.position + Vector2(14, 114)
    _options.custom_minimum_size = Vector2(FRAME.size.x - 28, 0)
    window.add_child(_options)
    hud._label("Esc: leave", FRAME.position + Vector2(14, FRAME.size.y - 20), Vector2(200, 14), window, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    window.hide()

func window() -> Control:
    return get_node("Window")

func is_open() -> bool:
    return window().visible

## options: [[label, callback (or null for a disabled line)], ...]
func open(speaker: String, words: String, options: Array, face: Texture2D = null) -> void:
    if hud.menu_open():
        return
    _paused_before = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    _title.text = speaker
    _text.text = words
    _face.texture = face
    _face.visible = face != null
    _text.position.x = FRAME.position.x + (60.0 if face != null else 14.0)
    _text.size.x = FRAME.size.x - (74.0 if face != null else 28.0)
    for child in _options.get_children():
        _options.remove_child(child)
        child.queue_free()
    for option in options:
        var button: Button = hud._button(String(option[0]), Vector2.ZERO, Vector2(FRAME.size.x - 28, 20), _options)
        button.custom_minimum_size = Vector2(FRAME.size.x - 28, 20)
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        var callback: Variant = option[1]
        if callback == null:
            button.disabled = true
        else:
            button.pressed.connect(func():
                close()
                callback.call()
            )
    window().show()

func close() -> void:
    if not window().visible:
        return
    window().hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before

func _unhandled_input(event: InputEvent) -> void:
    if window().visible and event.is_action_pressed("ui_cancel"):
        close()
        get_viewport().set_input_as_handled()
