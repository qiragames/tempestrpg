extends Control
## Join codes window (user request): playing together through routers without settings or
## extra software. The host makes one invite code per friend, copies it to the friend (Discord,
## chat…), pastes the friend's reply code and the friend is in. A joining friend sees their reply
## code here until the host has pasted it.
const UI := preload("res://scripts/ui/ui_style.gd")
const CODES := preload("res://scripts/network/join_codes.gd")
const FRAME := Rect2(70, 30, 500, 300)

var hud: CanvasLayer
var _title: Label
var _text: Label
var _code: TextEdit
var _copy: Button
var _make: Button
var _reply: LineEdit
var _connect: Button
var _status: Label
var _paused_before := false
var _making := false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "InvitePanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var window := Control.new()
    window.name = "Window"
    window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(window)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.85)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    window.add_child(backdrop)
    var frame := Panel.new()
    frame.position = FRAME.position
    frame.size = FRAME.size
    frame.add_theme_stylebox_override("panel", UI.ornate())
    window.add_child(frame)
    _title = UI.heading(hud._label("", FRAME.position + Vector2(14, 10), Vector2(360, 20), window, 14))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), window)
    close.pressed.connect(close_panel)
    _text = hud._label("", FRAME.position + Vector2(14, 34), Vector2(FRAME.size.x - 28, 40), window, 9)
    _make = hud._button("New invite code", FRAME.position + Vector2(14, 78), Vector2(150, 24), window)
    _make.pressed.connect(_make_invite)
    _copy = hud._button("Copy code", FRAME.position + Vector2(170, 78), Vector2(110, 24), window)
    _copy.pressed.connect(func():
        DisplayServer.clipboard_set(_code.text)
        _status.text = "Copied. Paste it to your friend (Discord, chat…)."
    )
    _code = TextEdit.new()
    _code.position = FRAME.position + Vector2(14, 106)
    _code.size = Vector2(FRAME.size.x - 28, 80)
    _code.editable = false
    _code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    _code.add_theme_font_size_override("font_size", 16)
    window.add_child(_code)
    _reply = LineEdit.new()
    _reply.position = FRAME.position + Vector2(14, 196)
    _reply.size = Vector2(FRAME.size.x - 150, 24)
    _reply.placeholder_text = "Paste your friend's reply code here"
    _reply.add_theme_font_size_override("font_size", 9)
    window.add_child(_reply)
    _connect = hud._button("Let them in", FRAME.position + Vector2(FRAME.size.x - 130, 196), Vector2(116, 24), window)
    _connect.pressed.connect(_accept)
    _status = hud._label("", FRAME.position + Vector2(14, 228), Vector2(FRAME.size.x - 28, 44), window, 9)
    _status.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    hud._label("Codes contain your Internet address — share them only with friends. Each friend needs their own code.", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), window, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    window.hide()
    hud.session.reply_code_ready.connect(show_reply)
    hud.session.character_assigned.connect(func(_id: String):
        if window.visible and hud.session.replica_world:
            close_panel()
    )

func window() -> Control:
    return get_node("Window")

func is_open() -> bool:
    return window().visible

func _show() -> void:
    if window().visible:
        return
    _paused_before = get_tree().paused
    window().show()

## Host: open the window (switching the world to join codes if it is not open to friends yet).
func open_host() -> void:
    var session: Node = hud.session
    if not session.code_mode and session.open_with_codes() != OK:
        return
    _title.text = "INVITE FRIENDS WITH A CODE"
    _text.text = "Make an invite code and send it to one friend. They paste it into Join a Friend and are in — nothing to paste back. (Only if their game says so, paste their reply code below.)"
    _make.visible = true
    _reply.visible = true
    _connect.visible = true
    _code.text = ""
    _reply.text = ""
    _status.text = "%d of 8 players." % session.owners.size()
    _show()

## Friend: their reply code, to send back to the host.
func show_reply(code: String) -> void:
    _title.text = "SEND THIS REPLY CODE BACK"
    _text.text = "Copy this reply code and send it to your friend. When they paste it, you join their world (this window closes by itself)."
    _make.visible = false
    _reply.visible = false
    _connect.visible = false
    _code.text = code
    _status.text = "Waiting for your friend…" if not code.is_empty() else "Could not make a reply code."
    _show()

func _make_invite() -> void:
    if _making:
        return
    _making = true
    _make.disabled = true
    _status.text = "Making a code (a few seconds)…"
    var code: String = await hud.session.create_invite()
    _making = false
    _make.disabled = false
    _code.text = code
    if code.is_empty():
        _status.text = "No more room (8 players) or join codes are unavailable."
    elif hud.session.RELAY_SCRIPT.is_short(code):
        _status.text = "Send this code to one friend — they join by themselves (the code works for 15 minutes)."
    else:
        _status.text = "The internet relay could not be reached: send this long code, then paste your friend's reply below."

func _accept() -> void:
    if hud.session.accept_reply(_reply.text):
        _status.text = "Connecting… they appear in your world in a moment. Make a new code for the next friend."
        _reply.text = ""
        _code.text = ""
    else:
        _status.text = "That reply code does not fit an open invite. Check it was copied completely."

func close_panel() -> void:
    window().hide()
    get_tree().paused = _paused_before

func _unhandled_input(event: InputEvent) -> void:
    if window().visible and event.is_action_pressed("ui_cancel"):
        close_panel()
        get_viewport().set_input_as_handled()
