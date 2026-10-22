extends Control
## Equipment window (opened from the bag, I), after the user's reference images: the character
## large in the middle wearing what is equipped, armour slots in a column on the left, jewellery
## on the right, a stats panel (gear score, stats, active set bonuses) and the owned items as a
## grid of squares. Drag an item onto a slot (or double-click it, or press Equip); drag a worn
## item back to the grid or right-click its slot to take it off. Hovering shows the item card.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const SETS := preload("res://scripts/items/set_catalogue.gd")
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
const ORIGIN := Vector2(20, 8)
const FRAME := Vector2(600, 344)
const CELL := 32.0
const GRID_COLUMNS := 8
const GRID_ROWS := 4
const SLOT_NAMES := {"weapon": "Weapon", "head": "Head", "body": "Body", "hands": "Hands", "feet": "Boots", "accessory_1": "Accessory", "accessory_2": "Accessory"}
## Where the slots sit (left column: armour and weapon; right of the doll: jewellery).
const SLOT_AT := {
    "head": Vector2(14, 44), "body": Vector2(14, 88), "hands": Vector2(14, 132), "feet": Vector2(14, 176), "weapon": Vector2(14, 220),
    "accessory_1": Vector2(234, 88), "accessory_2": Vector2(234, 132),
}
const DOLL := Rect2(62, 40, 164, 230)

## A square cell: a worn slot (`slot` set) or a grid cell. Draws its item's icon on a frame in
## the rarity colour; drag and drop moves items between the grid and the slots.
class GearCell extends Panel:
    var owner_panel: Control
    var slot := ""
    var item_id := ""
    var texture: Texture2D
    var rarity := -1

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP
        texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        add_theme_stylebox_override("panel", UI.round_slot("slot"))
        mouse_entered.connect(func(): owner_panel._hovered = item_id)
        mouse_exited.connect(func():
            if owner_panel._hovered == item_id:
                owner_panel._hovered = ""
        )

    func set_item(id: String, icon: Texture2D, item_rarity: int) -> void:
        if id == item_id and icon == texture and item_rarity == rarity:
            return
        item_id = id
        texture = icon
        rarity = item_rarity
        var style := UI.round_slot("slot")
        if rarity >= 0:
            style.accent = Color(GEAR.RARITY_COLORS[rarity])
        add_theme_stylebox_override("panel", style)
        queue_redraw()

    func _draw() -> void:
        if texture != null:
            draw_texture_rect(texture, Rect2(Vector2(2, 2), size - Vector2(4, 4)), false)
        elif not slot.is_empty():
            var font := get_theme_default_font()
            draw_string(font, Vector2(0, size.y / 2.0 + 3), SLOT_NAMES[slot], HORIZONTAL_ALIGNMENT_CENTER, size.x, 7, Color(0.55, 0.55, 0.6))
        if not item_id.is_empty() and item_id == owner_panel._selected:
            draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), UI.CYAN, false, 1.0)

    func _get_drag_data(_at: Vector2) -> Variant:
        if item_id.is_empty():
            return null
        var preview := TextureRect.new()
        preview.texture = texture
        preview.size = Vector2(28, 28)
        preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        set_drag_preview(preview)
        return {"item": item_id, "from": slot}

    func _can_drop_data(_at: Vector2, data: Variant) -> bool:
        return data is Dictionary and data.has("item") and (slot.is_empty() or owner_panel.fits(data.item, slot))

    func _drop_data(_at: Vector2, data: Variant) -> void:
        owner_panel.dropped(data, slot)

    func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed:
            if event.button_index == MOUSE_BUTTON_LEFT and not item_id.is_empty():
                owner_panel._selected = item_id
                if event.double_click:
                    if slot.is_empty():
                        owner_panel.equip_item(item_id)
                    else:
                        owner_panel._unequip(slot)
            elif event.button_index == MOUSE_BUTTON_RIGHT and not slot.is_empty():
                owner_panel._unequip(slot)

var hud: CanvasLayer
var _slot_cells: Dictionary = {}
var _grid: Array = []
var _doll: Control
var _stats: Label
var _stats_values: Label
var _stats_2: Label
var _stats_2_values: Label
const ATTRIBUTES := preload("res://scripts/progression/attributes.gd")
var _attr_points: Label
var _score: Label
var _details: Label
var _equip: Button
var _salvage: Button
var _salvage_common: Button
var _close: Button
var _selected: String = ""
## Item card (21b) for the hovered item, else the selected one.
var card: PanelContainer
var _hovered: String = ""
var _paused_before_open: bool = false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "GearPanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.85)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var frame := Panel.new()
    frame.position = ORIGIN
    frame.size = FRAME
    frame.add_theme_stylebox_override("panel", UI.ornate())
    add_child(frame)
    UI.heading(hud._label("EQUIPMENT", ORIGIN + Vector2(14, 10), Vector2(200, 20), self, 14))
    _close = hud._button("Close", ORIGIN + Vector2(FRAME.x - 92, 8), Vector2(80, 24), self)
    _close.pressed.connect(close)
    # The character.
    _doll = Control.new()
    _doll.position = ORIGIN + DOLL.position
    _doll.size = DOLL.size
    _doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _doll.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _doll.draw.connect(_draw_doll)
    add_child(_doll)
    for slot in GEAR.SLOTS:
        var cell := GearCell.new()
        cell.owner_panel = self
        cell.slot = slot
        cell.position = ORIGIN + SLOT_AT[slot]
        cell.size = Vector2(40, 40)
        add_child(cell)
        cell.set_item("", null, -1)
        _slot_cells[slot] = cell
    # Stats panel.
    var stats_box := Panel.new()
    stats_box.position = ORIGIN + Vector2(284, 40)
    stats_box.size = Vector2(302, 104)
    stats_box.name = "StatsBox"
    stats_box.add_theme_stylebox_override("panel", UI.hud_box())
    stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(stats_box)
    hud._label("GEAR SCORE", ORIGIN + Vector2(294, 44), Vector2(100, 12), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    _score = UI.heading(hud._label("0", ORIGIN + Vector2(294, 57), Vector2(110, 20), self, 18))
    # SVE feedback: the stats sit in two columns so they fit the box (names left, values right).
    _stats = hud._label("", ORIGIN + Vector2(398, 46), Vector2(90, 94), self, 7)
    _stats_values = hud._label("", ORIGIN + Vector2(398, 46), Vector2(88, 94), self, 7)
    _stats_values.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _stats_2 = hud._label("", ORIGIN + Vector2(496, 46), Vector2(86, 94), self, 7)
    _stats_2_values = hud._label("", ORIGIN + Vector2(496, 46), Vector2(84, 94), self, 7)
    _stats_2_values.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    # M12a: attributes under the gear score, a + for each while points are left.
    for index in range(ATTRIBUTES.KEYS.size()):
        var key: String = ATTRIBUTES.KEYS[index]
        var row_label: Label = hud._label("", ORIGIN + Vector2(294, 80 + index * 12), Vector2(70, 12), self, 7)
        row_label.name = "Attr_" + key
        row_label.tooltip_text = ATTRIBUTES.NAMES[key]
        row_label.mouse_filter = Control.MOUSE_FILTER_PASS
        var plus: Button = hud._button("+", ORIGIN + Vector2(364, 80 + index * 12), Vector2(16, 11), self)
        plus.name = "AttrPlus_" + key
        plus.add_theme_font_size_override("font_size", 7)
        plus.pressed.connect(func(): hud.session.request_action("attribute", {"key": key}))
    _attr_points = hud._label("", ORIGIN + Vector2(294, 128), Vector2(100, 12), self, 7)
    _attr_points.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    var sets_label: Label = hud._label("", ORIGIN + Vector2(294, 82), Vector2(104, 58), self, 7)
    sets_label.name = "Sets"
    sets_label.add_theme_color_override("font_color", Color("7fe3a0"))
    # Owned items: a grid of squares.
    UI.heading(hud._label("ITEMS", ORIGIN + Vector2(284, 148), Vector2(100, 12), self, 9))
    for index in range(GRID_COLUMNS * GRID_ROWS):
        var cell := GearCell.new()
        cell.owner_panel = self
        cell.position = ORIGIN + Vector2(284 + (index % GRID_COLUMNS) * (CELL + 1), 162 + int(index / GRID_COLUMNS) * (CELL + 1))
        cell.size = Vector2(CELL, CELL)
        add_child(cell)
        cell.set_item("", null, -1)
        _grid.append(cell)
    _equip = hud._button("Equip", ORIGIN + Vector2(70, 280), Vector2(150, 24), self)
    _equip.pressed.connect(_equip_selected)
    # User request: salvage gear into materials (at the Forge or in a town).
    _salvage = hud._button("Salvage", ORIGIN + Vector2(70, 308), Vector2(72, 20), self)
    _salvage.name = "Salvage"
    _salvage.pressed.connect(func(): _request({"operation": "salvage", "id": _selected}))
    _salvage_common = hud._button("Salvage Commons", ORIGIN + Vector2(146, 308), Vector2(74, 20), self)
    _salvage_common.name = "SalvageCommon"
    _salvage_common.pressed.connect(func(): _request({"operation": "salvage_common"}))
    for small in [_salvage, _salvage_common]:
        small.add_theme_font_size_override("font_size", 8)
    _details = hud._label("", ORIGIN + Vector2(14, 312), Vector2(260, 14), self, 8)
    _details.hide()
    hud._label("Drag items onto a slot (or double-click) · right-click a slot to take off · G: gear active · I / Esc: close", ORIGIN + Vector2(14, FRAME.y - 20), Vector2(FRAME.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    card = load("res://scripts/ui/item_card.gd").new()
    card.position = ORIGIN + Vector2(62, 40)
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(card)
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

func fits(id: String, slot: String) -> bool:
    var item: Dictionary = hud.player.item_by_id(id)
    return not item.is_empty() and GEAR.slot_fits(item.base, slot)

## A drop: onto a slot equips there; onto the grid takes a worn item off.
func dropped(data: Dictionary, slot: String) -> void:
    if slot.is_empty():
        if not String(data.get("from", "")).is_empty():
            _unequip(data.from)
    else:
        _request({"operation": "equip", "id": data.item, "slot": slot})
    _selected = data.item

func equip_item(id: String) -> void:
    var item: Dictionary = hud.player.item_by_id(id)
    if not item.is_empty():
        _request({"operation": "equip", "id": id, "slot": target_slot(item)})

func _request(payload: Dictionary) -> void:
    if hud.session.active:
        hud.session.request_action("gear", payload)
    elif payload.operation == "equip":
        hud.player.equip(payload.id, payload.slot)
    elif payload.operation == "salvage":
        hud.player.salvage(payload.id)
    elif payload.operation == "salvage_common":
        hud.player.salvage_common()
    else:
        hud.player.unequip(payload.slot)

func _equip_selected() -> void:
    var worn := _worn_slot(_selected)
    if not worn.is_empty():
        _unequip(worn)
    else:
        equip_item(_selected)

func _unequip(slot: String) -> void:
    if hud.player.progression.get("equipment", {}).has(slot):
        _request({"operation": "unequip", "slot": slot})

func _yield_text(item: Dictionary) -> String:
    var parts: Array = []
    var gains: Dictionary = preload("res://scripts/professions/crafting_catalogue.gd").salvage_yield(item)
    for material in gains:
        parts.append("%d %s" % [int(gains[material]), preload("res://scripts/trade/trade_catalogue.gd").item_name(material)])
    return ", ".join(parts)

## Gear score: every worn piece counts by its item level and rarity.
func gear_score() -> int:
    var total := 0.0
    for item in hud.player.equipped_items():
        total += (10.0 + 8.0 * float(GEAR.BASES[item.base].get("level", 1))) * GEAR.RARITY_SCALE[int(item.rarity)]
    return int(round(total))

func refresh() -> void:
    var player = hud.player
    _salvage_common.disabled = not player.gear.items.any(func(item): return int(item.get("rarity", 0)) == 0 and _worn_slot(String(item.id)).is_empty())
    var equipment: Dictionary = player.progression.get("equipment", {})
    for slot in GEAR.SLOTS:
        var item: Dictionary = player.item_by_id(equipment.get(slot, ""))
        _slot_cells[slot].set_item(item.get("id", ""), UI.gear_icon(item), int(item.get("rarity", -1)))
    # The grid lists what is not worn (worn pieces are on the doll).
    var loose: Array = _owned().filter(func(item): return _worn_slot(item.id).is_empty())
    for index in range(_grid.size()):
        var item: Dictionary = loose[index] if index < loose.size() else {}
        _grid[index].set_item(item.get("id", ""), UI.gear_icon(item), int(item.get("rarity", -1)))
        _grid[index].queue_redraw()
    for cell in _slot_cells.values():
        cell.queue_redraw()
    var selected: Dictionary = player.item_by_id(_selected)
    var worn: String = _worn_slot(_selected)
    if selected.is_empty():
        _details.text = "No gear yet. Gear comes from creatures, chests, the forge and merchants." if _owned().is_empty() else "Select an item."
        _equip.disabled = true
        _equip.text = "Equip"
        _salvage.disabled = true
    else:
        # Plain-text details stay available (tests, screen readers); the card shows them.
        _details.text = "%s\n%s\n\n%s" % [GEAR.display_name(selected), "Worn: " + SLOT_NAMES[worn] if not worn.is_empty() else "In the bag", GEAR.describe(selected)]
        _equip.disabled = false
        _equip.text = "Take off" if not worn.is_empty() else "Equip (%s)" % SLOT_NAMES[target_slot(selected)]
        _salvage.disabled = not worn.is_empty()
        _salvage.tooltip_text = "Breaks it into: " + _yield_text(selected) if worn.is_empty() else "Take it off first."
    # The card: the hovered item (else nothing, so the doll stays visible).
    var carded: Dictionary = player.item_by_id(_hovered) if not _hovered.is_empty() else {}
    var place: String = _worn_slot(carded.get("id", ""))
    card.show_item(carded, ("Worn: " + SLOT_NAMES[place]) if not place.is_empty() else "In the bag")
    _score.text = str(gear_score())
    var weapon: Dictionary = player.equipped_weapon()
    var rows: Array = [
        ["Damage", str(int(weapon.stats.damage)) if not weapon.is_empty() else "none"],
        ["Max HP", str(player.get_node("Health").maximum)],
        ["Magicules", str(int(player.get_node("Magicules").maximum))],
        ["Strike", "+%d" % int(player.gear_bonus("strike"))],
        ["Defense", str(int(player.gear_bonus("defense")))],
        ["Speed", str(int(player.current_speed()))],
        ["Regen", "%.1f/s" % float(player.get_node("Magicules").regeneration_per_second)],
    ]
    var left: Array = rows.slice(0, 4)
    var right: Array = rows.slice(4)
    _stats.text = "\n".join(left.map(func(row): return row[0]))
    _stats_values.text = "\n".join(left.map(func(row): return row[1]))
    _stats_2.text = "\n".join(right.map(func(row): return row[0]))
    _stats_2_values.text = "\n".join(right.map(func(row): return row[1]))
    var unspent: int = ATTRIBUTES.unspent(player.progression)
    for key in ATTRIBUTES.KEYS:
        get_node("Attr_" + key).text = "%s  %d" % [ATTRIBUTES.SHORT[key], ATTRIBUTES.value(player.progression, key)]
        get_node("AttrPlus_" + key).visible = unspent > 0
    _attr_points.text = "%d point%s to spend" % [unspent, "" if unspent == 1 else "s"] if unspent > 0 else ""
    var worn_sets := SETS.counts(player.equipped_items(), GEAR.BASES)
    var set_lines: Array = []
    for set_id in worn_sets:
        set_lines.append("%s %d/5" % [SETS.SETS[set_id][0], worn_sets[set_id]])
    get_node("Sets").text = "\n".join(set_lines)
    _doll.queue_redraw()

## The character, large (the worn pieces show in the slots around it).
func _draw_doll() -> void:
    var player = hud.player
    var frames: SpriteFrames = SPRITES.frames(player._body_id())
    var animation := "idle_down" if frames.has_animation("idle_down") else "idle"
    var body: Texture2D = frames.get_frame_texture(animation, 0)
    var rect := Rect2(Vector2(_doll.size.x / 2.0 - 48, 66), Vector2(96, 96))
    _doll.draw_circle(Vector2(_doll.size.x / 2.0, 172), 50, Color(0.12, 0.14, 0.2, 0.6))
    _doll.draw_texture_rect(body, rect, false)
    # User request: the worn pieces are not pasted onto the character (the art has no wearable
    # layers); the slots around it show them.

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
