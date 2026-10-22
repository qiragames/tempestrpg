extends Control
## World map (M4.5a, key M or the pause menu): the whole world drawn from WorldMap (one pixel per
## tile, shown scaled), region names (regions reached by ferry are faded), towns and villages,
## ferry piers, your position (blinking) and the other characters. Opens like the other windows:
## solo play pauses, online only this character stops.
const MAP := preload("res://scripts/world/world_map.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const FRAME := Rect2(20, 12, 600, 336)
const IMAGE_AT := Vector2(32, 42)
## SVE feedback: the map stays inside the frame (it used to run past the right edge); the view is
## fitted into this area.
const CANVAS_SIZE := Vector2(576, 282)
## Fitted scale for the normal view (kept for callers that size things by it).
const SCALE := 0.3
## Map colours by terrain.
const COLORS := {
    "ocean": Color("2f6fa8"), "shore": Color("6fc3dc"), "lake": Color("5fb8d8"), "lava": Color("e0642a"),
    "path": Color("b8784f"), "bridge": Color("d79a55"),
    0: Color("f2cf8f"), 1: Color("a7bb3c"), 2: Color("5f9a3a"), 3: Color("f0a35a"), 4: Color("7a7072"),
    5: Color("eef2f8"), 6: Color("f4b6c8"), 7: Color("6d6a3e"), "cliff": Color("4a4440"),
    8: Color("6e4a8c"), 9: Color("d8b85c"), 10: Color("3fae7e"), 11: Color("5a5664"),
}
## Label anchors (tiles) per region.
const LABELS := {
    MAP.Region.CLEARING: Vector2(190, 116), MAP.Region.THORNWOOD: Vector2(104, 84), MAP.Region.MIRROR_LAKE: Vector2(246, 56),
    MAP.Region.CINDER_CRATER: Vector2(256, 180), MAP.Region.HARROWMERE: Vector2(346, 64), MAP.Region.AMBERVALE: Vector2(180, 270),
    MAP.Region.EMBERREACH: Vector2(560, 268), MAP.Region.SEA: Vector2(330, 160),
    MAP.Region.FROSTPEAK: Vector2(190, -200), MAP.Region.SUNSCORCH: Vector2(-150, 30), MAP.Region.SAKURA_VALE: Vector2(560, -120),
    MAP.Region.MIREWOOD: Vector2(-170, 300), MAP.Region.VERDANT: Vector2(110, 196),
    MAP.Region.STORMREACH: Vector2(1000, -185), MAP.Region.DUSKFEN: Vector2(1020, 205), MAP.Region.SKYREACH: Vector2(1340, -210),
}
## Inside the Ki Realm (M4.7) only the realm is shown, with its own places named.
const REALM_LABELS := [
    ["Raptor Gulch", Vector2(-1140, -40)], ["Wasteland Canyon", Vector2(-720, 140)], ["Android Works", Vector2(-620, -90)],
    ["Sage Spire", Vector2(-760, -185)], ["Glacier Ridge", Vector2(-1000, -230)], ["Turtle Coast", Vector2(-1190, 330)],
    ["Emerald Isles", Vector2(-580, 260)],
]
static var _world_texture: ImageTexture
static var _realm_texture: ImageTexture

var hud: CanvasLayer
var _title: Label
## The shown part of the grid (tiles) and its scale and offset on the canvas.
var _view := Rect2(MAP.WORLD_VIEW)
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
            elif ocean > 0 and preload("res://scripts/dungeons/dungeon_catalogue.gd").in_strip(Vector2i(x, y)):
                # M7c: the Underdeep's chasms are dark rock.
                color = Color("1c1a22")
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

## --- Detail (user feedback: the map looked like a sketch): trees, rocks and buildings are
## marked on the picture; zoomed in, the real pixel-art props are drawn at small size.
const TERRAIN := preload("res://scripts/world/world_terrain.gd")
static var _detail: Image
static var _full_texture: ImageTexture
static var _sheets: Dictionary = {}

## The colour a prop leaves on the map ([colour, size in pixels]; size 0 = not drawn).
static func prop_mark(id: String) -> Array:
    if id.begins_with("pine") or id.begins_with("tree_snow"):
        return [Color("2e5a34") if not id.contains("snow") else Color("d8e2ea"), 1]
    if id in ["tree_big", "tree_round"]:
        return [Color("3c7430"), 1]
    if id == "tree_autumn":
        return [Color("b8642a"), 1]
    if id == "tree_dead":
        return [Color("6e5a44"), 1]
    if id in ["tree_pink", "tree_blossom"]:
        return [Color("e48aa8"), 1]
    if id in ["bamboo", "palm"]:
        return [Color("4f8a30"), 1]
    if id.begins_with("boulder"):
        return [Color("8a8a92") if not id.contains("snow") else Color("c8d0d8"), 1]
    if id.begins_with("ruin"):
        return [Color("8a7f72"), 2]
    if id in ["torii"]:
        return [Color("c0392b"), 1]
    if id in ["well", "stall"]:
        return [Color("8a6a4a"), 1]
    if id == "wall":
        return [Color("8a8478"), 1]
    if id in ["bush", "pebbles", "ferry_boat"]:
        return [Color(), 0]
    return [Color("a0522d"), 2]

## The map picture with every planned prop marked (built once the world planned its props).
static func detail_image() -> Image:
    if _detail != null:
        return _detail
    var picture := image()
    for prop in TERRAIN.planned_props():
        var mark := prop_mark(String(prop[0]))
        if int(mark[1]) == 0:
            continue
        var tile := Vector2i(((Vector2(prop[1]) - MAP.ORIGIN) / MAP.TILE).floor()) - MAP.MIN
        for dy in range(int(mark[1])):
            for dx in range(int(mark[1])):
                var at := tile + Vector2i(dx, -dy)
                if at.x >= 0 and at.y >= 0 and at.x < picture.get_width() and at.y < picture.get_height():
                    picture.set_pixelv(at, mark[0])
    if not TERRAIN.planned_props().is_empty():
        _detail = picture
    return picture

## The detailed map including the realm (the minimap's picture).
static func full_texture() -> ImageTexture:
    if _full_texture == null or _detail == null:
        _full_texture = ImageTexture.create_from_image(detail_image())
    return _full_texture

static func sheet(path: String) -> Texture2D:
    if not _sheets.has(path):
        _sheets[path] = load(path)
    return _sheets[path]

## The world's map without the hidden Ki Realm (painted over as open sea).
static func world_texture() -> ImageTexture:
    if _world_texture == null or _detail == null:
        var view := MAP.WORLD_VIEW
        var picture := detail_image().get_region(Rect2i(view.position - MAP.MIN, view.size))
        _world_texture = ImageTexture.create_from_image(picture)
    return _world_texture

## Only the Ki Realm.
static func realm_texture() -> ImageTexture:
    if _realm_texture == null or _detail == null:
        var rect := MAP.REALM_RECT
        _realm_texture = ImageTexture.create_from_image(detail_image().get_region(Rect2i(rect.position - MAP.MIN, rect.size)))
    return _realm_texture

func _in_realm() -> bool:
    return is_instance_valid(hud.player) and MAP.in_realm(hud.player.global_position)

## M7c: the dungeon this character is in ("" outside).
func _dungeon() -> String:
    return MAP.dungeon_at(hud.player.global_position) if is_instance_valid(hud.player) else ""

## What the map shows: the archipelago and the Reaches, the Ki Realm, or one dungeon.
func _zone_rect() -> Rect2i:
    var dungeon := _dungeon()
    if not dungeon.is_empty():
        return DUNGEONS.view(dungeon)
    return MAP.REALM_RECT if _in_realm() else MAP.WORLD_VIEW

const DUNGEONS := preload("res://scripts/dungeons/dungeon_catalogue.gd")
static var _dungeon_textures: Dictionary = {}

static func dungeon_texture(id: String) -> ImageTexture:
    if not _dungeon_textures.has(id) or _detail == null:
        var rect: Rect2i = DUNGEONS.view(id)
        _dungeon_textures[id] = ImageTexture.create_from_image(detail_image().get_region(Rect2i(rect.position - MAP.MIN, rect.size)))
    return _dungeon_textures[id]

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
    _canvas.size = CANVAS_SIZE
    _canvas.mouse_filter = Control.MOUSE_FILTER_STOP
    _canvas.clip_contents = true
    _canvas.draw.connect(_draw_map)
    _canvas.gui_input.connect(_map_input)
    add_child(_canvas)
    hud._label("Mouse wheel: zoom · drag: move · faded names: by ferry · squares: towns · gold X: your items · violet: leveling spots · M / Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(560, 14), self, 9).add_theme_color_override("font_color", UI.TEXT_DIM)
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
## Zoom (mouse wheel, 1x–10x of the fitted map) and the tile in the middle of the canvas.
const MAX_ZOOM := 10.0
var zoom := 1.0
var _fit := 1.0
var _centre := Vector2.ZERO
var _dragging := false

func _choose_view() -> void:
    _view = Rect2(_zone_rect())
    _fit = minf(_canvas.size.x / _view.size.x, _canvas.size.y / _view.size.y)
    zoom = 1.0
    _centre = _view.get_center()
    _apply_zoom()
    _title.text = ("WORLD MAP · " + DUNGEONS.DUNGEONS[_dungeon()][0].to_upper()) if not _dungeon().is_empty() else ("WORLD MAP · THE KI REALM" if _in_realm() else "WORLD MAP · THE ARCHIPELAGO")

func _apply_zoom() -> void:
    _scale = _fit * zoom
    # Keep the view inside the map (centred when the map is smaller than the canvas).
    var half := _canvas.size / (2.0 * _scale)
    var lo := _view.position + half
    var hi := _view.end - half
    _centre = Vector2(_view.get_center().x if lo.x > hi.x else clampf(_centre.x, lo.x, hi.x), _view.get_center().y if lo.y > hi.y else clampf(_centre.y, lo.y, hi.y))
    _offset = (_canvas.size / 2.0 - (_centre - _view.position) * _scale).round()

## Zoom toward a canvas point (the tile under it stays put).
func zoom_at(point: Vector2, factor: float) -> void:
    var tile := _view.position + (point - _offset) / _scale
    zoom = clampf(zoom * factor, 1.0, MAX_ZOOM)
    _scale = _fit * zoom
    _centre = tile - (point - _canvas.size / 2.0) / _scale
    _apply_zoom()

## User request: teleport scrolls. The map opens in teleport mode: cities you carry a scroll for
## glow; clicking one starts the teleport.
var teleport_mode := false

func open_teleport() -> void:
    open()
    if not visible:
        return
    teleport_mode = true
    _title.text = "TELEPORT · CLICK A GLOWING CITY"

## Cities this character holds a scroll for: [[town id, map point]].
func teleport_targets() -> Array:
    var found: Array = []
    var trade := preload("res://scripts/trade/trade_catalogue.gd")
    for town in MAP.TOWNS:
        if hud.player.get_node("Inventory").count_of(StringName(trade.teleport_id(town[0]))) > 0 and not trade.teleport_merchant(town[0]).is_empty():
            found.append([town[0], tile_to_map(town[3]).round()])
    return found

func teleport_at(point: Vector2) -> String:
    for target in teleport_targets():
        if point.distance_to(target[1]) <= 12.0:
            return target[0]
    return ""

func choose_teleport(town: String) -> void:
    hud.session.request_action("teleport", {"to": town})
    if hud.session.active:
        # The caster's own screen shows the cast at once.
        hud.player.teleport_left = preload("res://scripts/trade/trade_catalogue.gd").TELEPORT_SECONDS
    close()

func _map_input(event: InputEvent) -> void:
    if teleport_mode and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var town := teleport_at(event.position)
        if not town.is_empty():
            choose_teleport(town)
            _canvas.accept_event()
            return
    if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
        zoom_at(event.position, 1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8)
        _canvas.accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        _dragging = event.pressed
    elif event is InputEventMouseMotion and _dragging:
        _centre -= event.relative / _scale
        _apply_zoom()

## Zoomed in, the real props are drawn small (only those in view).
func _draw_props() -> void:
    if _scale < 2.5:
        return
    var lo := _view.position + (-_offset) / _scale - Vector2(3, 3)
    var hi := _view.position + (_canvas.size - _offset) / _scale + Vector2(3, 6)
    var size := _scale / MAP.TILE
    for prop in TERRAIN.planned_props():
        var foot: Vector2 = prop[1]
        var tile := (foot - MAP.ORIGIN) / MAP.TILE
        if tile.x < lo.x or tile.y < lo.y or tile.x > hi.x or tile.y > hi.y or not _shown(tile):
            continue
        var spec: Array = TERRAIN.PROPS.get(String(prop[0]), [])
        if spec.is_empty():
            continue
        var region: Rect2 = spec[1]
        var at := tile_to_map(tile)
        _canvas.draw_texture_rect_region(sheet(spec[0]), Rect2(at - Vector2(region.size.x / 2.0, region.size.y) * size, region.size * size), region)
    # The clearing's own seeded trees and rocks.
    var art := preload("res://scripts/visual/world_art.gd")
    for entry in [["tree", hud.get_parent().layout.get("trees", [])], ["rock", hud.get_parent().layout.get("rocks", [])]]:
        var spec: Array = art.PROPS[entry[0]]
        var region: Rect2 = spec[1]
        for spot in entry[1]:
            var at := to_map(spot.get_center() + Vector2(0, spot.size.y / 2.0) if spot is Rect2 else spot)
            if at.x > -20 and at.y > -20 and at.x < _canvas.size.x + 20 and at.y < _canvas.size.y + 20:
                _canvas.draw_texture_rect_region(spec[0], Rect2(at - Vector2(region.size.x / 2.0, region.size.y * 0.75) * size, region.size * size), region)

## SVE feedback: map labels in the crisp pixel fonts with a thin outline, each placed at the first
## of its candidate spots that overlaps no label already drawn (else left out at this zoom).
const LABEL_INK := Color(0.03, 0.04, 0.06)
const LABEL_PLATE := Color(0.04, 0.05, 0.09, 0.78)
const PLATE_MARGIN := 2.0
var _placed: Array = []
var _reserved: Array = []

## Candidate placements around a point: "centre", "below", "right", "left", "above".
func _place_label(anchor: Vector2, text: String, color: Color, sides: Array, kind: String = "body", force: bool = false) -> bool:
    var font: Font = UI.font(kind)
    var size: int = UI.FONT_SIZES[kind]
    var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
    var height: float = font.get_ascent(size) - 2.0
    var bounds := Rect2(Vector2.ZERO, _canvas.size).grow(-2.0)
    for side in sides:
        var top_left: Vector2
        match side:
            "centre":
                top_left = anchor - Vector2(extent.x / 2.0, height / 2.0)
            "below":
                top_left = anchor + Vector2(-extent.x / 2.0, 5)
            "above":
                top_left = anchor + Vector2(-extent.x / 2.0, -height - 6)
            "right":
                top_left = anchor + Vector2(6, -height / 2.0)
            "left":
                top_left = anchor + Vector2(-extent.x - 6, -height / 2.0)
        top_left = top_left.round()
        var rect := Rect2(top_left, Vector2(extent.x, height)).grow(PLATE_MARGIN)
        if not force and (not bounds.encloses(rect) or _placed.any(func(other): return other.intersects(rect)) or _reserved.any(func(other): return other.intersects(rect))):
            continue
        _placed.append(rect)
        # User request (map font readable): every label on a small dark plate, so it reads on snow,
        # sand and sea alike; the text itself stays crisp (no thick outline).
        var plate := rect.grow_individual(1.0, 0.0, 1.0, 1.0)
        _canvas.draw_rect(plate, LABEL_PLATE)
        _canvas.draw_rect(plate, Color(color, 0.35), false, 1.0)
        var baseline := top_left + Vector2(0, font.get_ascent(size) - 1.0)
        _canvas.draw_string(font, baseline + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, LABEL_INK)
        _canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
        return true
    return false

func _shown(tile: Vector2) -> bool:
    return _zone_rect().has_point(Vector2i(tile.floor()))

func _draw_map() -> void:
    var dungeon := _dungeon()
    var realm := _in_realm() or not dungeon.is_empty()
    _canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), COLORS.ocean if dungeon.is_empty() else Color("1c1a22"))
    _canvas.draw_texture_rect(dungeon_texture(dungeon) if not dungeon.is_empty() else (realm_texture() if realm else world_texture()), Rect2(_offset, _view.size * _scale), false)
    _draw_props()
    _canvas.draw_rect(Rect2(Vector2(-1, -1), _canvas.size + Vector2(2, 2)), UI.GOLD_DARK, false, 1.0)
    _placed.clear()
    # Labels keep clear of your arrow and the town squares.
    _reserved = [Rect2(to_map(hud.player.global_position).round() - Vector2(8, 8), Vector2(16, 16))]
    for town in MAP.TOWNS:
        if _shown(town[3]):
            _reserved.append(Rect2(tile_to_map(town[3]).round() - Vector2(3, 3), Vector2(6, 6)))
    if not realm:
        for ferry in MAP.HARBOURS:
            _reserved.append(Rect2(tile_to_map(ferry[2]).round() - Vector2(4, 4), Vector2(8, 8)))
    if not dungeon.is_empty():
        var spec: Array = DUNGEONS.DUNGEONS[dungeon]
        var title := "%s · Lv %d–%d · %s in the deepest chamber" % [spec[0], spec[3][0], spec[3][1], spec[5]]
        _place_label(Vector2(8, 4), title, Color("ffcf7a"), ["right"], "body", true)
    elif realm:
        var realm_levels: String = "The Ki Realm · " + preload("res://scripts/world/region_content.gd").range_text("The Ki Realm")
        _place_label(Vector2(2, 8), realm_levels, Color("ffcf7a"), ["right"], "body", true)
        for entry in REALM_LABELS:
            _place_label(tile_to_map(entry[1]), entry[0], UI.TEXT, ["centre", "below", "above"], "body")
    # Region names first (they matter most), each with its level range under it.
    for region in ([] if realm else LABELS.keys()):
        var name: String = MAP.REGION_NAMES[region]
        var at: Vector2 = tile_to_map(LABELS[region])
        var reachable: bool = region in MAP.REACHABLE or region == MAP.Region.SEA
        if not _place_label(at, name.to_upper(), UI.GOLD_LIGHT if reachable else Color(UI.TEXT, 0.7), ["centre", "below", "above"], "body"):
            continue
        # M7 (user request): what level the region is for.
        var levels: String = preload("res://scripts/world/region_content.gd").range_text(name)
        if not levels.is_empty():
            _place_label(at + Vector2(0, 4), levels, Color("ffcf7a"), ["below"])
    # Towns (larger, named) and villages; ferry piers.
    for town in MAP.TOWNS:
        if not _shown(town[3]):
            continue
        var spot := tile_to_map(town[3]).round()
        var big: bool = town[4] == "town"
        _canvas.draw_rect(Rect2(spot - Vector2(2, 2) if big else spot - Vector2(1, 1), Vector2(5, 5) if big else Vector2(3, 3)), Color(0.03, 0.04, 0.06))
        _canvas.draw_rect(Rect2(spot - Vector2(1, 1) if big else spot - Vector2(0.5, 0.5), Vector2(3, 3) if big else Vector2(2, 2)), UI.GOLD_LIGHT if big else UI.TEXT)
        if big:
            _place_label(spot, town[1], UI.TEXT, ["right", "left", "below", "above"])
    # M5d: the rival nations at their capitals.
    if not realm:
        for entry in preload("res://scripts/nation/rival_nations.gd").RIVALS:
            var capital := tile_to_map(MAP.town(entry[3])[3]).round()
            _canvas.draw_rect(Rect2(capital + Vector2(-8, -12), Vector2(1, 9)), Color("6b4a2b"))
            _canvas.draw_rect(Rect2(capital + Vector2(-7, -12), Vector2(6, 4)), entry[4])
            _place_label(capital + Vector2(-4, -8), entry[1], entry[4].lightened(0.35), ["above", "left", "right"])
    # M5a: your nation's name and banner at the camp.
    var camp: Node2D = hud.get_parent().get("camp")
    if camp != null and camp.state.founded and not realm:
        var at := to_map(camp.SITE).round()
        var nation: Dictionary = camp.state.nation
        var color: Color = camp.NATION.COLORS[int(nation.color)]
        _canvas.draw_rect(Rect2(at + Vector2(-1, -10), Vector2(1, 10)), Color("6b4a2b"))
        _canvas.draw_rect(Rect2(at + Vector2(0, -10), Vector2(7, 5)), color)
        var title: String = nation.name if not String(nation.name).is_empty() else camp.NATION.tier_name(int(nation.tier))
        _place_label(at + Vector2(3, -6), title, color.lightened(0.3), ["right", "above", "left"])
    for ferry in ([] if realm else MAP.HARBOURS):
        var pier := tile_to_map(ferry[2]).round()
        _canvas.draw_arc(pier, 2.5, 0, TAU, 10, Color(0.03, 0.04, 0.06), 2.0)
        _canvas.draw_arc(pier, 2.0, 0, TAU, 10, Color("9fe8ff"), 1.0)
    # M7c: cave mouths (brown arches) and the hidden elites you have found (red rings).
    for cave in DUNGEONS.ORDER:
        if _shown(DUNGEONS.DUNGEONS[cave][2]):
            var mouth := tile_to_map(DUNGEONS.DUNGEONS[cave][2]).round()
            _canvas.draw_arc(mouth, 3.0, PI, TAU, 8, Color("c89a6a"), 2.0)
            _place_label(mouth, DUNGEONS.DUNGEONS[cave][0], Color("e8c89a"), ["right", "left", "below", "above"])
    var bosses := preload("res://scripts/bosses/boss_catalogue.gd")
    for elite in hud.player.progression.get("elites", []):
        if bosses.ELITES.has(elite) and _shown(bosses.ELITES[elite][3]):
            var at_elite := tile_to_map(bosses.ELITES[elite][3]).round()
            _canvas.draw_arc(at_elite, 3.5, 0, TAU, 12, Color("ff5a5a"), 1.5)
            var label: String = "%s (Lv %d)" % [bosses.ELITES[elite][0], bosses.ELITES[elite][5]]
            _place_label(at_elite, label, Color("ffb0a0"), ["right", "left", "below", "above"])
    # Discovered leveling spots (violet rings, named) and your dropped item piles (gold) — 24a.
    var known: Array = hud.player.progression.get("spots", [])
    var region_content := preload("res://scripts/world/region_content.gd")
    for spot in region_content.SPOTS:
        if spot[0] in known and _shown(spot[2]):
            var at := to_map(region_content.at(spot[2])).round()
            _canvas.draw_arc(at, 3.0, 0, TAU, 12, Color("c48bff"), 1.5)
            _place_label(at, region_content.SPOT_NAMES[spot[0]], Color("e0c8ff"), ["right", "left", "below", "above"])
    for node in hud.get_parent().get_children():
        if node.is_in_group("item_piles") and node.owner_id == hud.player.character_id and _shown(Vector2(MAP.to_tile(node.global_position))):
            var pile := to_map(node.global_position).round()
            _canvas.draw_line(pile + Vector2(-3, -3), pile + Vector2(3, 3), Color("f0a34a"), 2.0)
            _canvas.draw_line(pile + Vector2(-3, 3), pile + Vector2(3, -3), Color("f0a34a"), 2.0)
    # Other characters, then you (blinking).
    for child in hud.get_parent().get_children():
        if child is CharacterBody2D and child.has_method("race") and child != hud.player and _shown(Vector2(MAP.to_tile(child.global_position))):
            var party: Node = hud.get_parent().get("party")
            var mate: bool = party != null and party.same_party(hud.player.character_id, child.character_id)
            UI.draw_arrow(_canvas, to_map(child.global_position).round(), child.facing, 5.0 if mate else 4.5, Color("ff8adf") if mate else Color(0.92, 0.94, 1.0))
    if teleport_mode:
        var pulse := 0.5 + 0.5 * sin(_time * 4.0)
        for target in teleport_targets():
            _canvas.draw_arc(target[1], 7.0 + pulse * 2.0, 0, TAU, 20, Color(0.55, 0.9, 1.0, 0.9), 2.0)
    # You: an arrow showing where you face, with a soft pulse.
    UI.draw_arrow(_canvas, to_map(hud.player.global_position).round(), hud.player.facing, 7.0, UI.CYAN, true)

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
    teleport_mode = false
    hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before_open
