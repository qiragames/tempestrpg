extends Control
## Shop window (M4.5c; user request after v1.5: "like the equipment menu, cleaner"). F next to a
## merchant opens it: the merchant's face and name, your purse, Buy and Sell tabs, the wares as a
## grid of icon squares (price under each, count on stacks) and on the right the selected thing —
## the item card for gear, a description for goods — with Buy / Sell / Sell all. Double-click
## buys or sells at once. The window only names merchant and entry; the host checks distance,
## stock, Zeni and room (WorldTrade). Harbours have their own window (harbour_panel.gd).
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const TRAVEL := preload("res://scripts/travel/travel_catalogue.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const ORIGIN := Vector2(20, 8)
const FRAME := Rect2(20, 8, 600, 344)
const CELL := 32.0
const COLUMNS := 9

var hud: CanvasLayer
var merchant_id := ""
var selling := false
var _title: Label
var _purse: Label
var _face: TextureRect
var _grid: GridContainer
var _scroll: ScrollContainer
var _cells: Array = []
var _icon: TextureRect
var _name: Label
var _kind: Label
var _details: Label
var _price: Label
var _card: Control
var _action: Button
var _buy_tab: Button
var _sell_tab: Button
var _sell_all: Button
var _close: Button
var _rows: Array = []
var _selected := 0
var _paused_before := false

## A ware: its icon on a slot square framed in the rarity colour, the price under it, the count on
## stacks; the selected one glows.
class WareCell extends Panel:
    var owner_panel: Control
    var index := 0
    var texture: Texture2D
    var rarity := -1
    var price := 0
    var count := 0
    var short := ""
    var chosen := false

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP
        texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        custom_minimum_size = Vector2(CELL, CELL + 9)

    func setup(row: Dictionary, icon: Texture2D, item_rarity: int, picked: bool) -> void:
        texture = icon
        rarity = item_rarity
        price = int(row.price)
        count = int(row.get("count", 1)) if row.kind != "gear" else 1
        short = String(row.get("label", "")).left(3)
        chosen = picked
        queue_redraw()

    func _draw() -> void:
        var square := Rect2(Vector2.ZERO, Vector2(CELL, CELL))
        var style: StyleBox = UI.round_slot("slot_hover" if chosen else "slot")
        if rarity >= 0 and style.get("accent") != null:
            style.accent = Color(GEAR.RARITY_COLORS[rarity])
        draw_style_box(style, square)
        if texture != null:
            draw_texture_rect(texture, square.grow(-4.0), false)
        else:
            var fallback := get_theme_default_font()
            draw_string(fallback, Vector2(0, CELL / 2.0 + 4), short, HORIZONTAL_ALIGNMENT_CENTER, CELL, 8, UI.TEXT)
        var font := get_theme_default_font()
        if count > 1:
            draw_string_outline(font, Vector2(2, 10), "%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.03, 0.04, 0.06))
            draw_string(font, Vector2(2, 10), "%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
        draw_string(font, Vector2(0, CELL + 8), "%d" % price, HORIZONTAL_ALIGNMENT_CENTER, CELL, 8, UI.GOLD_LIGHT)
        if chosen:
            draw_rect(square.grow(1.0), UI.GOLD_LIGHT, false, 1.0)

    func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            owner_panel.select(index)
            if event.double_click:
                owner_panel._act()
            accept_event()

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "TradePanel"
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
    var o := ORIGIN
    var well := Panel.new()
    well.position = o + Vector2(12, 8)
    well.size = Vector2(36, 36)
    well.add_theme_stylebox_override("panel", UI.box("slot"))
    well.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(well)
    _face = TextureRect.new()
    _face.position = o + Vector2(14, 10)
    _face.size = Vector2(32, 32)
    _face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    add_child(_face)
    _title = UI.heading(hud._label("", o + Vector2(56, 10), Vector2(320, 20), self, 14))
    _purse = hud._label("", o + Vector2(56, 30), Vector2(220, 14), self, 10)
    _purse.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _close = hud._button("Close", o + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    _close.pressed.connect(close)
    _buy_tab = hud._button("Buy", o + Vector2(12, 50), Vector2(80, 22), self)
    _buy_tab.pressed.connect(func(): _switch(false))
    _sell_tab = hud._button("Sell", o + Vector2(96, 50), Vector2(80, 22), self)
    _sell_tab.pressed.connect(func(): _switch(true))
    # The wares: a scrolling grid of squares.
    var wares_box := Panel.new()
    wares_box.position = o + Vector2(12, 76)
    wares_box.size = Vector2(COLUMNS * (CELL + 4) + 16, 238)
    wares_box.add_theme_stylebox_override("panel", UI.hud_box())
    wares_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(wares_box)
    _scroll = ScrollContainer.new()
    _scroll.position = wares_box.position + Vector2(6, 6)
    _scroll.size = wares_box.size - Vector2(10, 12)
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(_scroll)
    _grid = GridContainer.new()
    _grid.columns = COLUMNS
    _grid.add_theme_constant_override("h_separation", 4)
    _grid.add_theme_constant_override("v_separation", 3)
    _scroll.add_child(_grid)
    # The selected ware.
    var detail_x: float = wares_box.position.x + wares_box.size.x + 10
    var detail := Panel.new()
    detail.position = Vector2(detail_x, o.y + 76)
    detail.size = Vector2(FRAME.end.x - detail_x - 12, 238)
    detail.add_theme_stylebox_override("panel", UI.hud_box())
    detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(detail)
    _icon = TextureRect.new()
    _icon.position = detail.position + Vector2(8, 8)
    _icon.size = Vector2(32, 32)
    _icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    add_child(_icon)
    _name = hud._label("", detail.position + Vector2(46, 8), Vector2(detail.size.x - 52, 16), self, 10)
    _kind = hud._label("", detail.position + Vector2(46, 24), Vector2(detail.size.x - 52, 14), self, 8)
    _kind.add_theme_color_override("font_color", UI.TEXT_DIM)
    _details = hud._label("", detail.position + Vector2(8, 46), Vector2(detail.size.x - 16, 110), self, 9)
    _details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _card = load("res://scripts/ui/item_card.gd").new()
    _card.position = detail.position + Vector2(6, 44)
    _card.scale = Vector2(0.85, 0.85)
    add_child(_card)
    _price = hud._label("", detail.position + Vector2(8, detail.size.y - 76), Vector2(detail.size.x - 16, 14), self, 10)
    _price.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    # M6b: sell a whole stack (fish, logs, ores) at once.
    _sell_all = hud._button("", detail.position + Vector2(8, detail.size.y - 60), Vector2(detail.size.x - 16, 24), self)
    _sell_all.pressed.connect(func(): _act(true))
    _sell_all.hide()
    _action = hud._button("", detail.position + Vector2(8, detail.size.y - 32), Vector2(detail.size.x - 16, 26), self)
    _action.pressed.connect(_act)
    hud._label("Click: choose · double-click: buy or sell · F / Esc: close · selling pays %d%% of the price" % int(TRADE.SELL_SHARE * 100), o + Vector2(12, FRAME.size.y - 24), Vector2(560, 14), self, 9).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func world() -> Node:
    return hud.get_parent()

func open(id: String) -> void:
    merchant_id = id
    selling = false
    _selected = 0
    _show()

func _show() -> void:
    if hud.menu_open():
        return
    _paused_before = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    show()
    _refresh()
    _close.grab_focus()

func close() -> void:
    if not visible:
        return
    hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before

func _switch(sell: bool) -> void:
    selling = sell
    _selected = 0
    _refresh()

func _process(_delta: float) -> void:
    if visible:
        _purse.text = "Your purse: %d Zeni" % hud.player.zeni()

## The icon for a ware (gear: its icon in its tier's look; goods: their icon; tools and mounts).
func _ware_icon(row: Dictionary) -> Texture2D:
    match row.kind:
        "gear":
            return UI.gear_icon(row.item)
        "tool":
            var tool: Array = TRAVEL.parse_tool(row.id)
            var path := "res://assets/game/ui/tools/%s.png" % tool[0] if tool[0] in ["axe", "pickaxe"] else "res://assets/game/ui/icons/goods/fish.png"
            return load(path) if ResourceLoader.exists(path) else null
    return UI.icon(String(row.id))

## Rebuild the grid from the merchant's current stock (or the player's sellables).
func _refresh() -> void:
    _purse.text = "Your purse: %d Zeni" % hud.player.zeni()
    _rows.clear()
    var entry: Array = TRADE.merchant(merchant_id)
    _title.text = entry[1].to_upper()
    _face.texture = load("res://assets/game/sprites/%s/%s_face.png" % [entry[2], entry[2]])
    _buy_tab.disabled = not selling
    _sell_tab.disabled = selling
    if not selling:
        for item in world().trade.state.merchants.get(merchant_id, {}).get("stock", []):
            if int(item.count) <= 0:
                continue
            var row: Dictionary = item.duplicate()
            row["label"] = world().trade.describe(item)
            _rows.append(row)
    else:
        var kind: String = entry[3]
        if kind != "smith":
            for bag_entry in hud.player.get_node("Inventory").entries():
                var price := TRADE.price(String(bag_entry.id))
                if price > 0:
                    _rows.append({"kind": "bag", "id": String(bag_entry.id), "price": TRADE.sell_price(price), "name": bag_entry.name, "label": bag_entry.name, "count": bag_entry.count})
        if kind != "trader":
            var worn: Array = hud.player.progression.get("equipment", {}).values()
            for item in hud.player.gear.items:
                if item.id in worn:
                    continue
                _rows.append({"kind": "gear", "id": item.id, "price": TRADE.sell_price(TRADE.gear_price(item, entry[5])), "item": item, "label": GEAR.display_name(item)})
    _selected = clampi(_selected, 0, maxi(0, _rows.size() - 1))
    _rebuild_grid()
    _refresh_details()

func _rebuild_grid() -> void:
    while _cells.size() < _rows.size():
        var cell := WareCell.new()
        cell.owner_panel = self
        cell.index = _cells.size()
        _grid.add_child(cell)
        _cells.append(cell)
    for index in range(_cells.size()):
        var cell: WareCell = _cells[index]
        cell.visible = index < _rows.size()
        if cell.visible:
            var row: Dictionary = _rows[index]
            cell.setup(row, _ware_icon(row), int(row.item.rarity) if row.kind == "gear" else -1, index == _selected)

func select(index: int) -> void:
    _selected = index
    _rebuild_grid()
    _refresh_details()

func _refresh_details() -> void:
    _card.visible = false
    _details.visible = true
    if _rows.is_empty():
        _icon.texture = null
        _name.text = ""
        _kind.text = ""
        _price.text = ""
        _details.text = "Nothing to sell here." if selling else "Sold out until the next restock."
        _action.text = "—"
        _action.disabled = true
        _sell_all.visible = false
        return
    var row: Dictionary = _rows[_selected]
    _icon.texture = _ware_icon(row)
    _name.text = String(row.label)
    match row.kind:
        "gear":
            _kind.text = "%s gear" % GEAR.RARITIES[int(row.item.rarity)]
            _details.visible = false
            _card.visible = true
            _card.show_item(row.item, "")
        "good":
            var info: Array = TRADE.good_info(row.id)
            _kind.text = String(info[1])
            _details.text = String(info[2])
        "material":
            _kind.text = "Material"
            _details.text = "Wanted by crafters and merchants."
        "tool":
            _kind.text = "Tool"
            _details.text = "Owned, never equipped: it works by itself from now on (faster, more yield). Better tiers are crafted."
        "mount":
            _kind.text = "Mount"
            _details.text = "Ride it with H: much faster on the road."
        "bag":
            _kind.text = "From your bag · ×%d" % int(row.count)
            _details.text = TRADE.good_info(row.id)[2] if TRADE.is_good(row.id) else "Crafters and merchants pay for it."
    var count := int(row.get("count", 1))
    _price.text = ("%d Zeni each" % int(row.price)) if count > 1 or row.kind == "bag" else "%d Zeni" % int(row.price)
    _sell_all.visible = selling and row.kind == "bag" and count > 1
    if _sell_all.visible:
        _sell_all.text = "Sell all ×%d · %d Zeni" % [count, int(row.price) * count]
    if selling:
        _action.text = "Sell · %d Zeni" % int(row.price)
        _action.disabled = false
    else:
        _action.text = "Buy · %d Zeni" % int(row.price)
        _action.disabled = hud.player.zeni() < int(row.price)

func _act(all: bool = false) -> void:
    if _rows.is_empty():
        return
    var row: Dictionary = _rows[_selected]
    if selling:
        hud.session.request_action("trade", {"operation": "sell", "merchant": merchant_id, "kind": "gear" if row.kind == "gear" else ("bag_all" if all else "bag"), "id": row.id})
    else:
        hud.session.request_action("trade", {"operation": "buy", "merchant": merchant_id, "id": row.id})
    # Online the host answers with the next snapshot; refresh a moment later.
    get_tree().create_timer(0.15, true).timeout.connect(func():
        if visible:
            _refresh()
    )

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")) and not event.is_echo():
        close()
        get_viewport().set_input_as_handled()
