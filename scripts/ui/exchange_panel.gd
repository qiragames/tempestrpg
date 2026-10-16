extends Control
## The trade window (M11c): opens by itself while your character is in a trade. Left, your things
## (unworn gear and bag items) to put on the table; middle, your offer with Zeni; right, what your
## partner offers and whether they are ready. Only your new offer, Ready or Cancel go to the host
## (the "exchange" intent); the host's state comes back with the snapshots. Someone asking to trade
## with you gets a question (accept / decline).
const UI := preload("res://scripts/ui/ui_style.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const FRAME := Rect2(30, 14, 580, 332)
const COLUMN := 178.0

var hud: CanvasLayer
var _mine: VBoxContainer
var _offer: VBoxContainer
var _theirs: VBoxContainer
var _title: Label
var _status: Label
var _ready: Button
var _zeni_label: Label
var _asked := ""
var _shown_signature := ""
var _paused_before := false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "ExchangePanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.75)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var frame := Panel.new()
    frame.position = FRAME.position
    frame.size = FRAME.size
    frame.add_theme_stylebox_override("panel", UI.ornate())
    add_child(frame)
    _title = UI.heading(hud._label("TRADE", FRAME.position + Vector2(14, 10), Vector2(400, 20), self, 14))
    var headings := ["Your things (click to offer)", "Your offer", "Their offer"]
    var lists: Array = []
    for index in range(3):
        var x: float = FRAME.position.x + 14 + index * (COLUMN + 6)
        hud._label(headings[index], Vector2(x, FRAME.position.y + 36), Vector2(COLUMN, 14), self, 9).add_theme_color_override("font_color", UI.GOLD_LIGHT)
        var scroll := ScrollContainer.new()
        scroll.position = Vector2(x, FRAME.position.y + 52)
        scroll.size = Vector2(COLUMN, 200 if index != 1 else 170)
        add_child(scroll)
        var list := VBoxContainer.new()
        list.custom_minimum_size = Vector2(COLUMN - 12, 0)
        list.add_theme_constant_override("separation", 2)
        scroll.add_child(list)
        lists.append(list)
    _mine = lists[0]
    _offer = lists[1]
    _theirs = lists[2]
    var zeni_x: float = FRAME.position.x + 14 + COLUMN + 6
    _zeni_label = hud._label("Zeni: 0", Vector2(zeni_x, FRAME.position.y + 226), Vector2(COLUMN, 14), self, 9)
    var steps := [[-1000, "-1k"], [-100, "-100"], [100, "+100"], [1000, "+1k"]]
    for index in range(steps.size()):
        var button: Button = hud._button(steps[index][1], Vector2(zeni_x + index * 44, FRAME.position.y + 242), Vector2(42, 18), self)
        button.add_theme_font_size_override("font_size", 8)
        button.pressed.connect(_change_zeni.bind(int(steps[index][0])))
    _ready = hud._button("Ready", FRAME.position + Vector2(14, FRAME.size.y - 56), Vector2(140, 26), self)
    _ready.pressed.connect(func():
        var trade := current()
        hud.session.request_action("exchange", {"operation": "ready", "value": not bool(trade.get("ready", {}).get(me(), false))})
    )
    var cancel: Button = hud._button("Cancel trade", FRAME.position + Vector2(160, FRAME.size.y - 56), Vector2(140, 26), self)
    cancel.pressed.connect(func(): hud.session.request_action("exchange", {"operation": "cancel"}))
    _status = hud._label("", FRAME.position + Vector2(14, FRAME.size.y - 26), Vector2(FRAME.size.x - 28, 14), self, 9)
    _status.add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func exchange() -> Node:
    return hud.get_parent().get("exchange")

func me() -> String:
    return hud.player.character_id if is_instance_valid(hud.player) else ""

## The trade this peer's character is in ({} for none).
func current() -> Dictionary:
    var node := exchange()
    if node == null:
        return {}
    var id: String = node.trade_of(me())
    return node.state.trades.get(id, {}) if not id.is_empty() else {}

func is_open() -> bool:
    return visible

func _my_offer() -> Dictionary:
    var trade := current()
    return trade.get("offer", {}).get(me(), {"gear": [], "goods": {}, "zeni": 0}).duplicate(true)

func _send_offer(offer: Dictionary) -> void:
    hud.session.request_action("exchange", {"operation": "offer", "offer": offer})

func _change_zeni(step: int) -> void:
    var offer := _my_offer()
    offer.zeni = clampi(int(offer.zeni) + step, 0, int(hud.player.progression.get("zeni", 0)))
    _send_offer(offer)

func _add_gear(id: String) -> void:
    var offer := _my_offer()
    if not id in offer.gear:
        offer.gear.append(id)
        _send_offer(offer)

func _add_good(id: String, count: int) -> void:
    var offer := _my_offer()
    var have: int = hud.player.get_node("Inventory").count_of(id)
    offer.goods[id] = mini(have, int(offer.goods.get(id, 0)) + count)
    _send_offer(offer)

func _remove(kind: String, id: String) -> void:
    var offer := _my_offer()
    if kind == "gear":
        offer.gear.erase(id)
    else:
        offer.goods.erase(id)
    _send_offer(offer)

func _process(_delta: float) -> void:
    if not is_instance_valid(hud.player):
        return
    var node := exchange()
    if node == null:
        return
    # A question when someone asks to trade with you.
    var asked: Dictionary = node.state.requests.get(me(), {})
    var asker: String = String(asked.get("from", ""))
    if not asker.is_empty() and asker != _asked and not hud.menu_open():
        _asked = asker
        hud.dialog_panel.open("Trade", "%s wants to trade with you." % asker.left(24), [["Trade", func(): hud.session.request_action("exchange", {"operation": "accept"})], ["Decline", func(): hud.session.request_action("exchange", {"operation": "decline"})]])
    if asker.is_empty():
        _asked = ""
    var trade := current()
    if trade.is_empty():
        if visible:
            _close()
        return
    if not visible and not hud.menu_open():
        _open()
    if visible:
        var signature := JSON.stringify([trade, hud.player.gear.items.size(), hud.player.get_node("Inventory").total_units(), hud.player.progression.get("zeni", 0)])
        if signature != _shown_signature:
            _shown_signature = signature
            refresh()

func _open() -> void:
    _paused_before = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
    show()
    _shown_signature = ""

func _close() -> void:
    hide()
    if hud.session.active and is_instance_valid(hud.player):
        hud.player.input_blocked = false

func refresh() -> void:
    var trade := current()
    if trade.is_empty():
        return
    var partner: String = trade.b if trade.a == me() else trade.a
    _title.text = "TRADE WITH %s" % partner.left(24).to_upper()
    for list in [_mine, _offer, _theirs]:
        for child in list.get_children():
            child.queue_free()
    var offer: Dictionary = trade.offer.get(me(), {})
    var worn: Array = hud.player.progression.get("equipment", {}).values()
    # Your things.
    for item in hud.player.gear.items:
        if item.id in worn or item.id in offer.get("gear", []):
            continue
        var button: Button = _line(_mine, GEAR.display_name(item), GEAR.icon_texture(item.base, int(item.rarity)))
        button.pressed.connect(_add_gear.bind(item.id))
    for entry in hud.player.get_node("Inventory").entries():
        var id := String(entry.id)
        var left: int = int(entry.count) - int(offer.get("goods", {}).get(id, 0))
        if left <= 0:
            continue
        var button: Button = _line(_mine, "%s ×%d" % [entry.name, left], null)
        button.pressed.connect(_add_good.bind(id, 1 if not Input.is_key_pressed(KEY_SHIFT) else left))
    # Your offer.
    for id in offer.get("gear", []):
        var item: Dictionary = hud.player.item_by_id(id)
        if not item.is_empty():
            _line(_offer, "✕ %s" % GEAR.display_name(item), GEAR.icon_texture(item.base, int(item.rarity))).pressed.connect(_remove.bind("gear", id))
    for id in offer.get("goods", {}):
        _line(_offer, "✕ %s ×%d" % [TRADE.good_info(id)[0] if TRADE.is_good(id) else id, int(offer.goods[id])], null).pressed.connect(_remove.bind("goods", id))
    _zeni_label.text = "Zeni: %d (you have %d)" % [int(offer.get("zeni", 0)), int(hud.player.progression.get("zeni", 0))]
    # Theirs.
    var theirs: Dictionary = trade.offer.get(partner, {})
    var partner_actor: Node = hud.get_parent().player_by_id(partner)
    for id in theirs.get("gear", []):
        var item: Dictionary = partner_actor.item_by_id(id) if partner_actor != null else {}
        var line: Button = _line(_theirs, GEAR.display_name(item) if not item.is_empty() else id, GEAR.icon_texture(item.base, int(item.rarity)) if not item.is_empty() else null)
        line.disabled = true
    for id in theirs.get("goods", {}):
        _line(_theirs, "%s ×%d" % [TRADE.good_info(id)[0] if TRADE.is_good(id) else id, int(theirs.goods[id])], null).disabled = true
    if int(theirs.get("zeni", 0)) > 0:
        _line(_theirs, "%d Zeni" % int(theirs.zeni), null).disabled = true
    var mine_ready: bool = bool(trade.ready.get(me(), false))
    var their_ready: bool = bool(trade.ready.get(partner, false))
    _ready.text = "Not ready" if mine_ready else "Ready"
    _status.text = "%s · %s · both ready: everything changes hands · Shift-click: whole stack" % ["You are ready" if mine_ready else "You are not ready", "%s is ready" % partner.left(16) if their_ready else "%s is not ready" % partner.left(16)]

func _line(list: VBoxContainer, text: String, icon: Texture2D) -> Button:
    var button := Button.new()
    button.text = text
    button.icon = icon
    button.expand_icon = true
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.custom_minimum_size = Vector2(COLUMN - 14, 18)
    button.add_theme_font_size_override("font_size", 8)
    button.add_theme_constant_override("icon_max_width", 14)
    button.clip_text = true
    list.add_child(button)
    return button
