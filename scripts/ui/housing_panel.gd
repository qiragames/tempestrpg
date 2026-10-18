extends Control
## The furnishing window (M16): F inside your own house or inn room. Left the furniture you can
## buy (price and what it does) — "Place" puts it where you stand; right what is placed — "Take
## away" returns its price. Inn rooms take decorations only (four). Only kinds and indices go to the
## host (the "housing" intent).
const UI := preload("res://scripts/ui/ui_style.gd")
const HOUSING := preload("res://scripts/housing/world_housing.gd")
const FRAME := Rect2(40, 20, 560, 320)
const COLUMN := 258.0

var hud: CanvasLayer
var _title: Label
var _summary: Label
var _shop: VBoxContainer
var _placed: VBoxContainer
var _paused_before := false
var _signature := ""

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "HousingPanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.6)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var frame := Panel.new()
    frame.position = FRAME.position
    frame.size = FRAME.size
    frame.add_theme_stylebox_override("panel", UI.ornate())
    add_child(frame)
    _title = UI.heading(hud._label("FURNISH", FRAME.position + Vector2(14, 10), Vector2(360, 20), self, 14))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    close.pressed.connect(close_panel)
    _summary = hud._label("", FRAME.position + Vector2(14, 34), Vector2(FRAME.size.x - 28, 14), self, 9)
    _summary.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    var lists: Array = []
    for index in range(2):
        var x: float = FRAME.position.x + 14 + index * (COLUMN + 16)
        hud._label(["Furniture (placed where you stand)", "In this room (take away: price back)"][index], Vector2(x, FRAME.position.y + 52), Vector2(COLUMN, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
        var scroll := ScrollContainer.new()
        scroll.position = Vector2(x, FRAME.position.y + 68)
        scroll.size = Vector2(COLUMN, FRAME.size.y - 96)
        add_child(scroll)
        var list := VBoxContainer.new()
        list.custom_minimum_size = Vector2(COLUMN - 14, 0)
        list.add_theme_constant_override("separation", 2)
        scroll.add_child(list)
        lists.append(list)
    _shop = lists[0]
    _placed = lists[1]
    hud._label("Stand where a piece should go, then Place · the door stays free · Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func housing() -> Node:
    return hud.get_parent().get("housing")

func is_open() -> bool:
    return visible

func open() -> void:
    if hud.menu_open() or housing() == null:
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

func _send(operation: String, id: String) -> void:
    if hud.session.active:
        hud.session.request_action("housing", {"operation": operation, "id": id})

func refresh() -> void:
    for list in [_shop, _placed]:
        for child in list.get_children():
            child.queue_free()
    var node := housing()
    var me: Node2D = hud.player
    var inside: Dictionary = node.interior_at(me.global_position)
    if inside.is_empty() or inside.owner != me.character_id:
        _summary.text = "Only in your own house or inn room."
        return
    var inn: bool = inside.kind == "room"
    var list: Array = node.pieces(me.character_id, inside.kind)
    _title.text = "FURNISH YOUR %s" % ("INN ROOM" if inn else "HOUSE")
    _summary.text = "%d / %d pieces · you have %d Zeni%s" % [list.size(), HOUSING.ROOM_PIECES if inn else HOUSING.HOUSE_PIECES, int(me.progression.get("zeni", 0)), " · inn rooms take decorations only (the bed is there already)" if inn else ""]
    for kind in HOUSING.FURNITURE:
        var spec: Array = HOUSING.FURNITURE[kind]
        if inn and not bool(spec[3]):
            continue
        var button := _line(_shop, "%s · %d Zeni%s" % [spec[0], int(spec[1]), " — " + spec[2] if not String(spec[2]).is_empty() else ""], load(HOUSING.ART % kind))
        button.disabled = int(me.progression.get("zeni", 0)) < int(spec[1])
        button.pressed.connect(_act.bind("place", kind))
    for index in range(list.size()):
        _line(_placed, "%s (take away)" % HOUSING.FURNITURE[list[index].kind][0], load(HOUSING.ART % list[index].kind)).pressed.connect(_act.bind("remove", str(index)))

func _act(operation: String, id: String) -> void:
    _send(operation, id)
    await get_tree().process_frame
    _signature = ""
    refresh()

func _line(list: VBoxContainer, text: String, icon: Texture2D) -> Button:
    var button := Button.new()
    button.text = text
    button.icon = icon
    button.expand_icon = true
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.custom_minimum_size = Vector2(COLUMN - 16, 20)
    button.add_theme_font_size_override("font_size", 8)
    button.add_theme_constant_override("icon_max_width", 16)
    button.clip_text = true
    list.add_child(button)
    return button

func _process(_delta: float) -> void:
    if not visible or housing() == null:
        return
    var signature := JSON.stringify([housing().state, hud.player.progression.get("zeni", 0)])
    if signature != _signature:
        _signature = signature
        refresh()

func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        close_panel()
        get_viewport().set_input_as_handled()
