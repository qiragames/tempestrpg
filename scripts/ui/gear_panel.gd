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
const SLOT_NAMES := {"weapon": "Weapon", "head": "Head", "body": "Body", "hands": "Hands", "feet": "Feet", "accessory_1": "Accessory", "accessory_2": "Accessory"}
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
            style.border_color = Color(GEAR.RARITY_COLORS[rarity])
            style.set_border_width_all(2 if rarity >= 3 else 1)
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
var _score: Label
var _details: Label
var _equip: Button
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
    _score = UI.heading(hud._label("0", ORIGIN + Vector2(294, 54), Vector2(110, 24), self, 18))
    _stats = hud._label("", ORIGIN + Vector2(400, 43), Vector2(182, 98), self, 7)
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

## Gear score: every worn piece counts by its item level and rarity.
func gear_score() -> int:
    var total := 0.0
    for item in hud.player.equipped_items():
        total += (10.0 + 8.0 * float(GEAR.BASES[item.base].get("level", 1))) * GEAR.RARITY_SCALE[int(item.rarity)]
    return int(round(total))

func refresh() -> void:
    var player = hud.player
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
    else:
        # Plain-text details stay available (tests, screen readers); the card shows them.
        _details.text = "%s\n%s\n\n%s" % [GEAR.display_name(selected), "Worn: " + SLOT_NAMES[worn] if not worn.is_empty() else "In the bag", GEAR.describe(selected)]
        _equip.disabled = false
        _equip.text = "Take off" if not worn.is_empty() else "Equip (%s)" % SLOT_NAMES[target_slot(selected)]
    # The card: the hovered item (else nothing, so the doll stays visible).
    var carded: Dictionary = player.item_by_id(_hovered) if not _hovered.is_empty() else {}
    var place: String = _worn_slot(carded.get("id", ""))
    card.show_item(carded, ("Worn: " + SLOT_NAMES[place]) if not place.is_empty() else "In the bag")
    _score.text = str(gear_score())
    var weapon: Dictionary = player.equipped_weapon()
    var lines: Array = [
        "Weapon damage   %s" % (str(int(weapon.stats.damage)) if not weapon.is_empty() else "unarmed"),
        "Max HP          %d" % player.get_node("Health").maximum,
        "Magicules       %d" % int(player.get_node("Magicules").maximum),
        "Strike bonus    +%d" % int(player.gear_bonus("strike")),
        "Defense         %d" % int(player.gear_bonus("defense")),
        "Move speed      %d" % int(player.current_speed()),
        "Regeneration    %.1f/s" % float(player.get_node("Magicules").regeneration_per_second),
    ]
    _stats.text = "\n".join(lines)
    var worn_sets := SETS.counts(player.equipped_items(), GEAR.BASES)
    var set_lines: Array = []
    for set_id in worn_sets:
        set_lines.append("%s %d/5" % [SETS.SETS[set_id][0], worn_sets[set_id]])
    get_node("Sets").text = "\n".join(set_lines)
    _doll.queue_redraw()

## The character, large, with the worn pieces drawn on: helmet, armour, gloves, boots, weapon in
## hand, jewellery at the neck.
func _draw_doll() -> void:
    var player = hud.player
    var frames: SpriteFrames = SPRITES.frames(player._body_id())
    var animation := "idle_down" if frames.has_animation("idle_down") else "idle"
    var body: Texture2D = frames.get_frame_texture(animation, 0)
    var rect := Rect2(Vector2(_doll.size.x / 2.0 - 48, 66), Vector2(96, 96))
    _doll.draw_circle(Vector2(_doll.size.x / 2.0, 172), 50, Color(0.12, 0.14, 0.2, 0.6))
    _doll.draw_texture_rect(body, rect, false)
    var equipment: Dictionary = player.progression.get("equipment", {})
    var parts := {"body": [Vector2(0, 14), 32.0], "feet": [Vector2(0, 38), 22.0], "hands": [Vector2(-22, 16), 16.0], "head": [Vector2(0, -20), 32.0],
        "accessory_1": [Vector2(-6, 2), 11.0], "accessory_2": [Vector2(6, 2), 11.0], "weapon": [Vector2(34, 6), 38.0]}
    var centre := rect.get_center()
    for slot in ["feet", "body", "hands", "accessory_1", "accessory_2", "head", "weapon"]:
        var item: Dictionary = player.item_by_id(equipment.get(slot, ""))
        if item.is_empty():
            continue
        var icon := UI.gear_icon(item)
        if icon == null:
            continue
        var size: float = parts[slot][1]
        var at: Vector2 = centre + parts[slot][0] - Vector2(size, size) / 2.0
        if slot == "hands":
            # Both hands.
            _doll.draw_texture_rect(icon, Rect2(at, Vector2(size, size)), false)
            _doll.draw_texture_rect(icon, Rect2(centre + Vector2(22, 16) - Vector2(size, size) / 2.0, Vector2(size, size)), false)
            continue
        if int(item.rarity) >= 3:
            var element: String = String(GEAR.BASES[item.base].get("element", ""))
            var glow: Color = preload("res://scripts/items/element_catalogue.gd").color(element) if not element.is_empty() else Color(GEAR.RARITY_COLORS[int(item.rarity)])
            _doll.draw_circle(at + Vector2(size, size) / 2.0, size * 0.55, Color(glow, 0.18))
        _doll.draw_texture_rect(icon, Rect2(at, Vector2(size, size)), false)

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
