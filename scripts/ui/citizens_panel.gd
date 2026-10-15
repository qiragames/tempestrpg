extends Control
## Citizens and trade window (M5c, from the nation window): every citizen with their home and job
## (a job needs room at its workplace: fields, workshops, markets, watchtowers), the goods made by
## crafters, the treasury (take Zeni at the camp flag) and the caravan (an idle merchant takes up
## to ten goods to a town and comes back with Zeni). Only IDs and numbers go to the host.
const UI := preload("res://scripts/ui/ui_style.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const FRAME := Rect2(40, 10, 560, 338)

var hud: CanvasLayer
var _summary: Label
var _take: Button
var _take_all: Button
var _caravan: Label
var _town: OptionButton
var _goods: SpinBox
var _send: Button
var _list: VBoxContainer
var _rows_for: Array = []
var _paused_before := false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "CitizensPanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.8)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var frame := Panel.new()
    frame.position = FRAME.position
    frame.size = FRAME.size
    frame.add_theme_stylebox_override("panel", UI.ornate())
    add_child(frame)
    UI.heading(hud._label("CITIZENS & TRADE", FRAME.position + Vector2(14, 10), Vector2(300, 20), self, 14))
    var close: Button = hud._button("Back", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    close.pressed.connect(close_panel)
    _summary = hud._label("", FRAME.position + Vector2(14, 34), Vector2(330, 30), self, 9)
    _take = hud._button("Take 100 Zeni", FRAME.position + Vector2(352, 36), Vector2(96, 22), self)
    _take.add_theme_font_size_override("font_size", 9)
    _take.pressed.connect(func(): _send_op("treasury", "100"))
    _take_all = hud._button("Take all", FRAME.position + Vector2(452, 36), Vector2(94, 22), self)
    _take_all.add_theme_font_size_override("font_size", 9)
    _take_all.pressed.connect(func(): _send_op("treasury", "all"))
    UI.heading(hud._label("CARAVAN", FRAME.position + Vector2(14, 68), Vector2(200, 16), self, 11))
    _caravan = hud._label("", FRAME.position + Vector2(14, 86), Vector2(FRAME.size.x - 28, 16), self, 9)
    _town = OptionButton.new()
    _town.position = FRAME.position + Vector2(14, 104)
    _town.size = Vector2(240, 22)
    _town.add_theme_font_size_override("font_size", 9)
    for entry in NATION.caravan_towns():
        _town.add_item(entry[1])
        _town.set_item_metadata(_town.item_count - 1, entry[0])
    add_child(_town)
    _goods = SpinBox.new()
    _goods.position = FRAME.position + Vector2(262, 104)
    _goods.size = Vector2(90, 22)
    _goods.min_value = 1
    _goods.max_value = NATION.CARAVAN_GOODS
    _goods.value = 5
    _goods.suffix = "goods"
    add_child(_goods)
    _send = hud._button("Send caravan", FRAME.position + Vector2(360, 104), Vector2(186, 22), self)
    _send.add_theme_font_size_override("font_size", 9)
    _send.pressed.connect(func(): _send_op("caravan", "%s:%d" % [_town.get_item_metadata(_town.selected), int(_goods.value)]))
    UI.heading(hud._label("CITIZENS", FRAME.position + Vector2(14, 134), Vector2(200, 16), self, 11))
    var scroll := ScrollContainer.new()
    scroll.position = FRAME.position + Vector2(14, 152)
    scroll.size = Vector2(FRAME.size.x - 28, FRAME.size.y - 178)
    add_child(scroll)
    _list = VBoxContainer.new()
    _list.custom_minimum_size = Vector2(FRAME.size.x - 44, 0)
    scroll.add_child(_list)
    hud._label("Workers bring wood/stone · farmers tend 3 fields · crafters (workshop) make goods · merchants (market) sell them · guards (watchtower) defend · Esc: back", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func camp() -> Node2D:
    return hud.get_parent().camp

func open() -> void:
    _paused_before = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    show()
    _rows_for = []
    _refresh()

func close_panel() -> void:
    if not visible:
        return
    hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before

func is_open() -> bool:
    return visible

func _send_op(operation: String, id: String) -> void:
    hud.session.request_action("camp", {"operation": operation, "id": id})
    _rows_for = []
    _refresh()

func _process(_delta: float) -> void:
    if visible:
        _refresh()

func _refresh() -> void:
    var nation: Dictionary = camp().state.nation
    var at_flag: bool = camp().can_reach(hud.player, camp().SITE, 55)
    _summary.text = "Treasury %d Zeni · %d trade goods (%d made, %d sold)\nWork every %d s · %d citizens%s" % [int(nation.treasury), int(nation.goods), int(nation.crafted), int(nation.sold), int(NATION.WORK_SECONDS), nation.citizens.size(), "" if at_flag else " · take Zeni and send caravans at the camp flag"]
    _take.disabled = not at_flag or int(nation.treasury) < 100
    _take_all.disabled = not at_flag or int(nation.treasury) <= 0
    var away: bool = not String(nation.caravan.to).is_empty()
    var town_id: String = String(_town.get_item_metadata(_town.selected)) if _town.item_count > 0 else ""
    var terms: Array = NATION.caravan_terms(town_id, camp().SITE)
    if away:
        _caravan.text = "On the road to %s with %d goods · back in %d s" % [MAP.town(nation.caravan.to)[1], int(nation.caravan.goods), int(ceil(float(nation.caravan.left)))]
    else:
        _caravan.text = "To %s: %d min there and back, %d Zeni per good (needs a merchant)" % [_town.get_item_text(_town.selected), int(ceil(terms[0] / 60.0)), terms[1]]
    _send.disabled = away or not at_flag or NATION.job_count(nation, "merchant") == 0 or int(nation.goods) < int(_goods.value)
    # Citizen rows (rebuilt when the citizens or jobs change).
    var signature: Array = nation.citizens.map(func(citizen): return "%s:%s" % [citizen.id, citizen.job]) + [nation.buildings.size(), nation.caravan.merchant]
    if signature == _rows_for:
        return
    _rows_for = signature
    for child in _list.get_children():
        _list.remove_child(child)
        child.queue_free()
    if nation.citizens.is_empty():
        _list.add_child(_fit(hud._label("No citizens yet: build homes and keep food in the store.", Vector2.ZERO, Vector2.ZERO, _list, 9), 400))
        return
    for citizen in nation.citizens:
        var row := HBoxContainer.new()
        _list.add_child(row)
        var home: String = "the camp hut" if citizen.home == NATION.CAMP_HUT else NATION.BUILDINGS[NATION.building(nation, citizen.home).get("kind", "house")][0].to_lower()
        var lead: String = " (leading the caravan)" if citizen.id == nation.caravan.merchant else ""
        row.add_child(_fit(hud._label("%s · %s%s" % [citizen.name, home, lead], Vector2.ZERO, Vector2.ZERO, row, 9), 250))
        var jobs := OptionButton.new()
        jobs.custom_minimum_size = Vector2(220, 20)
        jobs.add_theme_font_size_override("font_size", 9)
        for job in NATION.JOBS:
            var places: int = NATION.job_places(nation, job)
            jobs.add_item("%s%s" % [NATION.JOBS[job][0], "" if String(NATION.JOBS[job][1]).is_empty() else " (%d/%d)" % [NATION.job_count(nation, job), places]])
            jobs.set_item_metadata(jobs.item_count - 1, job)
            if job != citizen.job and NATION.job_count(nation, job) >= places:
                jobs.set_item_disabled(jobs.item_count - 1, true)
            if job == citizen.job:
                jobs.select(jobs.item_count - 1)
        jobs.disabled = citizen.id == nation.caravan.merchant
        var id: String = citizen.id
        jobs.item_selected.connect(func(index: int): _send_op("job", "%s:%s" % [id, jobs.get_item_metadata(index)]))
        row.add_child(jobs)

func _fit(control: Control, width: float) -> Control:
    if control.get_parent() != null:
        control.get_parent().remove_child(control)
    control.custom_minimum_size = Vector2(width, 20)
    control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    return control

func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        close_panel()
        get_viewport().set_input_as_handled()
