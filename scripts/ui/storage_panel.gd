extends Control
## The storage window: opened with F at a Vault in your village or at a major city's town hall
## (its "Storage" sign). Tabs for the storages you can use here (settlement storage, this city's
## storage, or Buy for a city you have none in); left your bag and unworn gear (click to store),
## right what is stored (click to take). Shift-click moves a whole stack. Only operations go to the
## host (the "storage" intent).
const UI := preload("res://scripts/ui/ui_style.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const STORAGE := preload("res://scripts/settlement/storage.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const FRAME := Rect2(40, 14, 560, 332)
const COLUMN := 258.0

var hud: CanvasLayer
var _tabs: HBoxContainer
var _mine: VBoxContainer
var _stored: VBoxContainer
var _summary: Label
var _where := ""
var _places: Array = []
var _signature := ""
var _paused_before := false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "StoragePanel"
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
    UI.heading(hud._label("STORAGE", FRAME.position + Vector2(14, 10), Vector2(200, 20), self, 14))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    close.pressed.connect(close_panel)
    _tabs = HBoxContainer.new()
    _tabs.position = FRAME.position + Vector2(14, 36)
    _tabs.add_theme_constant_override("separation", 4)
    add_child(_tabs)
    _summary = hud._label("", FRAME.position + Vector2(14, 60), Vector2(FRAME.size.x - 28, 14), self, 9)
    _summary.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    var lists: Array = []
    for index in range(2):
        var x: float = FRAME.position.x + 14 + index * (COLUMN + 16)
        hud._label(["Your bag and gear (click to store)", "Stored (click to take)"][index], Vector2(x, FRAME.position.y + 78), Vector2(COLUMN, 14), self, 9).add_theme_color_override("font_color", UI.TEXT_DIM)
        var scroll := ScrollContainer.new()
        scroll.position = Vector2(x, FRAME.position.y + 94)
        scroll.size = Vector2(COLUMN, FRAME.size.y - 122)
        add_child(scroll)
        var list := VBoxContainer.new()
        list.custom_minimum_size = Vector2(COLUMN - 14, 0)
        list.add_theme_constant_override("separation", 2)
        scroll.add_child(list)
        lists.append(list)
    _mine = lists[0]
    _stored = lists[1]
    hud._label("Settlement storage: Vaults in your village, also at any major city's town hall · city storage: only in its city · Shift-click: a whole stack · Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func storage() -> Node:
    return hud.get_parent().get("storage")

func is_open() -> bool:
    return visible

## Open at a Vault or town hall (`places` from Storage.reachable, plus the city to buy in).
func open_at(places: Array, city: String = "") -> void:
    if hud.menu_open():
        return
    _places = places.duplicate()
    if not city.is_empty() and not city in _places:
        _places.append(city)
    _where = _places[0] if not _places.is_empty() else ""
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

func _name(where: String) -> String:
    return "Settlement storage" if where == "home" else "%s storage" % MAP.town(where)[1]

func refresh() -> void:
    for container in [_tabs, _mine, _stored]:
        for child in container.get_children():
            child.queue_free()
    var me: Node = hud.player
    for where in _places:
        var tab: Button = hud._button(_name(where), Vector2.ZERO, Vector2(150, 20), _tabs)
        tab.custom_minimum_size = Vector2(150, 20)
        tab.add_theme_font_size_override("font_size", 9)
        tab.modulate = Color.WHITE if where == _where else Color(0.7, 0.7, 0.7)
        tab.pressed.connect(func():
            _where = where
            _signature = ""
            refresh()
        )
    if _where.is_empty():
        _summary.text = "No storage here."
        return
    var node := storage()
    if _where != "home" and not STORAGE.owns_city(me.progression, _where):
        _summary.text = "Rent storage in %s for %d Zeni (you have %d). It can be used only in this city." % [MAP.town(_where)[1], STORAGE.CITY_PRICE, int(me.progression.get("zeni", 0))]
        var buy: Button = hud._button("Rent storage here", Vector2.ZERO, Vector2(180, 24), _stored)
        buy.pressed.connect(func():
            hud.session.request_action("storage", {"operation": "buy", "where": _where, "item": "", "count": 0})
            await get_tree().process_frame
            _signature = ""
            refresh()
        )
        return
    var stored: Dictionary = STORAGE.box(me.progression, _where)
    var space: Array = node.room(_where)
    _summary.text = "%s · items %d / %d · gear %d / %d%s" % [_name(_where), STORAGE.units(stored), int(space[0]), stored.get("gear", []).size(), int(space[1]), "" if _where != "home" or node.vaults().size() > 0 else " · build a Vault in your village (B, build mode) for room"]
    var worn: Array = me.progression.get("equipment", {}).values()
    for item in me.gear.items:
        if item.id in worn:
            continue
        _line(_mine, GEAR.display_name(item), GEAR.icon_texture(item.base, int(item.rarity))).pressed.connect(_move.bind("put", item.id, 1))
    for entry in me.get_node("Inventory").entries():
        var id := String(entry.id)
        var button := _line(_mine, "%s ×%d" % [entry.name, int(entry.count)], null)
        button.pressed.connect(func(): _move("put", id, int(entry.count) if Input.is_key_pressed(KEY_SHIFT) else 1))
    for item in stored.get("gear", []):
        _line(_stored, GEAR.display_name(item), GEAR.icon_texture(item.base, int(item.rarity))).pressed.connect(_move.bind("take", item.id, 1))
    for good in stored.get("goods", {}):
        var count: int = int(stored.goods[good])
        var button := _line(_stored, "%s ×%d" % [TRADE.good_info(good)[0] if TRADE.is_good(good) else String(good).replace("_", " ").capitalize(), count], null)
        button.pressed.connect(func(): _move("take", good, count if Input.is_key_pressed(KEY_SHIFT) else 1))

func _move(operation: String, item: String, count: int) -> void:
    hud.session.request_action("storage", {"operation": operation, "where": _where, "item": item, "count": count})
    await get_tree().process_frame
    _signature = ""
    refresh()

func _process(_delta: float) -> void:
    if not visible or not is_instance_valid(hud.player):
        return
    # Refresh when what is carried or stored changed (e.g. the host answered).
    var signature := JSON.stringify([hud.player.progression.get("storage", {}), hud.player.gear.items.size(), hud.player.get_node("Inventory").total_units()])
    if signature != _signature:
        _signature = signature
        refresh()

func _line(list: VBoxContainer, text: String, icon: Texture2D) -> Button:
    var button := Button.new()
    button.text = text
    button.icon = icon
    button.expand_icon = true
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.custom_minimum_size = Vector2(COLUMN - 16, 18)
    button.add_theme_font_size_override("font_size", 8)
    button.add_theme_constant_override("icon_max_width", 14)
    button.clip_text = true
    list.add_child(button)
    return button

func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        close_panel()
        get_viewport().set_input_as_handled()
