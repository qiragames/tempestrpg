extends Control
## The army window (M11h, C): your soldiers with rank, health and order; recruit one (inside your
## village, for Zeni) and give orders — Follow me, Hold here, Charge — or send them home. Only the
## operation goes to the host (the "army" intent).
const UI := preload("res://scripts/ui/ui_style.gd")
const ARMY := preload("res://scripts/nation/army.gd")
const FRAME := Rect2(90, 24, 460, 312)

var hud: CanvasLayer
var _list: VBoxContainer
var _summary: Label
var _paused_before := false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "ArmyPanel"
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
    UI.heading(hud._label("ARMY", FRAME.position + Vector2(14, 10), Vector2(200, 20), self, 14))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    close.pressed.connect(close_panel)
    _summary = hud._label("", FRAME.position + Vector2(14, 34), Vector2(FRAME.size.x - 28, 28), self, 9)
    _summary.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    var actions := [["Recruit", "recruit"], ["Follow me", "follow"], ["Hold here", "hold"], ["Charge!", "charge"], ["Send home", "dismiss"]]
    for index in range(actions.size()):
        var button: Button = hud._button(actions[index][0], FRAME.position + Vector2(14 + index * 87, 64), Vector2(84, 22), self)
        button.add_theme_font_size_override("font_size", 9)
        var operation: String = actions[index][1]
        button.pressed.connect(func():
            if operation in ARMY.ORDERS:
                hud.session.request_action("army", {"operation": "command", "order": operation})
            else:
                hud.session.request_action("army", {"operation": operation})
            await get_tree().process_frame
            refresh()
        )
    var scroll := ScrollContainer.new()
    scroll.position = FRAME.position + Vector2(14, 94)
    scroll.size = Vector2(FRAME.size.x - 28, FRAME.size.y - 120)
    add_child(scroll)
    _list = VBoxContainer.new()
    _list.custom_minimum_size = Vector2(FRAME.size.x - 44, 0)
    scroll.add_child(_list)
    hud._label("Two soldiers per nation tier · they rise in rank by fighting · a fallen soldier recovers at the camp · C / Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func army() -> Node:
    return hud.get_parent().get("army")

func is_open() -> bool:
    return visible

func open() -> void:
    if hud.menu_open() or army() == null:
        return
    _paused_before = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    show()
    refresh()

func close_panel() -> void:
    if not visible:
        return
    hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before

func refresh() -> void:
    for child in _list.get_children():
        child.queue_free()
    var node := army()
    var mine: Array = node.soldiers_of(hud.player.character_id)
    _summary.text = "Your soldiers: %d · the nation's army: %d / %d · a recruit costs %d Zeni%s" % [mine.size(), node.state().soldiers.size(), node.capacity(), node.price(hud.player), "" if node.capacity() > 0 else "\nFound your nation (B at the camp) to train soldiers."]
    for soldier in mine:
        var rank: Array = ARMY.rank_of(soldier)
        var full: int = ARMY.stats(soldier)[0]
        var line: Label = hud._label("%s · Lv %d · %s · %s · %d defeats" % [rank[0], int(soldier.level), "recovering %ds" % int(ceil(float(soldier.down))) if float(soldier.down) > 0.0 else "HP %d / %d" % [int(soldier.hp), full], {"follow": "following you", "hold": "holding", "charge": "charging"}[soldier.order], int(soldier.kills)], Vector2.ZERO, Vector2(FRAME.size.x - 44, 16), _list, 9)
        line.custom_minimum_size = Vector2(FRAME.size.x - 44, 16)
        line.add_theme_color_override("font_color", UI.GOLD_LIGHT if rank[0] == "Champion" else UI.TEXT)
    if mine.is_empty():
        hud._label("No soldiers yet. Recruit them inside your village.", Vector2.ZERO, Vector2(FRAME.size.x - 44, 16), _list, 9).add_theme_color_override("font_color", UI.TEXT_DIM)

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if event.is_action_pressed("ui_cancel") or (event.is_action_pressed("army") and not event.is_echo()):
        close_panel()
        get_viewport().set_input_as_handled()
