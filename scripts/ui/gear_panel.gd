extends Control
## Equipment window (opened from the bag). Left: the six slots (click to take an item off).
## Middle: owned items in rarity colours. Right: details and Equip. G uses a ready gear active.
## Styled after the inventory reference (step 21): gold-trimmed frame, item icons per base and rarity.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const ORIGIN := Vector2(30, 34)
const FRAME := Vector2(580, 292)
const SLOT_NAMES := {"weapon": "Weapon", "head": "Head", "body": "Body", "hands": "Hands", "feet": "Feet", "accessory_1": "Accessory", "accessory_2": "Accessory"}

var hud: CanvasLayer
var _slot_buttons: Dictionary = {}
var _items: ItemList
var _details: Label
var _equip: Button
var _totals: Label
var _close: Button
var _selected: String = ""
var _paused_before_open: bool = false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "GearPanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.8)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var frame := Panel.new()
    frame.position = ORIGIN
    frame.size = FRAME
    frame.add_theme_stylebox_override("panel", hud._panel_style())
    add_child(frame)
    UI.heading(hud._label("EQUIPMENT", ORIGIN + Vector2(12, 8), Vector2(300, 20), self, 14))
    UI.heading(hud._label("WORN", ORIGIN + Vector2(12, 24), Vector2(172, 12), self, 9))
    UI.heading(hud._label("OWNED GEAR", ORIGIN + Vector2(194, 24), Vector2(188, 12), self, 9))
    UI.heading(hud._label("DETAILS", ORIGIN + Vector2(394, 24), Vector2(176, 12), self, 9))
    _close = hud._button("Close", ORIGIN + Vector2(FRAME.x - 88, 6), Vector2(80, 24), self)
    _close.pressed.connect(close)
    for index in range(GEAR.SLOTS.size()):
        var slot: String = GEAR.SLOTS[index]
        var button: Button = hud._button("", ORIGIN + Vector2(12, 38 + index * 26), Vector2(172, 23), self)
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.expand_icon = false
        button.pressed.connect(_unequip.bind(slot))
        _slot_buttons[slot] = button
    _items = ItemList.new()
    _items.position = ORIGIN + Vector2(194, 38)
    _items.size = Vector2(188, 176)
    _items.add_theme_font_size_override("font_size", 10)
    _items.item_selected.connect(func(index): _selected = _owned()[index].id; refresh())
    add_child(_items)
    _details = hud._label("", ORIGIN + Vector2(394, 38), Vector2(176, 150), self, 10)
    _equip = hud._button("Equip", ORIGIN + Vector2(394, 190), Vector2(176, 24), self)
    _equip.pressed.connect(_equip_selected)
    _totals = hud._label("", ORIGIN + Vector2(12, 222), Vector2(556, 30), self, 10)
    hud._label("Click a slot to take an item off · G: use a gear active · I / Esc: close", ORIGIN + Vector2(12, 270), Vector2(500, 16), self, 9)
    hide()

func _owned() -> Array:
    return hud.player.gear.items

func _worn_slot(id: String) -> String:
    var equipment: Dictionary = hud.player.progression.get("equipment", {})
    for slot in equipment:
        if equipment[slot] == id:
            return slot
    return ""

## Accessories go to the first free accessory slot (or the first one).
func target_slot(item: Dictionary) -> String:
    var kind: String = GEAR.BASES[item.base].slot
    if kind != "accessory":
        return kind
    var equipment: Dictionary = hud.player.progression.get("equipment", {})
    return "accessory_2" if equipment.has("accessory_1") and not equipment.has("accessory_2") else "accessory_1"

func _request(payload: Dictionary) -> void:
    if hud.session.active:
        hud.session.request_action("gear", payload)
    elif payload.operation == "equip":
        hud.player.equip(payload.id, payload.slot)
    else:
        hud.player.unequip(payload.slot)

func _equip_selected() -> void:
    var item: Dictionary = hud.player.item_by_id(_selected)
    if not item.is_empty():
        _request({"operation": "equip", "id": _selected, "slot": target_slot(item)})

func _unequip(slot: String) -> void:
    if hud.player.progression.get("equipment", {}).has(slot):
        _request({"operation": "unequip", "slot": slot})

func refresh() -> void:
    var player = hud.player
    var equipment: Dictionary = player.progression.get("equipment", {})
    for slot in GEAR.SLOTS:
        var item: Dictionary = player.item_by_id(equipment.get(slot, ""))
        _slot_buttons[slot].text = "%s: %s" % [SLOT_NAMES[slot], "—" if item.is_empty() else GEAR.display_name(item)]
        _slot_buttons[slot].icon = UI.gear_icon(item)
        _slot_buttons[slot].add_theme_color_override("font_color", Color(GEAR.RARITY_COLORS[int(item.rarity)]) if not item.is_empty() else Color(0.6, 0.65, 0.68))
    var owned: Array = _owned()
    _items.clear()
    for index in range(owned.size()):
        var item: Dictionary = owned[index]
        _items.add_item(("● " if not _worn_slot(item.id).is_empty() else "") + GEAR.display_name(item), UI.gear_icon(item))
        _items.set_item_custom_fg_color(index, Color(GEAR.RARITY_COLORS[int(item.rarity)]))
        if item.id == _selected:
            _items.select(index)
    var selected: Dictionary = player.item_by_id(_selected)
    if selected.is_empty():
        _details.text = "No gear yet. Gear comes from creatures, chests and the camp forge (later steps)." if owned.is_empty() else "Select an item to see its stats."
        _equip.disabled = true
    else:
        var worn: String = _worn_slot(selected.id)
        _details.text = "%s\n%s\n\n%s" % [GEAR.display_name(selected), "Worn: " + SLOT_NAMES[worn] if not worn.is_empty() else "In the bag", GEAR.describe(selected)]
        _equip.disabled = not worn.is_empty() and worn == target_slot(selected)
        _equip.text = "Equip (%s)" % SLOT_NAMES[target_slot(selected)]
    var parts: Array = []
    for stat in GEAR.STATS:
        var value: float = player.gear_bonus(stat)
        if value != 0:
            var shown: String = str(int(value)) if value == floor(value) else str(value)
            parts.append(GEAR.STAT_TEXT[stat] % (("+" if value > 0 else "") + shown if stat == "speed" else shown))
    _totals.text = "Gear total: " + (", ".join(parts) if not parts.is_empty() else "nothing equipped")

func _process(_delta: float) -> void:
    if visible:
        refresh()

func open() -> void:
    if hud.menu_open():
        return
    _paused_before_open = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    if _selected.is_empty() and not _owned().is_empty():
        _selected = _owned()[0].id
    refresh()
    show()
    _close.grab_focus()

func close() -> void:
    if not visible:
        return
    hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before_open
