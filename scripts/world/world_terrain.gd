extends Node2D
## Draws and collides the world (M4.5a, grown in M4.5c) from WorldMap: ground TileMapLayers
## (dual-grid corner tiles for coasts, lake shores, lava and paths; rounded patches for every
## ground; plateau rims and rock walls for verticality), a bridge layer, merged collision
## rectangles for water, lava and cliffs, and y-sorted props (trees, boulders, ruins, the towns'
## and villages' buildings, ferry boats) with trunk/footprint collisions. Props are spawned in
## chunks around the characters (the whole world holds thousands). Presentation and static
## collisions only: the same on host and clients, nothing saved. Layer data, the prop list and
## the collisions come from WorldCache when it is current.
const MAP := preload("res://scripts/world/world_map.gd")
const CACHE := preload("res://scripts/world/world_cache.gd")
const TILE := 16
## The 16 corner combinations (top-left 8, top-right 4, bottom-left 2, bottom-right 1; bit =
## water/lava/dirt) in the Ninja Adventure layout shared by the water, lava and dirt sets
## (pond 3x3 at 0..2, pond-with-island 4x4 at 4..7, diagonals at column 9, plain land at (0, 5)).
const CORNER_LAYOUT := [Vector2i(0, 5), Vector2i(4, 0), Vector2i(7, 0), Vector2i(5, 0), Vector2i(4, 3), Vector2i(4, 1), Vector2i(9, 1), Vector2i(6, 2), Vector2i(7, 3), Vector2i(9, 0), Vector2i(7, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(6, 1), Vector2i(5, 1), Vector2i(1, 1)]
enum Source {WATER, FLOOR, FIELD, LAVA, RELIEF, RELIEF_DETAIL, PATHS}
const SHEETS := {
    Source.WATER: "res://assets/game/world/water.png",
    Source.FLOOR: "res://assets/game/world/terrain_floor.png",
    Source.FIELD: "res://assets/game/world/terrain_field.png",
    Source.LAVA: "res://assets/game/world/lava.png",
    Source.RELIEF: "res://assets/game/world/relief.png",
    Source.RELIEF_DETAIL: "res://assets/game/world/relief_detail.png",
    Source.PATHS: "res://assets/game/world/paths.png",
}
## Row offset of each corner set inside its sheet.
const SHORE_SAND := [Source.WATER, 0]
const SHORE_GRASS := [Source.WATER, 6]
const LAVA_ASH := [Source.LAVA, 0]
## Roads: the dirt corner set in paths.png, one 6-row copy per ground fringe (prepare_world.py).
const PATH_VARIANT := {0: 1, 1: 0, 2: 0, 3: 6, 4: 5, 5: 2, 6: 3, 7: 4}
## Rounded 3x3 patches of the field sheet per WorldMap.Ground: [top-left tile, plain tiles]. They
## layer every ground over the sand base and draw plateau rims (their dark edge reads as a ledge).
const PATCHES := {
    0: [Vector2i(0, 18), [Vector2i(3, 18), Vector2i(4, 18), Vector2i(3, 19), Vector2i(4, 19)]],
    1: [Vector2i(0, 3), [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)]],
    2: [Vector2i(0, 6), [Vector2i(3, 6), Vector2i(4, 6), Vector2i(3, 7), Vector2i(4, 7)]],
    3: [Vector2i(0, 0), [Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1)]],
    4: [Vector2i(0, 21), [Vector2i(3, 21), Vector2i(4, 21), Vector2i(3, 22), Vector2i(4, 22)]],
    5: [Vector2i(0, 12), [Vector2i(3, 12), Vector2i(4, 12), Vector2i(3, 13), Vector2i(4, 13)]],
    6: [Vector2i(0, 9), [Vector2i(3, 9), Vector2i(4, 9), Vector2i(3, 10), Vector2i(4, 10)]],
    7: [Vector2i(0, 15), [Vector2i(3, 15), Vector2i(4, 15), Vector2i(3, 16), Vector2i(4, 16)]],
}
## Plain grass and forest use the floor sheet's varied tiles.
const PLAIN_GRASS := [Vector2i(0, 12), Vector2i(0, 12), Vector2i(0, 12), Vector2i(1, 12), Vector2i(2, 12), Vector2i(3, 12)]
const PLAIN_FOREST := [Vector2i(11, 12), Vector2i(11, 12), Vector2i(12, 12), Vector2i(13, 12)]
const BRIDGE_TILE := Vector2i(5, 13)
## Corner code -> patch tile offset (no inner corners in a 3x3 patch: three corners and the two
## diagonals use the full centre).
const PATCH_LAYOUT := [Vector2i(-1, -1), Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 2), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 1), Vector2i(2, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 1), Vector2i(1, 1), Vector2i(1, 1)]
## Rock walls below plateaus (relief sheet): grey for green, snowy and wet lands, brown for sand,
## autumn and ash. Columns: left end, middle, right end; rows: upper and lower wall tile.
const WALL_GREY := [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), 1]
const WALL_BROWN := [Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), 6]
const BROWN_WALL_GROUNDS := [0, 3, 4]
## Stairs where a road climbs a wall (relief detail sheet): grey and orange steps.
const STAIRS_GREY := [Vector2i(5, 0), Vector2i(5, 1)]
const STAIRS_BROWN := [Vector2i(5, 3), Vector2i(5, 4)]
## Props: [sheet, region, footprint size (0 = walk through)]. Foot = bottom-centre.
const PROPS := {
    "pine": ["res://assets/game/world/nature.png", Rect2(32, 0, 32, 32), Vector2(10, 8)],
    "tree_big": ["res://assets/game/world/nature.png", Rect2(48, 288, 48, 48), Vector2(12, 10)],
    "tree_round": ["res://assets/game/world/nature.png", Rect2(256, 0, 32, 32), Vector2(10, 8)],
    "tree_autumn": ["res://assets/game/world/nature.png", Rect2(144, 288, 48, 48), Vector2(12, 10)],
    "tree_dead": ["res://assets/game/world/nature.png", Rect2(64, 0, 32, 32), Vector2(10, 8)],
    "boulder": ["res://assets/game/world/nature.png", Rect2(256, 128, 32, 32), Vector2(26, 14)],
    "bush": ["res://assets/game/world/nature.png", Rect2(0, 160, 16, 16), Vector2.ZERO],
    "pebbles": ["res://assets/game/world/nature.png", Rect2(240, 288, 32, 16), Vector2.ZERO],
    "pine_snow": ["res://assets/game/world/nature.png", Rect2(128, 0, 32, 32), Vector2(10, 8)],
    "tree_snow": ["res://assets/game/world/nature.png", Rect2(192, 0, 32, 32), Vector2(10, 8)],
    "tree_snow_big": ["res://assets/game/world/nature.png", Rect2(96, 288, 48, 48), Vector2(12, 10)],
    "boulder_snow": ["res://assets/game/world/nature.png", Rect2(32, 192, 32, 32), Vector2(24, 12)],
    "tree_pink": ["res://assets/game/world/nature.png", Rect2(224, 0, 32, 32), Vector2(10, 8)],
    "tree_blossom": ["res://assets/game/world/nature.png", Rect2(0, 288, 48, 48), Vector2(12, 10)],
    "bamboo": ["res://assets/game/world/nature.png", Rect2(176, 128, 16, 48), Vector2(8, 6)],
    "palm": ["res://assets/game/world/desert.png", Rect2(192, 160, 32, 32), Vector2(10, 8)],
    "ruin_hall": ["res://assets/game/world/ruins.png", Rect2(0, 0, 64, 48), Vector2(56, 18)],
    "ruin_statue": ["res://assets/game/world/ruins.png", Rect2(0, 48, 32, 48), Vector2(24, 12)],
    "ruin_pillar": ["res://assets/game/world/ruins.png", Rect2(48, 48, 16, 48), Vector2(12, 10)],
    "ruin_house": ["res://assets/game/world/ruins.png", Rect2(176, 0, 48, 48), Vector2(40, 18)],
    "house_a": ["res://assets/game/world/house.png", Rect2(0, 0, 48, 48), Vector2(40, 20)],
    "house_b": ["res://assets/game/world/house.png", Rect2(64, 0, 64, 48), Vector2(56, 20)],
    "house_c": ["res://assets/game/world/house.png", Rect2(192, 0, 64, 48), Vector2(56, 20)],
    "shop": ["res://assets/game/world/house.png", Rect2(256, 0, 48, 48), Vector2(40, 20)],
    "shop_green": ["res://assets/game/world/house.png", Rect2(304, 0, 48, 48), Vector2(40, 20)],
    "house_round": ["res://assets/game/world/house.png", Rect2(368, 0, 48, 48), Vector2(40, 20)],
    "house_wood": ["res://assets/game/world/house.png", Rect2(416, 0, 48, 48), Vector2(40, 20)],
    "hall": ["res://assets/game/world/house.png", Rect2(400, 112, 64, 112), Vector2(56, 24)],
    "lodge": ["res://assets/game/world/house.png", Rect2(400, 224, 64, 84), Vector2(56, 22)],
    "torii": ["res://assets/game/world/house.png", Rect2(0, 80, 32, 32), Vector2(6, 6)],
    "hut_tent": ["res://assets/game/world/house.png", Rect2(0, 120, 48, 40), Vector2(40, 18)],
    "hut_straw": ["res://assets/game/world/house.png", Rect2(48, 120, 48, 40), Vector2(40, 18)],
    "igloo_a": ["res://assets/game/world/house.png", Rect2(0, 176, 48, 48), Vector2(40, 20)],
    "igloo_b": ["res://assets/game/world/house.png", Rect2(48, 176, 48, 48), Vector2(36, 20)],
    "igloo_c": ["res://assets/game/world/house.png", Rect2(96, 176, 48, 48), Vector2(40, 20)],
    "dome_hut": ["res://assets/game/world/desert.png", Rect2(0, 0, 48, 48), Vector2(40, 20)],
    "desert_house": ["res://assets/game/world/desert.png", Rect2(96, 0, 64, 48), Vector2(56, 20)],
    "well": ["res://assets/game/world/desert.png", Rect2(0, 48, 32, 32), Vector2(24, 12)],
    "stall": ["res://assets/game/world/desert.png", Rect2(32, 160, 32, 32), Vector2(28, 10)],
    "tower": ["res://assets/game/world/desert.png", Rect2(48, 0, 32, 80), Vector2(26, 18)],
    "wall": ["res://assets/game/world/desert.png", Rect2(272, 64, 48, 48), Vector2(48, 18)],
    "ferry_boat": ["res://assets/game/world/boat.png", Rect2(0, 0, 80, 32), Vector2.ZERO],
}
## Hand-placed landmarks (tile positions of the foot).
const LANDMARKS := [
    ["ruin_hall", Vector2(246, 71.5)], ["ruin_pillar", Vector2(242, 70)], ["ruin_pillar", Vector2(250, 70)],
    ["house_a", Vector2(336, 88)], ["house_c", Vector2(352, 87)], ["house_a", Vector2(341, 101)], ["tower", Vector2(358, 100)],
    ["wall", Vector2(331, 80)], ["wall", Vector2(334, 80)], ["wall", Vector2(337, 80)], ["wall", Vector2(355, 80)], ["wall", Vector2(358, 80)], ["wall", Vector2(361, 80)],
    ["ruin_house", Vector2(150, 246)], ["ruin_statue", Vector2(212, 240)], ["ruin_hall", Vector2(262, 248)],
    # Sakura Vale's hilltop shrine.
    ["torii", Vector2(600, -44)], ["ruin_statue", Vector2(604, -54)], ["tree_blossom", Vector2(592, -56)], ["tree_blossom", Vector2(612, -58)],
]
## Buildings per town theme: [centre building, merchant's shop, ring buildings, decorations].
const THEMES := {
    "verdant": ["hall", "shop", ["house_a", "house_b", "house_wood", "house_a", "house_round"], ["tree_round", "well", "bush"]],
    "harrow": ["", "shop", [], []],
    "amber": ["hall", "shop", ["house_wood", "house_a", "hut_straw", "house_b"], ["tree_autumn", "well", "bush"]],
    "frost": ["lodge", "shop", ["igloo_a", "igloo_b", "igloo_c", "igloo_a"], ["pine_snow", "boulder_snow"]],
    "desert": ["tower", "stall", ["dome_hut", "desert_house", "dome_hut", "desert_house"], ["palm", "well", "palm"]],
    "sakura": ["hall", "shop_green", ["house_c", "house_round", "house_c", "shop_green"], ["tree_pink", "torii", "bamboo"]],
    "marsh": ["hall", "hut_tent", ["hut_straw", "hut_tent", "hut_straw", "house_wood"], ["tree_dead", "bush"]],
    "ember": ["hall", "house_round", ["house_round", "hut_tent", "house_round", "hut_tent"], ["boulder", "tree_dead"]],
}
const PROP_SEED := 9001
## Props are spawned in square chunks of this many tiles around every character.
const CHUNK := 32
const STREAM_SECONDS := 0.25
## Built once per process and copied into every new world instance (worlds are reloaded often:
## title → world → title, tests). Layer cell data and the prop list (also in WorldCache).
static var _layer_cache: Dictionary = {}
static var _prop_cache: Array = []
static var _chunks: Dictionary = {}

var ground: TileMapLayer
## Rounded overlays: every ground over the sand base, forest over grass.
var blend: TileMapLayer
var canopy: TileMapLayer
## Plateau rims (patches of the ground above) and rock walls with stairs.
var heights: TileMapLayer
var cliffs: TileMapLayer
## Coasts, lakes, lava and paths on top of every land layer.
var features: TileMapLayer
var bridges: TileMapLayer
var props: Node2D
var collision: StaticBody2D
## Chunk → spawned prop nodes.
var _spawned: Dictionary = {}
var _stream_left := 0.0

static func tile_set() -> TileSet:
    var tiles := TileSet.new()
    tiles.tile_size = Vector2i(TILE, TILE)
    for id in SHEETS:
        var source := TileSetAtlasSource.new()
        source.texture = load(SHEETS[id])
        source.texture_region_size = Vector2i(TILE, TILE)
        var grid: Vector2i = source.texture.get_size() / TILE
        for y in range(grid.y):
            for x in range(grid.x):
                source.create_tile(Vector2i(x, y))
        tiles.add_source(source, id)
    return tiles

const LAYERS := ["Ground", "Blend", "Forest", "Heights", "Cliffs", "Features", "Bridges"]

func _ready() -> void:
    name = "WorldTerrain"
    var tiles := tile_set()
    ground = _layer("Ground", tiles, -2)
    blend = _layer("Blend", tiles, -2)
    canopy = _layer("Forest", tiles, -2)
    heights = _layer("Heights", tiles, -2)
    cliffs = _layer("Cliffs", tiles, -2)
    features = _layer("Features", tiles, -2)
    bridges = _layer("Bridges", tiles, -1)
    var all: Array = [ground, blend, canopy, heights, cliffs, features, bridges]
    if _layer_cache.is_empty() and MAP.use_cache:
        var stored: Variant = CACHE.load_part("layers")
        if stored is Dictionary:
            _layer_cache = stored
    if _layer_cache.is_empty():
        _fill()
        for layer in all:
            _layer_cache[layer.name] = layer.tile_map_data
    else:
        for layer in all:
            layer.tile_map_data = _layer_cache[layer.name]
    collision = StaticBody2D.new()
    collision.name = "Coasts"
    for rect in MAP.solid_rects():
        _box(rect)
    # World edge (beyond the ocean).
    var outer := MAP.bounds()
    for edge in [Rect2(outer.position - Vector2(16, 0), Vector2(16, outer.size.y)), Rect2(Vector2(outer.end.x, outer.position.y), Vector2(16, outer.size.y)), Rect2(outer.position - Vector2(0, 16), Vector2(outer.size.x, 16)), Rect2(Vector2(outer.position.x, outer.end.y), Vector2(outer.size.x, 16))]:
        _box(edge)
    add_child(collision)
    props = Node2D.new()
    props.name = "WorldProps"
    props.y_sort_enabled = true
    add_child(props)
    _plan_once()
    stream_props()

func _box(rect: Rect2) -> void:
    var shape := CollisionShape2D.new()
    var box := RectangleShape2D.new()
    box.size = rect.size
    shape.shape = box
    shape.position = rect.get_center()
    collision.add_child(shape)

func _layer(id: String, tiles: TileSet, z: int) -> TileMapLayer:
    var layer := TileMapLayer.new()
    layer.name = id
    layer.tile_set = tiles
    layer.z_index = z
    add_child(layer)
    return layer

## Which feature tile draws (x, y): water first, then lake, lava, paths; [] for plain land.
static func feature_for(x: int, y: int) -> Array:
    var map: Dictionary = MAP.data()
    var code: int = MAP.corners(map.ocean, x, y)
    if code > 0:
        return [SHORE_SAND[0], CORNER_LAYOUT[code] + Vector2i(0, SHORE_SAND[1])]
    code = MAP.corners(map.lake, x, y)
    if code > 0:
        return [SHORE_GRASS[0], CORNER_LAYOUT[code] + Vector2i(0, SHORE_GRASS[1])]
    code = MAP.corners(map.lava, x, y)
    if code > 0:
        return [LAVA_ASH[0], CORNER_LAYOUT[code] + Vector2i(0, LAVA_ASH[1])]
    code = MAP.corners(map.dirt, x, y)
    if code > 0:
        var variant: int = PATH_VARIANT[int(map.ground[MAP.vertex_index(x, y)])]
        return [Source.PATHS, CORNER_LAYOUT[code] + Vector2i(0, 6 * variant)]
    return []

static func _variant(list: Array, x: int, y: int) -> Vector2i:
    return list[absi(x * 7 + y * 13 + x * y) % 23 % list.size()]

## Corner code of "ground is one of kinds" for tile (x, y).
static func _ground_code(x: int, y: int, kinds: Array) -> int:
    var ground_data: PackedByteArray = MAP.data().ground
    var code := 0
    for corner in [[0, 0, 8], [1, 0, 4], [0, 1, 2], [1, 1, 1]]:
        if ground_data[MAP.vertex_index(x + corner[0], y + corner[1])] in kinds:
            code += corner[2]
    return code

func _fill() -> void:
    var map: Dictionary = MAP.data()
    var offset := Vector2i(MAP.ORIGIN / TILE)
    for y in range(MAP.MIN.y, MAP.MIN.y + MAP.ROWS):
        for x in range(MAP.MIN.x, MAP.MIN.x + MAP.COLS):
            var cell := Vector2i(x, y) + offset
            var feature := feature_for(x, y)
            if not feature.is_empty():
                features.set_cell(cell, feature[0], feature[1])
            if feature.is_empty() or feature[1] != CORNER_LAYOUT[15] + Vector2i(0, SHORE_SAND[1]) or feature[0] != SHORE_SAND[0]:
                _land(x, y, cell)
                _relief(x, y, cell)
            if map.bridge[MAP.tile_index(x, y)] == 1:
                bridges.set_cell(cell, Source.WATER, BRIDGE_TILE)

## Land under (x, y): ash or sand base, then each ground as a rounded overlay, forest over grass.
func _land(x: int, y: int, cell: Vector2i) -> void:
    var codes := {}
    var full := false
    for kind in [MAP.Ground.GRASS, MAP.Ground.AUTUMN, MAP.Ground.SNOW, MAP.Ground.BLOSSOM, MAP.Ground.MUD]:
        var kinds: Array = [MAP.Ground.GRASS, MAP.Ground.FOREST] if kind == MAP.Ground.GRASS else [kind]
        var code := _ground_code(x, y, kinds)
        if code > 0:
            codes[kind] = code
            full = full or code == 15
    var ash := _ground_code(x, y, [MAP.Ground.ASH])
    var forest := _ground_code(x, y, [MAP.Ground.FOREST])
    if ash > 0:
        ground.set_cell(cell, Source.LAVA, Vector2i(0, 5))
    elif not full:
        ground.set_cell(cell, Source.WATER, Vector2i(0, 5))
    for kind in codes:
        var code: int = codes[kind]
        if code == 15:
            if kind == MAP.Ground.GRASS:
                if forest < 15:
                    blend.set_cell(cell, Source.FLOOR, _variant(PLAIN_GRASS, x, y))
            else:
                blend.set_cell(cell, Source.FIELD, PATCHES[kind][0] + Vector2i(1, 1))
        else:
            blend.set_cell(cell, Source.FIELD, PATCHES[kind][0] + PATCH_LAYOUT[code])
    if forest == 15:
        canopy.set_cell(cell, Source.FLOOR, _variant(PLAIN_FOREST, x, y))
    elif forest > 0:
        canopy.set_cell(cell, Source.FIELD, PATCHES[MAP.Ground.FOREST][0] + PATCH_LAYOUT[forest])

## Verticality: the rim of each raised level drawn as the ground's rounded patch (its dark edge is
## the ledge), and rock walls (or stairs on roads) below south rims.
func _relief(x: int, y: int, cell: Vector2i) -> void:
    var map: Dictionary = MAP.data()
    var corner_heights: Array = MAP.heights(x, y)
    var top: int = corner_heights.max()
    var kind: int = map.ground[MAP.vertex_index(x, y)]
    if top > corner_heights.min():
        var code := 0
        for index in range(4):
            if corner_heights[index] >= top:
                code += [8, 4, 2, 1][index]
        heights.set_cell(cell, Source.FIELD, PATCHES[kind][0] + PATCH_LAYOUT[code])
        return
    var wall := MAP.cliff(x, y)
    var brown: bool = kind in BROWN_WALL_GROUNDS
    if wall == MAP.Cliff.WALL_TOP or wall == MAP.Cliff.WALL_BOTTOM:
        var walls: Array = WALL_BROWN if brown else WALL_GREY
        var left := MAP.cliff(x - 1, y) == wall
        var right := MAP.cliff(x + 1, y) == wall
        var column: Vector2i = walls[1] if left and right else (walls[0] if right else (walls[2] if left else walls[1]))
        cliffs.set_cell(cell, Source.RELIEF, column + Vector2i(0, 0 if wall == MAP.Cliff.WALL_TOP else 1))
        return
    # Stairs where a road climbs a south wall.
    for step in [1, 2]:
        if MAP._south_rim(x, y - step) and MAP.ramp(x, y - step) and corner_heights[0] < MAP.heights(x, y - step).max():
            var stairs: Array = STAIRS_BROWN if brown else STAIRS_GREY
            cliffs.set_cell(cell, Source.RELIEF_DETAIL, stairs[step - 1])
            return

func _prop(id: String, foot: Vector2) -> void:
    _prop_cache.append([id, foot])

func _spawn_prop(id: String, foot: Vector2) -> Node2D:
    var spec: Array = PROPS[id]
    var holder := StaticBody2D.new() if spec[2] != Vector2.ZERO else Node2D.new()
    holder.position = foot.round()
    holder.y_sort_enabled = true
    var sprite := Sprite2D.new()
    var texture := AtlasTexture.new()
    texture.atlas = load(spec[0])
    texture.region = spec[1]
    sprite.texture = texture
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.offset = Vector2(0, -spec[1].size.y / 2.0)
    holder.add_child(sprite)
    if spec[2] != Vector2.ZERO:
        var shape := CollisionShape2D.new()
        var box := RectangleShape2D.new()
        box.size = spec[2]
        shape.shape = box
        shape.position = Vector2(0, -spec[2].y / 2.0)
        holder.add_child(shape)
    holder.set_meta("prop", id)
    props.add_child(holder)
    return holder

## The prop plan (from WorldCache or computed) and its chunk index, once per process.
func _plan_once() -> void:
    if _prop_cache.is_empty() and MAP.use_cache:
        var stored: Variant = CACHE.load_part("props")
        if stored is Array:
            _prop_cache = stored
    if _prop_cache.is_empty():
        _plan_props()
    if _chunks.is_empty():
        for index in range(_prop_cache.size()):
            var chunk := chunk_of(_prop_cache[index][1])
            if not _chunks.has(chunk):
                _chunks[chunk] = []
            _chunks[chunk].append(index)

static func chunk_of(world: Vector2) -> Vector2i:
    return Vector2i(((world - MAP.ORIGIN) / (TILE * CHUNK)).floor())

static func planned_props() -> Array:
    return _prop_cache

func _physics_process(delta: float) -> void:
    _stream_left -= delta
    if _stream_left <= 0.0:
        _stream_left = STREAM_SECONDS
        stream_props()

## Spawn the props of every chunk next to a character (3x3 chunks each), free those two chunks
## away from all of them. Without characters yet, around the spawn.
func stream_props(extra: Array = []) -> void:
    var centres: Array = extra.duplicate()
    for actor in get_tree().get_nodes_in_group("player"):
        if is_instance_valid(actor) and get_parent() != null and actor.get_parent() == get_parent():
            centres.append(chunk_of(actor.global_position))
    if centres.is_empty():
        centres.append(chunk_of(preload("res://scripts/world/world_layout.gd").SPAWN))
    for chunk in _spawned.keys():
        var near := false
        for centre in centres:
            near = near or (absi(chunk.x - centre.x) <= 2 and absi(chunk.y - centre.y) <= 2)
        if not near:
            for node in _spawned[chunk]:
                if is_instance_valid(node):
                    node.queue_free()
            _spawned.erase(chunk)
    for centre in centres:
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                var chunk: Vector2i = centre + Vector2i(dx, dy)
                if _spawned.has(chunk):
                    continue
                var nodes: Array = []
                for index in _chunks.get(chunk, []):
                    nodes.append(_spawn_prop(_prop_cache[index][0], _prop_cache[index][1]))
                _spawned[chunk] = nodes

## Spawn the chunks around a world position right away (teleports, ferries, tests).
func ensure_props_at(world: Vector2) -> void:
    stream_props([chunk_of(world)])

## Deterministic plan: landmarks, towns, ferry boats, then scatter by ground and region, kept
## off the clearing, roads, shores, cliffs, towns and content spots.
func _plan_props() -> void:
    var map: Dictionary = MAP.data()
    var taken: Array = []
    for landmark in LANDMARKS:
        _prop(landmark[0], MAP.to_world(landmark[1]))
        taken.append(_footprint(landmark[0], landmark[1]))
    for town in MAP.TOWNS:
        _plan_town(town, map, taken)
    for ferry in MAP.FERRIES:
        var direction := Vector2(ferry[3])
        var end: Vector2 = Vector2(ferry[2]) + direction * (MAP.PIER_LENGTH + 0.5)
        var boat: Vector2 = end + (Vector2(3.5, 2.0) if direction.x == 0 else direction * 3.0 + Vector2(0, 2.0))
        _prop("ferry_boat", MAP.to_world(boat))
    var rng := RandomNumberGenerator.new()
    rng.seed = PROP_SEED
    var keep_out := Rect2(MAP.CLEARING.position - Vector2i(3, 3), MAP.CLEARING.size + Vector2i(6, 6))
    var crater: Vector2 = MAP.AREAS[1][0]
    for angle_step in range(14):
        var at := crater + Vector2.from_angle(angle_step * TAU / 14.0) * Vector2(11, 8)
        _prop("boulder", MAP.to_world(at.round()))
    var spots: Array = preload("res://scripts/world/region_content.gd").spots()
    for cy in range(MAP.MIN.y + 2, MAP.MIN.y + MAP.ROWS - 3, 3):
        for cx in range(MAP.MIN.x + 2, MAP.MIN.x + MAP.COLS - 3, 3):
            var tile := Vector2i(cx + rng.randi_range(0, 2), cy + rng.randi_range(0, 2))
            var roll := rng.randf()
            var pick := rng.randi_range(0, 99)
            if map.ocean[MAP.vertex_index(tile.x, tile.y)] == 1 or keep_out.has_point(tile) or not _clear_ground(map, tile):
                continue
            var kind: int = map.ground[MAP.vertex_index(tile.x, tile.y)]
            var region: int = map.region[MAP.tile_index(tile.x, tile.y)]
            var id := _scatter(kind, region, roll, pick)
            if not id.is_empty() and not _near_landmark(tile, spots):
                _prop(id, MAP.to_world(Vector2(tile) + Vector2(0.5, 1.0)))

## What grows at a tile (by ground, then region).
static func _scatter(kind: int, region: int, roll: float, pick: int) -> String:
    match kind:
        MAP.Ground.FOREST:
            if roll < 0.7:
                return ["pine", "pine", "tree_big", "tree_round"][pick % 4]
        MAP.Ground.GRASS:
            if roll < 0.1:
                return ["tree_big", "tree_round", "bush", "bush"][pick % 4]
        MAP.Ground.AUTUMN:
            if roll < 0.22:
                return ["tree_autumn", "tree_autumn", "bush"][pick % 3]
        MAP.Ground.ASH:
            if region == MAP.Region.EMBERREACH and roll < 0.3:
                return ["tree_dead", "boulder", "pebbles"][pick % 3]
            elif roll < 0.25:
                return ["boulder", "pebbles", "pebbles", "tree_dead"][pick % 4]
        MAP.Ground.SAND:
            if region == MAP.Region.SUNSCORCH:
                if roll < 0.05:
                    return ["palm", "boulder", "pebbles", "palm", "bush"][pick % 5]
            elif roll < 0.015:
                return "bush"
        MAP.Ground.SNOW:
            if roll < 0.16:
                return ["pine_snow", "pine_snow", "tree_snow", "tree_snow_big", "boulder_snow"][pick % 5]
        MAP.Ground.BLOSSOM:
            if roll < 0.13:
                return ["tree_pink", "tree_blossom", "bamboo", "bamboo", "bush"][pick % 5]
        MAP.Ground.MUD:
            if roll < 0.16:
                return ["tree_dead", "tree_dead", "bush", "pebbles", "bush"][pick % 5]
    return ""

## Tile rect a prop occupies (its sprite's lower part), for keeping buildings apart.
static func _footprint(id: String, foot: Vector2) -> Rect2:
    var size: Vector2 = PROPS[id][1].size / TILE
    var depth := minf(size.y, 2.5)
    return Rect2(foot.x - size.x / 2.0, foot.y - depth, size.x, depth)

## Town and village buildings around the plaza: the centre building north of it, the merchant's
## shop east of it, a ring of homes and a few decorations; each only where it fits.
func _plan_town(town: Array, map: Dictionary, taken: Array) -> void:
    var theme: Array = THEMES[town[5]]
    var centre: Vector2 = town[3]
    var big: bool = town[4] == "town"
    var wanted: Array = []
    if big and not theme[0].is_empty():
        wanted.append([theme[0], centre + Vector2(0, -6.5)])
    if big:
        wanted.append([theme[1], centre + Vector2(7, -1)])
    var ring: Array = theme[2]
    var count: int = 10 if big else 5
    var radii: Vector2 = Vector2(13, 9) if big else Vector2(7.5, 5.5)
    var turn: float = float(absi(hash(town[0])) % 360) / 360.0 * TAU
    for index in range(count if not ring.is_empty() else 0):
        var angle := turn + index * TAU / count
        wanted.append([ring[index % ring.size()], centre + Vector2.from_angle(angle) * radii + Vector2(0, 1)])
    var decor: Array = theme[3]
    for index in range(decor.size() * (2 if big else 1)):
        var angle := turn + (index + 0.5) * TAU / (decor.size() * (2 if big else 1))
        wanted.append([decor[index % decor.size()], centre + Vector2.from_angle(angle) * (radii * 0.55) + Vector2(0, 1)])
    for entry in wanted:
        var foot: Vector2 = entry[1]
        var area := _footprint(entry[0], foot)
        if not _fits(map, area, taken):
            continue
        taken.append(area.grow(1.0))
        _prop(entry[0], MAP.to_world(foot))

## A building fits on dry, level land off roads, cliffs, bridges and other buildings.
static func _fits(map: Dictionary, area: Rect2, taken: Array) -> bool:
    for other in taken:
        if other.intersects(area):
            return false
    var level := -1
    for y in range(floori(area.position.y), ceili(area.end.y) + 1):
        for x in range(floori(area.position.x), ceili(area.end.x) + 1):
            if not MAP.in_grid(Vector2i(x, y)) or MAP.solid(x, y) or map.bridge[MAP.tile_index(x, y)] == 1:
                return false
            var vertex := MAP.vertex_index(x, y)
            if map.dirt[vertex] == 1 or map.lake[vertex] == 1 or map.ocean[vertex] == 1:
                return false
            if level >= 0 and map.height[vertex] != level:
                return false
            level = map.height[vertex]
    return true

## Land around the tile, away from water, lava, paths, bridges and cliffs.
static func _clear_ground(map: Dictionary, tile: Vector2i) -> bool:
    for dy in range(-1, 3):
        for dx in range(-1, 2):
            var x := clampi(tile.x + dx, MAP.MIN.x, MAP.MIN.x + MAP.COLS - 1)
            var y := clampi(tile.y + dy, MAP.MIN.y, MAP.MIN.y + MAP.ROWS - 1)
            var vertex := MAP.vertex_index(x, y)
            if map.ocean[vertex] == 1 or map.lake[vertex] == 1 or map.lava[vertex] == 1 or map.dirt[vertex] == 1:
                return false
            if map.bridge[MAP.tile_index(x, y)] == 1 or MAP.cliff(x, y) != MAP.Cliff.NONE:
                return false
    return true

func _near_landmark(tile: Vector2i, spots: Array) -> bool:
    for landmark in LANDMARKS:
        if Vector2(tile).distance_to(landmark[1]) < 5.0:
            return true
    for town in MAP.TOWNS:
        if Vector2(tile).distance_to(town[3]) < (16.0 if town[4] == "town" else 10.0):
            return true
    # Region content (M4.5b): creatures, deposits and chests stand in the open.
    for spot in spots:
        if Vector2(tile).distance_to(spot) < 3.0:
            return true
    for ferry in MAP.FERRIES:
        if Vector2(tile).distance_to(ferry[2]) < 6.0:
            return true
    return Vector2(tile).distance_to(MAP.AREAS[1][0]) < 9.0
