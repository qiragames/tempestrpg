extends PanelContainer
## Item card after the user's tooltip reference (step 21b): framed in the rarity colour, icon in a
## rarity frame, name and rarity/type badges, DPS and attack speed for weapons, stat rows (green
## bonus, red penalty, dim roll range), passives, the active and where the item is. Lower rarities
## simply have fewer lines. Only real item data is shown (no requirements/class/level systems).
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const WIDTH := 176.0
## Tallest card (Legendary weapon, two long passives, active) still fits this.
const MAX_HEIGHT := 222.0
const GOOD := Color("7ee08a")
const BAD := Color("ef6b62")
const STAT_NAMES := {"damage": "Weapon damage", "hp": "Max HP", "magicules": "Max Magicules", "regen": "Magicules/s", "speed": "Move speed", "strike": "Strike damage", "defense": "Damage taken"}
const SLOT_TYPES := {"head": "Head", "body": "Body", "hands": "Hands", "feet": "Feet", "accessory": "Accessory"}

var item: Dictionary = {}
var _box: VBoxContainer
var _key: String = "-"

func _init() -> void:
    name = "ItemCard"
    custom_minimum_size = Vector2(WIDTH, 0)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _box = VBoxContainer.new()
    _box.add_theme_constant_override("separation", 1)
    add_child(_box)

## Attack speed in hits per second (weapons), from the type's recovery time.
static func hits_per_second(item_data: Dictionary) -> float:
    return 1.0 / GEAR.WEAPONS[GEAR.BASES[item_data.base].weapon].recovery

static func dps(item_data: Dictionary) -> float:
    return float(item_data.stats.damage) * hits_per_second(item_data)

static func speed_name(hits: float) -> String:
    return "Fast" if hits >= 2.0 else ("Normal" if hits >= 1.6 else "Slow")

static func type_name(item_data: Dictionary) -> String:
    var base: Dictionary = GEAR.BASES[item_data.base]
    return GEAR.WEAPONS[base.weapon].name if base.has("weapon") else SLOT_TYPES[base.slot]

## Shown value of a stat and whether it helps the wearer (less damage taken is good).
static func stat_value(stat: String, value: float) -> Array:
    var text := str(int(value)) if value == floor(value) else str(value)
    match stat:
        "damage":
            return [text, true]
        "defense":
            return ["-" + text, true]
    return [("+" if value > 0 else "") + text, value >= 0]

## Show an item; `where` is the footer ("Worn: Weapon", "In the bag", or empty).
func show_item(item_data: Dictionary, where: String = "") -> void:
    # Windows refresh every frame; rebuild only when the item or its place changed.
    var key := var_to_str(item_data) + where
    if key == _key:
        return
    _key = key
    item = item_data
    for child in _box.get_children():
        _box.remove_child(child)
        child.queue_free()
    visible = not item.is_empty()
    if item.is_empty():
        return
    var rarity: int = int(item.rarity)
    var color := Color(GEAR.RARITY_COLORS[rarity])
    add_theme_stylebox_override("panel", UI.ornate("card", color))
    # Header: framed icon, name, badges.
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 6)
    _box.add_child(header)
    var icon_frame := PanelContainer.new()
    var icon_box := UI.box("well")
    icon_box.border_color = color
    icon_box.set_content_margin_all(2)
    icon_frame.add_theme_stylebox_override("panel", icon_box)
    icon_frame.name = "IconFrame"
    var icon := TextureRect.new()
    icon.name = "Icon"
    icon.texture = UI.gear_icon(item)
    icon.custom_minimum_size = Vector2(32, 32)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    icon_frame.add_child(icon)
    header.add_child(icon_frame)
    var titles := VBoxContainer.new()
    titles.add_theme_constant_override("separation", 2)
    titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(titles)
    var title := _label(GEAR.BASES[item.base].name, 11, color, titles)
    title.name = "Name"
    var badges := HBoxContainer.new()
    badges.add_theme_constant_override("separation", 3)
    titles.add_child(badges)
    _badge(GEAR.RARITIES[rarity].to_upper(), color, Color(0.06, 0.05, 0.08), badges).name = "RarityBadge"
    _badge(type_name(item).to_upper(), Color(0.86, 0.84, 0.8), Color(0.06, 0.05, 0.08), badges).name = "TypeBadge"
    # Weapons: DPS, attack speed and damage.
    if GEAR.BASES[item.base].has("weapon"):
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 3)
        _box.add_child(row)
        _label("%d" % roundi(dps(item)), 16, Color("f4e9d8"), row).name = "Dps"
        _label("DPS", 9, UI.TEXT_DIM, row).size_flags_vertical = Control.SIZE_SHRINK_END
        var hits := hits_per_second(item)
        var speed := _label("%s %s · %.1f hits/s" % [speed_name(hits), GEAR.WEAPONS[GEAR.BASES[item.base].weapon].name.to_lower(), hits], 9, UI.TEXT_DIM, _box)
        speed.name = "Speed"
        speed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _box.add_child(_divider(color))
    # Stats: name, value (green/red) and the roll range for this rarity.
    var grid := GridContainer.new()
    grid.name = "Stats"
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 4)
    grid.add_theme_constant_override("v_separation", 1)
    _box.add_child(grid)
    for stat in item.stats:
        var shown: Array = stat_value(stat, float(item.stats[stat]))
        var span: Array = GEAR.stat_range(item.base, stat, rarity)
        var name_label := _label(STAT_NAMES[stat], 10, UI.TEXT, grid)
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var low: String = stat_value(stat, span[0])[0]
        var high: String = stat_value(stat, span[1])[0]
        var value := _label("%s  (%s to %s)" % [shown[0], low, high] if span[0] != span[1] else shown[0], 10, GOOD if shown[1] else BAD, grid)
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    # Passives (Rare and up) and the active (Epic and Legendary).
    if not item.passives.is_empty() or not String(item.active).is_empty():
        _box.add_child(_divider(color))
    for passive in item.passives:
        _label("• " + GEAR.PASSIVES[passive], 9, GOOD, _box).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if not String(item.active).is_empty():
        var active: Dictionary = GEAR.ACTIVES[item.active]
        _label("Active (G): %s" % active.name, 10, UI.CYAN, _box).name = "Active"
        _label("%s · %d s cooldown" % [active.text, int(active.cooldown)], 9, UI.TEXT_DIM, _box).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if not where.is_empty():
        _label(where, 9, UI.TEXT_DIM, _box).name = "Where"
    _fit()
    # Wrapped lines settle their height after layout; fit again once they have.
    _fit.call_deferred()

## Shrink to the content: fixed width, height of the current lines.
func _fit() -> void:
    size = Vector2(WIDTH, get_combined_minimum_size().y)

func _label(text: String, font_size: int, color: Color, parent: Node) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.custom_minimum_size.x = 0
    parent.add_child(label)
    return label

func _badge(text: String, background: Color, ink: Color, parent: Node) -> Label:
    var label := _label(text, 8, ink, parent)
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.content_margin_left = 3
    style.content_margin_right = 3
    label.add_theme_stylebox_override("normal", style)
    return label

## Thin rule in the rarity colour with a small diamond in the middle (as in the reference).
func _divider(color: Color) -> Control:
    var rule := Control.new()
    rule.custom_minimum_size = Vector2(0, 7)
    rule.draw.connect(func():
        var middle := rule.size.x / 2.0
        rule.draw_line(Vector2(8, 3.5), Vector2(middle - 6, 3.5), Color(color, 0.6), 1.0)
        rule.draw_line(Vector2(middle + 6, 3.5), Vector2(rule.size.x - 8, 3.5), Color(color, 0.6), 1.0)
        rule.draw_colored_polygon(PackedVector2Array([Vector2(middle, 0), Vector2(middle + 4, 3.5), Vector2(middle, 7), Vector2(middle - 4, 3.5)]), color)
    )
    return rule

## The card's text, top to bottom (for tests and accessibility).
func plain_text() -> String:
    var parts: Array = []
    _collect(self, parts)
    return "\n".join(parts)

func _collect(node: Node, parts: Array) -> void:
    for child in node.get_children():
        if child is Label and not child.is_queued_for_deletion():
            parts.append(child.text)
        _collect(child, parts)
