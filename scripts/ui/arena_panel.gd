extends Control
## The arena window (M15): F at the Arena in your settlement. Challenge a character standing at the
## arena to a best-of-three match, and see the arena board — every character of this world with
## their arena and duel records, best first. Only ids go to the host (the "duel" intent).
const UI := preload("res://scripts/ui/ui_style.gd")
const DUELS := preload("res://scripts/pvp/world_duels.gd")
const FRAME := Rect2(110, 30, 420, 290)

var hud: CanvasLayer
var _list: VBoxContainer
var _paused_before := false
var _signature := ""

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "ArenaPanel"
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
    UI.heading(hud._label("ARENA", FRAME.position + Vector2(14, 10), Vector2(200, 20), self, 14))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    close.pressed.connect(close_panel)
    var scroll := ScrollContainer.new()
    scroll.position = FRAME.position + Vector2(14, 38)
    scroll.size = Vector2(FRAME.size.x - 28, FRAME.size.y - 64)
    add_child(scroll)
    _list = VBoxContainer.new()
    _list.custom_minimum_size = Vector2(FRAME.size.x - 44, 0)
    _list.add_theme_constant_override("separation", 2)
    scroll.add_child(_list)
    hud._label("Best of three rounds · nobody dies and nothing is lost · leaving the ring gives up · Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func duels() -> Node:
    return hud.get_parent().get("duels")

func is_open() -> bool:
    return visible

func open() -> void:
    if hud.menu_open() or duels() == null:
        return
    _paused_before = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    show()
    _signature = ""
    refresh()

func close_panel() -> void:
    if not visible:
        return
    hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before

func _text(text: String, colour: Color) -> void:
    var label: Label = hud._label(text, Vector2.ZERO, Vector2(FRAME.size.x - 44, 16), _list, 9)
    label.custom_minimum_size = Vector2(FRAME.size.x - 44, 16)
    label.add_theme_color_override("font_color", colour)

## Every character of this world with a record: [id, arena [won, lost], duels [won, lost]].
func board() -> Array:
    var rows := {}
    for id in hud.session.records:
        var progression: Variant = hud.session.records[id].get("progression")
        if progression is Dictionary:
            rows[id] = [id, DUELS.record(progression, "arena"), DUELS.record(progression, "duels")]
    for actor in get_tree().get_nodes_in_group("player"):
        if actor.get_parent() == hud.get_parent():
            rows[actor.character_id] = [actor.character_id, DUELS.record(actor.progression, "arena"), DUELS.record(actor.progression, "duels")]
    var sorted: Array = rows.values()
    sorted.sort_custom(func(a, b): return int(a[1][0]) > int(b[1][0]) or (int(a[1][0]) == int(b[1][0]) and int(a[2][0]) > int(b[2][0])))
    return sorted

func refresh() -> void:
    for child in _list.get_children():
        child.queue_free()
    var me: Node2D = hud.player
    var node := duels()
    _text("Challenge someone at the arena", UI.GOLD_LIGHT)
    var anyone := false
    for actor in get_tree().get_nodes_in_group("player"):
        if actor == me or actor.get_parent() != hud.get_parent() or node.arena_at(actor) == Vector2.INF:
            continue
        anyone = true
        var row := HBoxContainer.new()
        row.custom_minimum_size = Vector2(0, 22)
        _list.add_child(row)
        var label: Label = hud._label(actor.character_id, Vector2.ZERO, Vector2(200, 20), row, 9)
        label.custom_minimum_size = Vector2(200, 20)
        var fight: Button = hud._button("Challenge", Vector2.ZERO, Vector2(90, 20), row)
        fight.custom_minimum_size = Vector2(90, 20)
        fight.add_theme_font_size_override("font_size", 8)
        fight.disabled = node.in_match(me.character_id) or node.in_match(actor.character_id)
        var rival: String = actor.character_id
        fight.pressed.connect(func():
            hud.session.request_action("duel", {"operation": "challenge", "id": rival})
            close_panel())
    if not anyone:
        _text("Nobody else stands at the arena right now.", UI.TEXT_DIM)
    _text("", UI.TEXT)
    _text("Arena board (arena won/lost · duels won/lost)", UI.GOLD_LIGHT)
    var place := 1
    for row in board():
        _text("%d. %s   arena %d/%d · duels %d/%d" % [place, row[0], row[1][0], row[1][1], row[2][0], row[2][1]], UI.TEXT if row[0] != me.character_id else Color("8fe3a0"))
        place += 1

func _process(_delta: float) -> void:
    if not visible or duels() == null:
        return
    var signature := JSON.stringify([duels().state.matches.keys(), get_tree().get_nodes_in_group("player").size(), hud.player.global_position.round()])
    if signature != _signature:
        _signature = signature
        refresh()

func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        close_panel()
        get_viewport().set_input_as_handled()
