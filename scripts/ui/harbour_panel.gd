extends Control
## Harbour window (M4.5d, user decisions): travel by map. Pick a harbour on the map, then sail
## with a ticket for it, a ferry pass or your own ship (with the crew you invited); a short voyage
## plays across the map. Here you also buy tickets, the pass, a ship (at shipwrights), summon your
## ship and invite characters standing near you. The window only names harbours and characters;
## the host checks everything (WorldHarbours).
const TRAVEL := preload("res://scripts/travel/travel_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const FRAME := Rect2(20, 12, 600, 336)
const MAP_AT := Vector2(34, 46)
const SCALE := 0.31
const VOYAGE_SECONDS := 2.4

var hud: CanvasLayer
var here := ""
var destination := ""
var _title: Label
var _status: Label
var _choice: Label
var _canvas: Control
var _buttons: Dictionary = {}
var _ports: Dictionary = {}
var _guest_index := 0
var _voyage := {}
var _paused_before := false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "HarbourPanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.8)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var frame := Panel.new()
    frame.position = FRAME.position
    frame.size = FRAME.size
    frame.add_theme_stylebox_override("panel", UI.ornate())
    add_child(frame)
    _title = UI.heading(hud._label("", FRAME.position + Vector2(14, 10), Vector2(400, 20), self, 14))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    close.pressed.connect(close_panel)
    _buttons["close"] = close
    _canvas = Control.new()
    _canvas.position = FRAME.position + MAP_AT
    _canvas.size = Vector2(MAP.COLS, MAP.ROWS) * SCALE
    _canvas.mouse_filter = Control.MOUSE_FILTER_PASS
    _canvas.draw.connect(_draw_map)
    add_child(_canvas)
    for entry in MAP.HARBOURS:
        var port := Button.new()
        port.flat = true
        port.size = Vector2(12, 12)
        port.position = _canvas.position + _to_map(entry[2]) - Vector2(6, 6)
        port.tooltip_text = entry[1]
        port.pressed.connect(_pick.bind(entry[0]))
        add_child(port)
        _ports[entry[0]] = port
    var x := FRAME.position.x + MAP_AT.x + _canvas.size.x + 14
    var width := FRAME.end.x - x - 12
    _status = hud._label("", Vector2(x, FRAME.position.y + 44), Vector2(width, 74), self, 9)
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _choice = hud._label("", Vector2(x, FRAME.position.y + 120), Vector2(width, 40), self, 10)
    _choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _choice.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    var y := FRAME.position.y + 162
    for key in ["sail", "ticket", "pass", "ship", "summon", "invite", "accept"]:
        var button: Button = hud._button("", Vector2(x, y), Vector2(width, 22), self)
        button.add_theme_font_size_override("font_size", 9)
        button.pressed.connect(_act.bind(key))
        _buttons[key] = button
        y += 24
    hud._label("Click a harbour on the map · F / Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(500, 14), self, 9).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func _to_map(tile: Vector2) -> Vector2:
    return (tile - Vector2(MAP.MIN)) * SCALE

func harbours() -> Node:
    return hud.get_parent().harbours

func open(harbour: String) -> void:
    if hud.menu_open():
        return
    here = harbour
    destination = ""
    _voyage = {}
    _paused_before = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    show()
    _refresh()
    _buttons.close.grab_focus()

func close_panel() -> void:
    if not visible:
        return
    hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before

func _pick(id: String) -> void:
    if _voyage.is_empty() and id != here:
        destination = id
        _refresh()

## Characters standing next to you (to invite aboard).
func _nearby() -> Array:
    var found: Array = []
    for actor in get_tree().get_nodes_in_group("player"):
        if actor != hud.player and actor.global_position.distance_to(hud.player.global_position) <= TRAVEL.CREW_RADIUS:
            found.append(actor.character_id)
    return found

func _refresh() -> void:
    var me = hud.player
    var node := harbours()
    var entry: Array = MAP.harbour(here)
    _title.text = entry[1].to_upper()
    var ship: Dictionary = node.ship_of(me)
    var lines: Array = []
    if ship.get("owned", false):
        lines.append("Your ship lies at %s." % MAP.harbour(ship.at)[1] if ship.at != here else "Your ship lies here, ready to sail.")
        var crew: Array = node.crew_of(me.character_id)
        lines.append("Crew: %s" % (", ".join(crew) if not crew.is_empty() else "none yet (invite characters next to you)"))
    elif node.has_pass(me):
        lines.append("Ferry pass: %d min left." % int(ceil((float(me.progression.ferry_pass_until) - node.world_time()) / 60.0)))
    var tickets: Array = []
    for harbour in MAP.HARBOURS:
        var count: int = me.get_node("Inventory").count_of(TRAVEL.ticket_id(harbour[0]))
        if count > 0:
            tickets.append("%s ×%d" % [harbour[1], count])
    lines.append("Tickets: %s" % (", ".join(tickets) if not tickets.is_empty() else "none"))
    lines.append("Purse: %d Zeni" % me.zeni())
    _status.text = "\n".join(lines)
    var invited: Dictionary = node.state.invites.get(me.character_id, {})
    var own_here: bool = ship.get("owned", false) and ship.at == here
    var can_sail := false
    if destination.is_empty():
        _choice.text = "Choose a harbour on the map."
    else:
        var fare := TRAVEL.fare(here, destination)
        var how := "on your ship" if own_here else ("with your pass" if node.has_pass(me) else ("with your ticket" if me.get_node("Inventory").count_of(TRAVEL.ticket_id(destination)) > 0 else "— buy a ticket first"))
        can_sail = own_here or node.has_pass(me) or me.get_node("Inventory").count_of(TRAVEL.ticket_id(destination)) > 0
        _choice.text = "To %s %s (ticket %d Zeni)" % [MAP.harbour(destination)[1], how, fare]
    var busy := not _voyage.is_empty()
    _button_state("sail", "Sail", not busy and can_sail and not destination.is_empty(), true)
    _button_state("ticket", "Buy ticket · %d Zeni" % (TRAVEL.fare(here, destination) if not destination.is_empty() else 0), not busy and not destination.is_empty() and not own_here and me.zeni() >= (TRAVEL.fare(here, destination) if not destination.is_empty() else 0), not own_here)
    _button_state("pass", "Ferry pass (1 h) · %d Zeni" % TRAVEL.PASS_PRICE, not busy and me.zeni() >= TRAVEL.PASS_PRICE, not ship.get("owned", false))
    _button_state("ship", "Buy a ship · %d Zeni" % TRAVEL.SHIP_PRICE, not busy and me.zeni() >= TRAVEL.SHIP_PRICE, entry[4] and not ship.get("owned", false))
    _button_state("summon", "Summon your ship here", not busy, ship.get("owned", false) and ship.at != here)
    var guests := _nearby()
    var guest: String = guests[_guest_index % guests.size()] if not guests.is_empty() else ""
    _button_state("invite", "Invite %s aboard" % guest if not guest.is_empty() else "Invite (no one nearby)", not busy and not guest.is_empty(), own_here)
    _button_state("accept", "Accept %s's invitation" % invited.get("owner", ""), not busy, not invited.is_empty())
    for id in _ports:
        _ports[id].disabled = busy or id == here
    _canvas.queue_redraw()

func _button_state(key: String, text: String, enabled: bool, shown: bool) -> void:
    _buttons[key].text = text
    _buttons[key].disabled = not enabled
    _buttons[key].visible = shown

func _act(key: String) -> void:
    match key:
        "sail":
            hud.session.request_action("harbour", {"operation": "sail", "harbour": here, "to": destination})
            _voyage = {"from": _to_map(MAP.harbour(here)[2]), "to": _to_map(MAP.harbour(destination)[2]), "time": 0.0}
        "ticket":
            hud.session.request_action("harbour", {"operation": "ticket", "harbour": here, "to": destination})
        "pass", "ship", "summon":
            hud.session.request_action("harbour", {"operation": key, "harbour": here})
        "invite":
            var guests := _nearby()
            if not guests.is_empty():
                hud.session.request_action("harbour", {"operation": "invite", "harbour": here, "guest": guests[_guest_index % guests.size()]})
                _guest_index += 1
        "accept":
            hud.session.request_action("harbour", {"operation": "accept"})
    get_tree().create_timer(0.15, true).timeout.connect(func():
        if visible:
            _refresh()
    )

func _process(delta: float) -> void:
    if not visible:
        return
    if not _voyage.is_empty():
        _voyage.time += delta
        _canvas.queue_redraw()
        if _voyage.time >= VOYAGE_SECONDS:
            _voyage = {}
            close_panel()

func _draw_map() -> void:
    _canvas.draw_texture_rect(preload("res://scripts/ui/world_map_panel.gd").world_texture(), Rect2(Vector2.ZERO, _canvas.size), false)
    _canvas.draw_rect(Rect2(Vector2(-1, -1), _canvas.size + Vector2(2, 2)), UI.GOLD_DARK, false, 1.0)
    var font: Font = _canvas.get_theme_default_font()
    for entry in MAP.HARBOURS:
        var at := _to_map(entry[2])
        var color: Color = UI.CYAN if entry[0] == here else (UI.GOLD_LIGHT if entry[0] == destination else Color("9fe8ff"))
        _canvas.draw_circle(at, 4.5, Color(0.03, 0.04, 0.06))
        _canvas.draw_circle(at, 3.0, color)
        _canvas.draw_string_outline(font, at + Vector2(5, 3), entry[1].trim_suffix(" Harbour"), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 3, Color(0.03, 0.04, 0.06))
        _canvas.draw_string(font, at + Vector2(5, 3), entry[1].trim_suffix(" Harbour"), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)
    if not destination.is_empty():
        _canvas.draw_dashed_line(_to_map(MAP.harbour(here)[2]), _to_map(MAP.harbour(destination)[2]), UI.GOLD_LIGHT, 1.0, 4.0)
    if not _voyage.is_empty():
        var t: float = clampf(_voyage.time / VOYAGE_SECONDS, 0.0, 1.0)
        var at: Vector2 = _voyage.from.lerp(_voyage.to, t * t * (3.0 - 2.0 * t))
        # A little boat with a sail crossing the map.
        _canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-6, 0), at + Vector2(6, 0), at + Vector2(4, 3), at + Vector2(-4, 3)]), Color("8b5a2b"))
        _canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -9), at + Vector2(0, -1), at + Vector2(5, -1)]), Color("f4efe2"))

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")) and not event.is_echo() and _voyage.is_empty():
        close_panel()
        get_viewport().set_input_as_handled()
