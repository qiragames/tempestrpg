extends Control
## Party window (M4.6, key P): your party (leader first) with Leave / Remove, the characters
## online with Invite, and a pending invitation to accept or decline. Also draws the party frames
## (HP / Magicule bars of the other members) under the status card. Only names travel to the
## host; it checks every rule (WorldParty).
const UI := preload("res://scripts/ui/ui_style.gd")
const FRAME := Rect2(150, 40, 340, 270)
const PARTY_COLOR := Color("ff8adf")

var hud: CanvasLayer
var _list: VBoxContainer
var _title: Label
var _invite_label: Label
var _accept: Button
var _decline: Button
var _close: Button
var _frames: Control
var _paused_before := false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "PartyPanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _frames = Control.new()
    _frames.name = "PartyFrames"
    _frames.position = Vector2(8, 100)
    _frames.size = Vector2(160, 80)
    _frames.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _frames.draw.connect(_draw_frames)
    add_child(_frames)
    var window := Control.new()
    window.name = "Window"
    window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(window)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.8)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    window.add_child(backdrop)
    var frame := Panel.new()
    frame.position = FRAME.position
    frame.size = FRAME.size
    frame.add_theme_stylebox_override("panel", UI.ornate())
    window.add_child(frame)
    _title = UI.heading(hud._label("PARTY", FRAME.position + Vector2(14, 10), Vector2(220, 20), window, 14))
    _close = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), window)
    _close.pressed.connect(close)
    _invite_label = hud._label("", FRAME.position + Vector2(14, 38), Vector2(FRAME.size.x - 28, 16), window, 10)
    _invite_label.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _accept = hud._button("Accept", FRAME.position + Vector2(14, 56), Vector2(100, 22), window)
    _accept.pressed.connect(func(): _send("accept"))
    _decline = hud._button("Decline", FRAME.position + Vector2(120, 56), Vector2(100, 22), window)
    _decline.pressed.connect(func(): _send("decline"))
    var scroll := ScrollContainer.new()
    scroll.position = FRAME.position + Vector2(14, 84)
    scroll.size = Vector2(FRAME.size.x - 28, FRAME.size.y - 112)
    window.add_child(scroll)
    _list = VBoxContainer.new()
    _list.custom_minimum_size = Vector2(FRAME.size.x - 40, 0)
    scroll.add_child(_list)
    hud._label("Up to 4 · bonus XP and even Zeni together · F revives a fallen member · P / Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), window, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    window.hide()

func window() -> Control:
    return get_node("Window")

func party() -> Node:
    return hud.get_parent().get("party")

func open() -> void:
    if hud.menu_open() or party() == null:
        return
    _paused_before = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    window().show()
    _refresh()
    _close.grab_focus()

func close() -> void:
    if not window().visible:
        return
    window().hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before

func is_open() -> bool:
    return window().visible

## Labels and buttons keep their size inside the list's rows.
func _fit(control: Control, width: float) -> Control:
    control.custom_minimum_size = Vector2(width, 20)
    control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    return control

func _row() -> HBoxContainer:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 22)
    return row

func _send(operation: String, id: String = "") -> void:
    var payload := {"operation": operation}
    if not id.is_empty():
        payload["id"] = id
    hud.session.request_action("party", payload)
    get_tree().create_timer(0.15, true).timeout.connect(func():
        if window().visible:
            _refresh()
    )

func _refresh() -> void:
    for child in _list.get_children():
        child.queue_free()
    var me: String = hud.player.character_id
    var node := party()
    var invite: Dictionary = node.state.invites.get(me, {})
    _invite_label.text = "%s invites you to their party." % invite.from if not invite.is_empty() else ""
    _accept.visible = not invite.is_empty()
    _decline.visible = not invite.is_empty()
    var mine: Array = node.members(me)
    var leading: bool = node.leader(me) == me
    _title.text = "PARTY (%d / %d)" % [mine.size(), node.MAX_SIZE] if mine.size() > 1 else "PARTY"
    if mine.size() > 1:
        for id in mine:
            var row := _row()
            var name_label: Label = hud._label(("★ " if node.leader(me) == id else "") + id + (" (you)" if id == me else ""), Vector2.ZERO, Vector2(170, 20), row, 10)
            name_label.add_theme_color_override("font_color", PARTY_COLOR)
            _fit(name_label, 170)
            if id == me:
                var leave: Button = _fit(hud._button("Leave", Vector2.ZERO, Vector2(110, 20), row), 110)
                leave.pressed.connect(func(): _send("leave"))
            elif leading:
                var kick: Button = _fit(hud._button("Remove", Vector2.ZERO, Vector2(110, 20), row), 110)
                kick.pressed.connect(_send.bind("kick", id))
            _list.add_child(row)
    var others: Array = []
    for actor in get_tree().get_nodes_in_group("player"):
        if actor.character_id != me and not actor.character_id in mine:
            others.append(actor.character_id)
    if not others.is_empty():
        _fit(hud._label("Online:", Vector2.ZERO, Vector2(200, 18), _list, 10), 200)
    for id in others:
        var row := _row()
        _fit(hud._label(id, Vector2.ZERO, Vector2(170, 20), row, 10), 170)
        var invite_button: Button = _fit(hud._button("Invite", Vector2.ZERO, Vector2(110, 20), row), 110)
        invite_button.disabled = mine.size() >= node.MAX_SIZE or (mine.size() > 1 and not leading)
        invite_button.pressed.connect(_send.bind("invite", id))
        _list.add_child(row)
    if others.is_empty() and mine.size() <= 1:
        _fit(hud._label("Nobody else is online. Open your world to friends (Esc).", Vector2.ZERO, Vector2(300, 18), _list, 10), 290)

func _process(_delta: float) -> void:
    _frames.queue_redraw()

## Small HP / Magicule bars of the other party members present in the world.
func _draw_frames() -> void:
    var node := party()
    if node == null or not is_instance_valid(hud.player):
        return
    var y := 0.0
    var font: Font = _frames.get_theme_default_font()
    for id in node.members(hud.player.character_id):
        if id == hud.player.character_id:
            continue
        var actor: Node = hud.get_parent().player_by_id(id)
        _frames.draw_rect(Rect2(0, y, 130, 22), Color(0.02, 0.03, 0.06, 0.75))
        _frames.draw_string(font, Vector2(4, y + 8), id, HORIZONTAL_ALIGNMENT_LEFT, 120, 8, PARTY_COLOR)
        if actor != null:
            var health: Node = actor.get_node("Health")
            var pool: Node = actor.get_node("Magicules")
            _frames.draw_rect(Rect2(4, y + 11, 122, 4), Color("3a1414"))
            _frames.draw_rect(Rect2(4, y + 11, 122.0 * health.current / maxf(1.0, health.maximum), 4), Color("d94a4a") if health.current > 0 else Color("6a6a6a"))
            _frames.draw_rect(Rect2(4, y + 16, 122, 3), Color("14223a"))
            _frames.draw_rect(Rect2(4, y + 16, 122.0 * pool.current / maxf(1.0, pool.maximum), 3), Color("4a8ad9"))
        y += 25

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("party") and not event.is_echo():
        if window().visible:
            close()
        else:
            open()
        get_viewport().set_input_as_handled()
    elif window().visible and event.is_action_pressed("ui_cancel"):
        close()
        get_viewport().set_input_as_handled()
