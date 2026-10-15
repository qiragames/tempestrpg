extends RefCounted
## Shared interface look (step 21), after the user's HUD reference: dark panels with gold trim,
## cyan for analysis/assistant accents, red/blue/gold bars. Built in code so every panel, the HUD
## and later menus share one Theme. The prepared Ninja Adventure pixel font is not used: its glyphs
## break at the 8-11 px sizes this 640x360 interface needs, so the engine font stays for text.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")

const INK := Color("0f131b")
const PANEL := Color(0.07, 0.09, 0.12, 0.94)
const GOLD := Color("c49a52")
const GOLD_DARK := Color("6b5532")
const GOLD_LIGHT := Color("f0d38c")
const CYAN := Color("71e4d4")
const CYAN_DARK := Color("2b6f69")
const TEXT := Color("ece3cc")
const TEXT_DIM := Color("8f8a7c")
const HP := Color("d4473f")
const MAGICULES := Color("3f8ee0")
const XP := Color("e1bf3c")
## Material icons in the bag (by item ID); camp resources by resource name.
const ICONS := {
    "gnasher_essence": "res://assets/game/ui/icons/essence.png",
    "thornback_quill": "res://assets/game/ui/icons/quill.png",
    "wood": "res://assets/game/ui/icons/wood.png",
    "stone": "res://assets/game/ui/icons/stone.png",
    "essence": "res://assets/game/ui/icons/essence.png",
}

static var _theme: Theme
const ORNATE := preload("res://scripts/ui/ornate_box.gd")
## Ornamented frames (Kenney Fantasy UI Borders, CC0): white, tinted per use. Windows and banners
## use the large 96 px "Double" frames (32 px corners, 2 px lines); HUD blocks, item cards
## and the analysis box the 48 px ones (16 px corners) so they stay slim.
const FRAMES := {
    "panel": "res://assets/game/ui/frames/frame_panel.png",
    "hud": "res://assets/game/ui/frames/frame_hud.png",
    "assistant": "res://assets/game/ui/frames/frame_assistant.png",
    "banner": "res://assets/game/ui/frames/frame_banner.png",
    "card": "res://assets/game/ui/frames/frame_card.png",
}

## An ornamented frame: "panel" (windows, menus), "hud" (HUD blocks), "assistant" (cyan
## analysis), "banner" (titles), "card" (item cards; pass the rarity colour).
static func ornate(kind: String = "panel", color: Color = GOLD) -> StyleBox:
    var style := ORNATE.new()
    style.texture = load(FRAMES[kind])
    style.border_color = CYAN if kind == "assistant" else color
    style.corner = 32 if kind in ["panel", "banner"] else 16
    style.inset = 0.0 if style.corner == 32 else 2.0
    style.outset = 6.0 if style.corner == 32 else 0.0
    style.crest = kind in ["panel", "banner"]
    if kind == "assistant":
        style.bg_color = Color(0.04, 0.10, 0.12, 0.92)
    elif kind == "card":
        style.bg_color = Color(0.08, 0.06, 0.11, 0.97)
    style.set_content_margin_all(10 if style.corner == 32 else (6 if kind == "card" else 8))
    return style

## A framed box: gold trim on a dark fill (kind "frame"), cyan for analysis ("assistant"),
## a hotbar/inventory cell ("slot"), or a flat inner well ("well").
static func box(kind: String = "frame") -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.border_color = GOLD
    style.set_border_width_all(1)
    style.set_content_margin_all(4)
    match kind:
        "assistant":
            style.bg_color = Color(0.04, 0.10, 0.12, 0.92)
            style.border_color = CYAN
        "slot":
            style.bg_color = Color(0.10, 0.12, 0.16, 0.95)
            style.border_color = GOLD_DARK
        "slot_hover":
            style.bg_color = Color(0.14, 0.16, 0.21, 0.98)
            style.border_color = GOLD_LIGHT
        "slot_pressed":
            style.bg_color = Color(0.20, 0.17, 0.10, 0.98)
            style.border_color = GOLD_LIGHT
        "slot_disabled":
            style.bg_color = Color(0.07, 0.08, 0.10, 0.9)
            style.border_color = Color(0.25, 0.23, 0.2)
        "focus":
            style.draw_center = false
            style.border_color = CYAN
        "well":
            style.bg_color = Color(0.03, 0.04, 0.06, 0.9)
            style.border_color = Color(0.2, 0.19, 0.16)
        "selected":
            style.bg_color = Color(0.30, 0.24, 0.12, 0.95)
            style.border_color = GOLD_LIGHT
        "bar_back":
            style.bg_color = Color(0.02, 0.03, 0.05, 0.95)
            style.border_color = GOLD_DARK
            style.set_content_margin_all(0)
    return style

static func fill(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = color.lightened(0.35)
    style.border_width_top = 1
    return style

## HUD blocks (user feedback: keep the dark background, round the corners): a softly rounded
## dark box with a thin trim (gold, or cyan for the analysis box).
static func hud_box(kind: String = "frame") -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.06, 0.07, 0.10, 0.86) if kind != "assistant" else Color(0.04, 0.10, 0.12, 0.88)
    style.border_color = Color(GOLD_DARK, 0.9) if kind != "assistant" else Color(CYAN, 0.8)
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    style.corner_detail = 6
    style.shadow_color = Color(0, 0, 0, 0.35)
    style.shadow_size = 3
    style.set_content_margin_all(6)
    return style

## Rounded hotbar cells in the same spirit.
static func round_slot(kind: String) -> StyleBoxFlat:
    var style := box(kind)
    style.set_corner_radius_all(5)
    style.corner_detail = 5
    return style

## The shared Theme (built once).
static func theme() -> Theme:
    if _theme != null:
        return _theme
    var built := Theme.new()
    built.default_font_size = 11
    built.set_stylebox("panel", "Panel", ornate())
    built.set_stylebox("panel", "PanelContainer", ornate())
    built.set_color("font_color", "Label", TEXT)
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        built.set_stylebox(state, "Button", box({"normal": "slot", "hover": "slot_hover", "pressed": "slot_pressed", "disabled": "slot_disabled", "focus": "focus"}[state]))
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
    built.set_stylebox("panel", "TooltipPanel", box())
    built.set_color("font_color", "TooltipLabel", TEXT)
    built.set_font_size("font_size", "TooltipLabel", 10)
    built.set_stylebox("normal", "LineEdit", box("well"))
    built.set_stylebox("focus", "LineEdit", box("focus"))
    built.set_stylebox("panel", "PopupMenu", box())
    built.set_color("default_color", "RichTextLabel", TEXT)
    _theme = built
    return built

static var installed := false

## Give every interface the shared look (idempotent). The HUD lives under a CanvasLayer, which a
## Window/Control theme does not reach, so the look is merged into the engine's default theme.
static func install(_tree: SceneTree = null) -> void:
    if installed:
        return
    ThemeDB.get_default_theme().merge_with(theme())
    installed = true

## A thin bar in the given colour (HP red, Magicules blue, XP gold).
static func style_bar(bar: ProgressBar, color: Color) -> void:
    bar.add_theme_stylebox_override("background", box("bar_back"))
    bar.add_theme_stylebox_override("fill", fill(color))
    bar.show_percentage = false
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func icon(id: String) -> Texture2D:
    return load(ICONS[id]) if ICONS.has(id) else null

## The prepared gear icon for an item instance: one per base and rarity (step 18).
static func gear_icon(item: Dictionary) -> Texture2D:
    if item.is_empty():
        return null
    return preload("res://scripts/items/gear_catalogue.gd").icon_texture(item.base, int(item.rarity))

## A menu entry in the title/pause reference style: gold capitals, a gold bar when focused or hovered.
static func menu_entry(button: Button) -> void:
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_color_override("font_color", GOLD_LIGHT)
    button.add_theme_color_override("font_focus_color", Color.WHITE)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.38))
    var empty := StyleBoxEmpty.new()
    button.add_theme_stylebox_override("normal", empty)
    button.add_theme_stylebox_override("disabled", empty)
    for state in ["hover", "focus", "pressed"]:
        var bar := box("selected")
        bar.bg_color = Color(0.36, 0.27, 0.12, 0.9)
        button.add_theme_stylebox_override(state, bar)

## Section title in gold.
static func heading(label: Label) -> Label:
    label.add_theme_color_override("font_color", GOLD_LIGHT)
    return label
