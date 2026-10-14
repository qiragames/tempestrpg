extends Control
## Shop and ferry window (M4.5c). F next to a merchant opens its stock (Buy) and what it would
## take from you (Sell); F on a pier offers the crossing. The window only names merchant, entry
## or dock; the host checks distance, stock, Zeni and room (WorldTrade).
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const FRAME := Rect2(96, 40, 448, 276)

var hud: CanvasLayer
var merchant_id := ""
var dock_id := ""
var selling := false
var _title: Label
var _purse: Label
var _face: TextureRect
var _list: ItemList
var _details: Label
var _action: Button
var _buy_tab: Button
var _sell_tab: Button
var _close: Button
var _rows: Array = []
var _paused_before := false

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
    var o := FRAME.position
    _face = TextureRect.new()
    _face.position = o + Vector2(12, 8)
    _face.size = Vector2(32, 32)
    _face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    add_child(_face)
    _title = UI.heading(hud._label("", o + Vector2(50, 10), Vector2(300, 20), self, 14))
    _purse = hud._label("", o + Vector2(50, 28), Vector2(200, 14), self, 10)
    _purse.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _close = hud._button("Close", o + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    _close.pressed.connect(close)
    _buy_tab = hud._button("Buy", o + Vector2(12, 48), Vector2(80, 24), self)
    _buy_tab.pressed.connect(func(): _switch(false))
    _sell_tab = hud._button("Sell", o + Vector2(96, 48), Vector2(80, 24), self)
    _sell_tab.pressed.connect(func(): _switch(true))
    _list = ItemList.new()
    _list.position = o + Vector2(12, 78)
    _list.size = Vector2(220, 168)
    _list.add_theme_font_size_override("font_size", 10)
    _list.item_selected.connect(func(_index): _refresh_details())
    add_child(_list)
    _details = hud._label("", o + Vector2(242, 80), Vector2(194, 130), self, 10)
    _details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _action = hud._button("", o + Vector2(242, 216), Vector2(194, 30), self)
    _action.pressed.connect(_act)
    hud._label("F / Esc: close · Selling pays %d%% of the price" % int(TRADE.SELL_SHARE * 100), o + Vector2(12, FRAME.size.y - 22), Vector2(400, 14), self, 9).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func world() -> Node:
    return hud.get_parent()

func open(id: String) -> void:
    merchant_id = id
    dock_id = ""
    selling = false
    _show()

func open_ferry(id: String) -> void:
    dock_id = id
    merchant_id = ""
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
    _refresh()

func _process(_delta: float) -> void:
    if visible:
        _purse.text = "Your purse: %d Zeni" % hud.player.zeni()

## Rebuild the list from the merchant's current stock (or the player's sellables).
func _refresh() -> void:
    _purse.text = "Your purse: %d Zeni" % hud.player.zeni()
    _list.clear()
    _rows.clear()
    var ferry := not dock_id.is_empty()
    _buy_tab.visible = not ferry
    _sell_tab.visible = not ferry
    _list.visible = not ferry
    if ferry:
        var here: Array = MAP.ferry(dock_id)
        var there: Array = MAP.ferry(here[4])
        _title.text = here[1].to_upper()
        _face.texture = load("res://assets/game/sprites/ferryman/ferryman_face.png")
        _details.position = FRAME.position + Vector2(12, 80)
        _details.size = Vector2(420, 120)
        _details.text = "The ferryman can take you across the sea to %s (%s).\n\nThe crossing costs %d Zeni." % [there[1], MAP.region_name(MAP.dock_position(there[0])), TRADE.FERRY_FARE]
        _action.text = "Sail · %d Zeni" % TRADE.FERRY_FARE
        _action.disabled = hud.player.zeni() < TRADE.FERRY_FARE
        return
    _details.position = FRAME.position + Vector2(242, 80)
    _details.size = Vector2(194, 130)
    var entry: Array = TRADE.merchant(merchant_id)
    _title.text = entry[1].to_upper()
    _face.texture = load("res://assets/game/sprites/%s/%s_face.png" % [entry[2], entry[2]])
    _buy_tab.disabled = not selling
    _sell_tab.disabled = selling
    if not selling:
        for item in world().trade.state.merchants.get(merchant_id, {}).get("stock", []):
            if int(item.count) <= 0:
                continue
            _rows.append(item)
            _list.add_item("%s · %d Z%s" % [world().trade.describe(item), int(item.price), "" if item.kind == "gear" else " ×%d" % int(item.count)])
    else:
        var kind: String = entry[3]
        if kind != "smith":
            for bag_entry in hud.player.get_node("Inventory").entries():
                var price := TRADE.price(String(bag_entry.id))
                if price > 0:
                    _rows.append({"kind": "bag", "id": String(bag_entry.id), "price": TRADE.sell_price(price), "name": bag_entry.name, "count": bag_entry.count})
                    _list.add_item("%s ×%d · %d Z" % [bag_entry.name, bag_entry.count, TRADE.sell_price(price)])
        if kind != "trader":
            var worn: Array = hud.player.progression.get("equipment", {}).values()
            for item in hud.player.gear.items:
                if item.id in worn:
                    continue
                var value := TRADE.sell_price(TRADE.gear_price(item, entry[5]))
                _rows.append({"kind": "gear", "id": item.id, "price": value, "item": item})
                _list.add_item("%s · %d Z" % [GEAR.display_name(item), value])
    if _rows.is_empty():
        _details.text = "Nothing to sell here." if selling else "Sold out until the next restock."
        _action.text = "—"
        _action.disabled = true
        return
    _list.select(0)
    _refresh_details()

func _refresh_details() -> void:
    if not dock_id.is_empty() or _rows.is_empty():
        return
    var selected: PackedInt32Array = _list.get_selected_items()
    var row: Dictionary = _rows[selected[0] if not selected.is_empty() else 0]
    var text := ""
    match row.kind:
        "gear":
            text = GEAR.describe(row.item)
        "good":
            var info: Array = TRADE.good_info(row.id)
            text = "%s\n%s\n\n%s" % [info[0], info[1], info[2]]
        "material":
            text = "%s\nMaterial\n\nWanted by crafters and merchants." % row.id.replace("_", " ").capitalize()
        "bag":
            text = "%s ×%d\n\nSell one for %d Zeni." % [row.name, int(row.count), int(row.price)]
    _details.text = text
    if selling:
        _action.text = "Sell · %d Zeni" % int(row.price)
        _action.disabled = false
    else:
        _action.text = "Buy · %d Zeni" % int(row.price)
        _action.disabled = hud.player.zeni() < int(row.price)

func _act() -> void:
    if not dock_id.is_empty():
        hud.session.request_action("ferry", {"dock": dock_id})
        close()
        return
    var selected: PackedInt32Array = _list.get_selected_items()
    if _rows.is_empty() or selected.is_empty():
        return
    var row: Dictionary = _rows[selected[0]]
    if selling:
        hud.session.request_action("trade", {"operation": "sell", "merchant": merchant_id, "kind": "gear" if row.kind == "gear" else "bag", "id": row.id})
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
