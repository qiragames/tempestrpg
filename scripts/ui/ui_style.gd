extends RefCounted
## Shared interface look. M13 (user choice 2026-10-18, mockup docs/ui_overhaul/): a pixel UI from
## the Dogobongocat UI pack (CC0) — navy panels, parchment, gold-cornered slots, plates and bars —
## with three pixel fonts kept at their native size so they stay sharp at every window scale:
## m5x7 for text, m3x6 for small labels (Daniel Linssen, free) and Toasty for headings
## (Dogobongocat). Built in code so every panel, the HUD and the menus share one Theme.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const PIXEL_BOX := preload("res://scripts/ui/pixel_box.gd")

const INK := Color("14233a")
const PANEL := Color("405273")
const NAVY_DARK := Color("1c2a42")
const PAPER := Color("bcad9f")
const GOLD := Color("e9b85c")
const GOLD_DARK := Color("8a6a3a")
const GOLD_LIGHT := Color("fdd179")
const CYAN := Color("71e4d4")
const CYAN_DARK := Color("2b6f69")
const TEXT := Color("ffe9c4")
const TEXT_DIM := Color("9aa6bd")
const HP := Color("c4593f")
const MAGICULES := Color("4f86c6")
const XP := Color("fdd179")
## Material icons in the bag (by item ID); camp resources by resource name.
const ICONS := {
    "gnasher_essence": "res://assets/game/ui/icons/essence.png",
    "thornback_quill": "res://assets/game/ui/icons/quill.png",
    "wood": "res://assets/game/ui/icons/wood.png",
    "stone": "res://assets/game/ui/icons/stone.png",
    "essence": "res://assets/game/ui/icons/essence.png",
}
## Pieces of the pixel UI (assets/game/ui/pixel/) and their corner sizes.
const PIECES := {
    "panel": ["panel_navy", 5],
    "flat": ["panel_navy_flat", 4],
    "paper": ["panel_paper", 5],
    "plate": ["plate_navy", 4],
    "plate_paper": ["plate_paper", 4],
    "slot": ["slot", 4],
    "slot_grey": ["slot_grey", 4],
    "slot_light": ["slot_light", 4],
    "bar_back": ["bar_thin_navy", 3],
    "bar_red": ["bar_red", 6],
    "bar_red_empty": ["bar_red_empty", 6],
    "bar_blue": ["bar_blue", 6],
    "bar_magic": ["bar_magic", 6],
    "bar_blue_empty": ["bar_blue_empty", 6],
    "bar_gold": ["bar_thin_gold", 3],
}
## The status card's bars: [track, fill] pieces.
const BARS := {"hp": ["bar_red_empty", "bar_red"], "magicules": ["bar_red_empty", "bar_magic"], "xp": ["bar_back", "bar_gold"]}
const FONTS := {
    "body": "res://assets/game/fonts/m5x7.ttf",
    "small": "res://assets/game/fonts/m3x6.ttf",
    "head": "res://assets/game/fonts/toasty.ttf",
}
## The size each font is drawn at (whole pixels at any integer window scale).
const FONT_SIZES := {"body": 16, "small": 16, "head": 14}
## Requested sizes below this use the small font. Text drawn by hand (`draw_string`) asks for at
## least 8: the fixed-size fonts round their scale, so smaller sizes would vanish.
const SMALL_BELOW := 10

static var _theme: Theme
static var _fonts := {}

static func font(kind: String = "body") -> Font:
    if not _fonts.has(kind):
        var file := FontFile.new()
        file.load_dynamic_font(FONTS[kind])
        file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
        file.hinting = TextServer.HINTING_NONE
        file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
        file.fixed_size = FONT_SIZES[kind]
        file.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
        _fonts[kind] = file
    return _fonts[kind]

## A pixel nine-patch: "panel", "flat", "paper", "plate", "plate_paper", "slot", "slot_grey",
## "slot_light", "bar_back". `alpha` makes it see-through; `content` is the inner margin.
static func piece(kind: String, content: float = 6.0, alpha: float = 1.0, tint: Color = Color.WHITE) -> StyleBox:
    var style := PIXEL_BOX.new()
    style.texture = load("res://assets/game/ui/pixel/%s.png" % PIECES[kind][0])
    style.margin = int(PIECES[kind][1])
    style.tint = Color(tint, tint.a * alpha)
    style.set_content_margin_all(content)
    return style

## A window frame: "panel" (windows, menus), "hud" (see-through HUD blocks), "assistant"
## (teal analysis box), "banner" (titles), "card" (item cards; pass the rarity colour).
static func ornate(kind: String = "panel", color: Color = GOLD) -> StyleBox:
    match kind:
        "hud":
            return piece("panel", 6.0, 0.86)
        "assistant":
            return piece("panel", 6.0, 0.92, Color(0.72, 0.98, 0.95))
        "banner":
            return piece("plate", 6.0)
        "card":
            var card: StyleBox = piece("panel", 6.0, 0.97)
            card.accent = color
            return card
    return piece("panel", 10.0, 0.95)

## Boxes: a navy frame ("frame"), the teal analysis box ("assistant"), an item cell ("slot",
## "slot_hover", "slot_pressed", "slot_disabled"), keyboard focus ("focus"), a darker inner well
## ("well"), a selected row ("selected") or a bar's track ("bar_back").
static func box(kind: String = "frame") -> StyleBox:
    match kind:
        "assistant":
            return ornate("assistant")
        "slot":
            return piece("slot", 4.0)
        "slot_hover":
            return piece("slot", 4.0, 1.0, Color(1.3, 1.3, 1.45))
        "slot_pressed":
            return piece("slot_grey", 4.0)
        "slot_disabled":
            return piece("slot", 4.0, 0.55)
        "focus":
            var focus := StyleBoxFlat.new()
            focus.draw_center = false
            focus.border_color = CYAN
            focus.set_border_width_all(1)
            return focus
        "well":
            return piece("flat", 4.0, 0.95, Color(0.62, 0.66, 0.78))
        "selected":
            var selected := StyleBoxFlat.new()
            selected.bg_color = Color(0.55, 0.42, 0.18, 0.9)
            selected.border_color = GOLD_LIGHT
            selected.set_border_width_all(1)
            selected.set_content_margin_all(4)
            return selected
        "bar_back":
            return piece("bar_back", 0.0)
    return piece("panel", 4.0, 0.95)

## A button in the given state: a navy plate that lights up on hover and darkens when pressed.
static func button_box(state: String) -> StyleBox:
    var style: StyleBox
    match state:
        "hover":
            style = piece("plate", 0.0, 1.0, Color(1.3, 1.25, 1.1))
        "pressed":
            style = piece("plate", 0.0, 1.0, Color(0.7, 0.7, 0.8))
        "disabled":
            style = piece("plate", 0.0, 0.55)
        "focus":
            return box("focus")
        _:
            style = piece("plate", 0.0)
    style.content_margin_left = 5
    style.content_margin_right = 5
    style.content_margin_top = 0
    style.content_margin_bottom = 1
    return style

static func fill(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = color.lightened(0.35)
    style.border_width_top = 1
    return style

## HUD blocks: a see-through navy panel.
static func hud_box(kind: String = "frame") -> StyleBox:
    return ornate("assistant") if kind == "assistant" else ornate("hud")

## Hotbar cells: the gold-cornered slot.
static func round_slot(kind: String) -> StyleBox:
    return box(kind)

## The shared Theme (built once).
static func theme() -> Theme:
    if _theme != null:
        return _theme
    var built := Theme.new()
    built.default_font = font("body")
    built.default_font_size = FONT_SIZES.body
    built.set_stylebox("panel", "Panel", ornate())
    built.set_stylebox("panel", "PanelContainer", ornate())
    built.set_color("font_color", "Label", TEXT)
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        built.set_stylebox(state, "Button", button_box(state))
    built.set_color("font_color", "Button", TEXT)
    built.set_color("font_hover_color", "Button", GOLD_LIGHT)
    built.set_color("font_pressed_color", "Button", GOLD_LIGHT)
    built.set_color("font_focus_color", "Button", TEXT)
    built.set_color("font_disabled_color", "Button", TEXT_DIM)
    built.set_stylebox("panel", "ItemList", box("well"))
    built.set_stylebox("focus", "ItemList", box("focus"))
    built.set_stylebox("selected", "ItemList", box("selected"))
    built.set_stylebox("selected_focus", "ItemList", box("selected"))
    built.set_stylebox("hovered", "ItemList", box("slot_hover"))
    built.set_color("font_color", "ItemList", TEXT)
    built.set_color("font_selected_color", "ItemList", GOLD_LIGHT)
    built.set_constant("icon_margin", "ItemList", 4)
    built.set_constant("v_separation", "ItemList", 3)
    built.set_stylebox("background", "ProgressBar", box("bar_back"))
    built.set_stylebox("fill", "ProgressBar", fill(MAGICULES))
    built.set_stylebox("panel", "TooltipPanel", ornate("hud"))
    built.set_color("font_color", "TooltipLabel", TEXT)
    built.set_stylebox("normal", "LineEdit", box("well"))
    built.set_stylebox("focus", "LineEdit", box("focus"))
    built.set_stylebox("panel", "PopupMenu", ornate("hud"))
    built.set_color("default_color", "RichTextLabel", TEXT)
    _theme = built
    return built

static var installed := false

## Give every interface the shared look (idempotent). The HUD lives under a CanvasLayer, which a
## Window/Control theme does not reach, so the look is merged into the engine's default theme.
## Text drawn by hand (map labels, names over heads) uses the small pixel font.
static func install(tree: SceneTree = null) -> void:
    if installed:
        return
    ThemeDB.get_default_theme().merge_with(theme())
    ThemeDB.fallback_font = font("small")
    var main_loop: MainLoop = tree if tree != null else Engine.get_main_loop()
    if main_loop is SceneTree:
        (main_loop as SceneTree).node_added.connect(_on_node_added)
    installed = true

## Controls asked for a small size (below 10) get the small pixel font.
static func _on_node_added(node: Node) -> void:
    if node is Control:
        _small_font.call_deferred(node)

static func _small_font(node: Control) -> void:
    if not is_instance_valid(node) or node.has_theme_font_override("font") or node.has_theme_font_override("normal_font"):
        return
    var key := "normal_font_size" if node is RichTextLabel else "font_size"
    if node.has_theme_font_size_override(key) and node.get_theme_font_size(key) < SMALL_BELOW:
        node.add_theme_font_override("normal_font" if node is RichTextLabel else "font", font("small"))
        # The fixed-size fonts round their scale: below 8 they would vanish.
        node.add_theme_font_size_override(key, FONT_SIZES.small)

## A slim bar in the given colour (HP red, Magicules blue, XP gold).
static func style_bar(bar: ProgressBar, color: Color) -> void:
    bar.add_theme_stylebox_override("background", box("bar_back"))
    bar.add_theme_stylebox_override("fill", fill(color))
    bar.show_percentage = false
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

## A status-card bar drawn with the pack's bar pieces: "hp", "magicules" or "xp".
static func pixel_bar(bar: ProgressBar, kind: String) -> void:
    bar.add_theme_stylebox_override("background", piece(BARS[kind][0], 0.0))
    bar.add_theme_stylebox_override("fill", piece(BARS[kind][1], 0.0))
    bar.show_percentage = false
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

## A skill's icon (M12c: the class skills; others have none yet).
static func skill_icon(id: String) -> Texture2D:
    var path := "res://assets/game/ui/skills/%s.png" % id
    return load(path) if ResourceLoader.exists(path) else null

static func icon(id: String) -> Texture2D:
    return load(ICONS[id]) if ICONS.has(id) else null

## The prepared gear icon for an item instance: one per base and rarity (step 18).
static func gear_icon(item: Dictionary) -> Texture2D:
    if item.is_empty():
        return null
    return preload("res://scripts/items/gear_catalogue.gd").icon_texture(item.base, int(item.rarity))

## A menu entry (title and pause menus): heading font in gold, a lit plate when focused or hovered.
static func menu_entry(button: Button) -> void:
    button.add_theme_font_override("font", font("head"))
    button.add_theme_color_override("font_color", GOLD_LIGHT)
    button.add_theme_color_override("font_focus_color", Color.WHITE)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.56))
    var empty := StyleBoxEmpty.new()
    button.add_theme_stylebox_override("normal", empty)
    button.add_theme_stylebox_override("disabled", empty)
    for state in ["hover", "focus", "pressed"]:
        button.add_theme_stylebox_override(state, piece("plate", 0.0, 1.0, Color(1.25, 1.2, 1.05)))

## Section title: the heading font in gold.
static func heading(label: Label) -> Label:
    label.add_theme_font_override("font", font("head"))
    label.add_theme_color_override("font_color", GOLD_LIGHT)
    return label

## A map marker (user request: an arrow that shows where a character faces, like a mouse pointer
## but modern): a notched navigation arrow with a dark outline, a two-tone body and, for yourself,
## a soft pulsing ring. `facing` is the character's facing direction.
static func draw_arrow(canvas: CanvasItem, at: Vector2, facing: Vector2, size: float, colour: Color, ring: bool = false) -> void:
    var direction: Vector2 = facing.normalized() if facing.length() > 0.1 else Vector2.UP
    var side: Vector2 = direction.orthogonal()
    var tip: Vector2 = at + direction * size
    var left: Vector2 = at - direction * size * 0.75 + side * size * 0.7
    var right: Vector2 = at - direction * size * 0.75 - side * size * 0.7
    var notch: Vector2 = at - direction * size * 0.3
    if ring:
        var pulse: float = fmod(Time.get_ticks_msec() / 1000.0, 1.4) / 1.4
        canvas.draw_arc(at, size * (1.1 + pulse * 0.9), 0.0, TAU, 24, Color(colour, 0.55 * (1.0 - pulse)), 1.0, true)
    # Outline: the same shape, a pixel larger.
    var grow: float = 1.2
    var outline := PackedVector2Array([at + (tip - at) * grow + direction * 0.6, at + (left - at) * grow, notch - direction * 0.8, at + (right - at) * grow])
    canvas.draw_colored_polygon(outline, Color(0.02, 0.03, 0.06, 0.95))
    # Two-tone body: the lit half and the shaded half.
    canvas.draw_colored_polygon(PackedVector2Array([tip, left, notch]), colour.lightened(0.25))
    canvas.draw_colored_polygon(PackedVector2Array([tip, notch, right]), colour.darkened(0.2))
    canvas.draw_line(tip, notch, Color(1, 1, 1, 0.55), 1.0, true)

