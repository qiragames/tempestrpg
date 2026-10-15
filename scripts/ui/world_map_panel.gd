extends Control
## World map (M4.5a, key M or the pause menu): the whole world drawn from WorldMap (one pixel per
## tile, shown scaled), region names (regions reached by ferry are faded), towns and villages,
## ferry piers, your position (blinking) and the other characters. Opens like the other windows:
## solo play pauses, online only this character stops.
const MAP := preload("res://scripts/world/world_map.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const FRAME := Rect2(20, 12, 600, 336)
const IMAGE_AT := Vector2(104, 44)
## Screen pixels per tile (the whole 1200 x 768 grid fits the frame).
const SCALE := 0.36
## Map colours by terrain.
const COLORS := {
    "ocean": Color("2f6fa8"), "shore": Color("6fc3dc"), "lake": Color("5fb8d8"), "lava": Color("e0642a"),
    "path": Color("b8784f"), "bridge": Color("d79a55"),
    0: Color("f2cf8f"), 1: Color("a7bb3c"), 2: Color("5f9a3a"), 3: Color("f0a35a"), 4: Color("7a7072"),
    5: Color("eef2f8"), 6: Color("f4b6c8"), 7: Color("6d6a3e"), "cliff": Color("4a4440"),
}
## Label anchors (tiles) per region.
const LABELS := {
    MAP.Region.CLEARING: Vector2(190, 116), MAP.Region.THORNWOOD: Vector2(104, 84), MAP.Region.MIRROR_LAKE: Vector2(246, 56),
    MAP.Region.CINDER_CRATER: Vector2(256, 180), MAP.Region.HARROWMERE: Vector2(346, 64), MAP.Region.AMBERVALE: Vector2(180, 270),
    MAP.Region.EMBERREACH: Vector2(560, 268), MAP.Region.SEA: Vector2(330, 160),
    MAP.Region.FROSTPEAK: Vector2(190, -200), MAP.Region.SUNSCORCH: Vector2(-150, 30), MAP.Region.SAKURA_VALE: Vector2(560, -120),
    MAP.Region.MIREWOOD: Vector2(-170, 300), MAP.Region.VERDANT: Vector2(110, 196),
}
## Inside the Ki Realm (M4.7) only the realm is shown, with its own places named.
const REALM_LABELS := [
    ["Raptor Gulch", Vector2(-322, -160)], ["Wasteland Canyon", Vector2(-212, -160)], ["Android Works", Vector2(-218, -214)],
    ["Sage Spire", Vector2(-286, -226)], ["Hermit Atoll", Vector2(-374, -152)],
]
static var _world_texture: ImageTexture
static var _realm_texture: ImageTexture

var hud: CanvasLayer
var _title: Label
## The shown part of the grid (tiles) and its scale and offset on the canvas.
var _view := Rect2(Vector2(MAP.MIN), Vector2(MAP.COLS, MAP.ROWS))
var _scale := SCALE
var _offset := Vector2.ZERO
var _close: Button
var _canvas: Control
var _time := 0.0
var _paused_before_open: bool = false

static func image() -> Image:
    var stored: Variant = preload("res://scripts/world/world_cache.gd").load_part("image") if MAP.use_cache else null
    if stored is PackedByteArray:
        var cached := Image.new()
        if cached.load_png_from_buffer(stored) == OK:
            return cached
    var map: Dictionary = MAP.data()
    var picture := Image.create(MAP.COLS, MAP.ROWS, false, Image.FORMAT_RGBA8)
    for y in range(MAP.MIN.y, MAP.MIN.y + MAP.ROWS):
        for x in range(MAP.MIN.x, MAP.MIN.x + MAP.COLS):
            var color: Color
            var ocean: int = MAP.corners(map.ocean, x, y)
            if map.bridge[MAP.tile_index(x, y)] == 1:
                color = COLORS.bridge
            elif ocean == 15:
                color = COLORS.ocean
            elif ocean > 0:
                color = COLORS.shore
            elif MAP.corners(map.lake, x, y) >= 8:
                color = COLORS.lake
            elif MAP.corners(map.lava, x, y) >= 8:
                color = COLORS.lava
            elif map.dirt[MAP.vertex_index(x, y)] == 1:
                color = COLORS.path
            elif MAP.cliff(x, y) != MAP.Cliff.NONE:
                color = COLORS.cliff
            else:
                # Higher ground is drawn a little lighter.
                color = COLORS[int(map.ground[MAP.vertex_index(x, y)])].lightened(0.12 * map.height[MAP.vertex_index(x, y)])
            picture.set_pixel(x - MAP.MIN.x, y - MAP.MIN.y, color)
    return picture

## The world's map without the hidden Ki Realm (painted over as open sea).
static func world_texture() -> ImageTexture:
    if _world_texture == null:
        var picture := image()
        var rect := MAP.REALM_RECT
        picture.fill_rect(Rect2i(rect.position - MAP.MIN, rect.size), COLORS.ocean)
        _world_texture = ImageTexture.create_from_image(picture)
    return _world_texture

## Only the Ki Realm.
static func realm_texture() -> ImageTexture:
    if _realm_texture == null:
        var rect := MAP.REALM_RECT
        _realm_texture = ImageTexture.create_from_image(image().get_region(Rect2i(rect.position - MAP.MIN, rect.size)))
    return _realm_texture

func _in_realm() -> bool:
    return is_instance_valid(hud.player) and MAP.in_realm(hud.player.global_position)

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "WorldMapPanel"
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
    _title = UI.heading(hud._label("WORLD MAP · THE ARCHIPELAGO", FRAME.position + Vector2(14, 10), Vector2(400, 20), self, 14))
    _close = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    _close.pressed.connect(close)
    _canvas = Control.new()
    _canvas.position = IMAGE_AT
    _canvas.size = Vector2(MAP.COLS, MAP.ROWS) * SCALE
    _canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _canvas.draw.connect(_draw_map)
    add_child(_canvas)
    hud._label("Faded names: reached by ferry (anchors) · squares: towns and villages · gold X: your items · violet: leveling spots · M / Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(560, 14), self, 9).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func _process(delta: float) -> void:
    if visible:
        _time += delta
        _canvas.queue_redraw()

## Map pixel for a world position.
func to_map(world: Vector2) -> Vector2:
    return tile_to_map((world - MAP.ORIGIN) / MAP.TILE)

func tile_to_map(tile: Vector2) -> Vector2:
    return _offset + (tile - _view.position) * _scale

## Whole world, or (inside the Ki Realm) only the realm, scaled to fit and centred.
func _choose_view() -> void:
    var realm := _in_realm()
    _view = Rect2(MAP.REALM_RECT) if realm else Rect2(Vector2(MAP.MIN), Vector2(MAP.COLS, MAP.ROWS))
    _scale = minf(_canvas.size.x / _view.size.x, _canvas.size.y / _view.size.y)
    _offset = ((_canvas.size - _view.size * _scale) / 2.0).round()
    _title.text = "WORLD MAP · THE KI REALM" if realm else "WORLD MAP · THE ARCHIPELAGO"

func _shown(tile: Vector2) -> bool:
    return MAP.REALM_RECT.has_point(Vector2i(tile.floor())) == _in_realm()

func _draw_map() -> void:
    var realm := _in_realm()
    _canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), COLORS.ocean)
    _canvas.draw_texture_rect(realm_texture() if realm else world_texture(), Rect2(_offset, _view.size * _scale), false)
    _canvas.draw_rect(Rect2(Vector2(-1, -1), _canvas.size + Vector2(2, 2)), UI.GOLD_DARK, false, 1.0)
    var font: Font = _canvas.get_theme_default_font()
    if realm:
        for entry in REALM_LABELS:
            var size := font.get_string_size(entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
            var at: Vector2 = tile_to_map(entry[1]) - Vector2(size.x / 2.0, 0)
            _canvas.draw_string_outline(font, at.round(), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0.03, 0.04, 0.06))
            _canvas.draw_string(font, at.round(), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.TEXT)
    for region in ([] if realm else LABELS.keys()):
        var name: String = MAP.REGION_NAMES[region]
        var size := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
        var at: Vector2 = tile_to_map(LABELS[region]) - Vector2(size.x / 2.0, 0)
        var reachable: bool = region in MAP.REACHABLE or region == MAP.Region.SEA
        _canvas.draw_string_outline(font, at.round(), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0.03, 0.04, 0.06))
        _canvas.draw_string(font, at.round(), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.TEXT if reachable else Color(UI.TEXT, 0.55))
    # Towns (larger, named) and villages; ferry piers.
    for town in MAP.TOWNS:
        if not _shown(town[3]):
            continue
        var spot := tile_to_map(town[3]).round()
        var big: bool = town[4] == "town"
        _canvas.draw_rect(Rect2(spot - Vector2(2, 2) if big else spot - Vector2(1, 1), Vector2(5, 5) if big else Vector2(3, 3)), Color(0.03, 0.04, 0.06))
        _canvas.draw_rect(Rect2(spot - Vector2(1, 1) if big else spot - Vector2(0.5, 0.5), Vector2(3, 3) if big else Vector2(2, 2)), UI.GOLD_LIGHT if big else UI.TEXT)
        if big:
            _canvas.draw_string_outline(font, spot + Vector2(4, 9), town[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 3, Color(0.03, 0.04, 0.06))
            _canvas.draw_string(font, spot + Vector2(4, 9), town[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UI.GOLD_LIGHT)
    # M5d: the rival nations at their capitals.
    if not realm:
        for entry in preload("res://scripts/nation/rival_nations.gd").RIVALS:
            var capital := tile_to_map(MAP.town(entry[3])[3]).round()
            _canvas.draw_rect(Rect2(capital + Vector2(-8, -12), Vector2(1, 9)), Color("6b4a2b"))
            _canvas.draw_rect(Rect2(capital + Vector2(-7, -12), Vector2(6, 4)), entry[4])
            _canvas.draw_string_outline(font, capital + Vector2(-8, -14), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 3, Color(0.03, 0.04, 0.06))
            _canvas.draw_string(font, capital + Vector2(-8, -14), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, entry[4].lightened(0.35))
    # M5a: your nation's name and banner at the camp.
    var camp: Node2D = hud.get_parent().get("camp")
    if camp != null and camp.state.founded and not realm:
        var at := to_map(camp.SITE).round()
        var nation: Dictionary = camp.state.nation
        var color: Color = camp.NATION.COLORS[int(nation.color)]
        _canvas.draw_rect(Rect2(at + Vector2(-1, -10), Vector2(1, 10)), Color("6b4a2b"))
        _canvas.draw_rect(Rect2(at + Vector2(0, -10), Vector2(7, 5)), color)
        var title: String = nation.name if not String(nation.name).is_empty() else camp.NATION.tier_name(int(nation.tier))
        _canvas.draw_string_outline(font, at + Vector2(9, -4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.03, 0.04, 0.06))
        _canvas.draw_string(font, at + Vector2(9, -4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color.lightened(0.3))
    for ferry in ([] if realm else MAP.HARBOURS):
        var pier := tile_to_map(ferry[2]).round()
        _canvas.draw_arc(pier, 2.5, 0, TAU, 10, Color(0.03, 0.04, 0.06), 2.0)
        _canvas.draw_arc(pier, 2.0, 0, TAU, 10, Color("9fe8ff"), 1.0)
    # Discovered leveling spots (violet rings, named) and your dropped item piles (gold) — 24a.
    var known: Array = hud.player.progression.get("spots", [])
    var region_content := preload("res://scripts/world/region_content.gd")
    for spot in region_content.SPOTS:
        if spot[0] in known and _shown(spot[2]):
            var at := to_map(region_content.at(spot[2])).round()
            _canvas.draw_arc(at, 3.0, 0, TAU, 12, Color("c48bff"), 1.5)
            _canvas.draw_string_outline(font, at + Vector2(5, 3), region_content.SPOT_NAMES[spot[0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.03, 0.04, 0.06))
            _canvas.draw_string(font, at + Vector2(5, 3), region_content.SPOT_NAMES[spot[0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("e0c8ff"))
    for node in hud.get_parent().get_children():
        if node.is_in_group("item_piles") and node.owner_id == hud.player.character_id and MAP.in_realm(node.global_position) == realm:
            var pile := to_map(node.global_position).round()
            _canvas.draw_line(pile + Vector2(-3, -3), pile + Vector2(3, 3), Color("f0a34a"), 2.0)
            _canvas.draw_line(pile + Vector2(-3, 3), pile + Vector2(3, -3), Color("f0a34a"), 2.0)
    # Other characters, then you (blinking).
    for child in hud.get_parent().get_children():
        if child is CharacterBody2D and child.has_method("race") and child != hud.player and MAP.in_realm(child.global_position) == realm:
            var party: Node = hud.get_parent().get("party")
            var mate: bool = party != null and party.same_party(hud.player.character_id, child.character_id)
            _canvas.draw_rect(Rect2(to_map(child.global_position).round() - Vector2(1.5, 1.5) if mate else to_map(child.global_position).round() - Vector2(1, 1), Vector2(4, 4) if mate else Vector2(3, 3)), Color("ff8adf") if mate else Color.WHITE)
    var me := to_map(hud.player.global_position).round()
    if fmod(_time, 0.8) < 0.55:
        _canvas.draw_circle(me, 3.5, Color(0.03, 0.04, 0.06))
        _canvas.draw_circle(me, 2.5, UI.CYAN)

func open() -> void:
    if hud.menu_open():
        return
    _paused_before_open = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    _time = 0.0
    _choose_view()
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
