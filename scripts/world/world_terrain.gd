extends Node2D
## Draws and collides the archipelago (M4.5a) from WorldMap: a ground TileMapLayer (dual-grid
## corner tiles for coasts, lake shores, lava and paths), a bridge layer, merged collision
## rectangles for water and lava, and y-sorted props (trees, boulders, ruins, town buildings)
## with trunk/footprint collisions. Presentation and static collisions only: the same on host
## and clients, nothing saved.
const MAP := preload("res://scripts/world/world_map.gd")
const TILE := 16
## The 16 corner combinations (top-left 8, top-right 4, bottom-left 2, bottom-right 1; bit =
## water/lava/dirt) in the Ninja Adventure layout shared by the water, lava and dirt sets
## (pond 3x3 at 0..2, pond-with-island 4x4 at 4..7, diagonals at column 9, plain land at (0, 5)).
const CORNER_LAYOUT := [Vector2i(0, 5), Vector2i(4, 0), Vector2i(7, 0), Vector2i(5, 0), Vector2i(4, 3), Vector2i(4, 1), Vector2i(9, 1), Vector2i(6, 2), Vector2i(7, 3), Vector2i(9, 0), Vector2i(7, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(6, 1), Vector2i(5, 1), Vector2i(1, 1)]
enum Source {WATER, FLOOR, FIELD, LAVA}
const SHEETS := {
    Source.WATER: "res://assets/game/world/water.png",
    Source.FLOOR: "res://assets/game/world/terrain_floor.png",
    Source.FIELD: "res://assets/game/world/terrain_field.png",
    Source.LAVA: "res://assets/game/world/lava.png",
}
## Row offset of each corner set inside its sheet.
const SHORE_SAND := [Source.WATER, 0]
const SHORE_GRASS := [Source.WATER, 6]
const LAVA_ASH := [Source.LAVA, 0]
const DIRT_GRASS := [Source.FLOOR, 7]
## Plain ground per WorldMap.Ground: [source, tiles to vary between].
const PLAIN := {
    0: [Source.WATER, [Vector2i(0, 5)]],
    1: [Source.FLOOR, [Vector2i(0, 12), Vector2i(0, 12), Vector2i(0, 12), Vector2i(1, 12), Vector2i(2, 12), Vector2i(3, 12)]],
    2: [Source.FLOOR, [Vector2i(11, 12), Vector2i(11, 12), Vector2i(12, 12), Vector2i(13, 12)]],
    3: [Source.FIELD, [Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1)]],
    4: [Source.LAVA, [Vector2i(0, 5)]],
}
const BRIDGE_TILE := Vector2i(5, 13)
## Rounded 3x3 patches of the field sheet, layered over the ground below them (grass and
## autumn over sand, forest over grass): [top-left tile of the patch, plain tiles].
const PATCHES := {
    1: [Vector2i(0, 3), [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)]],
    3: [Vector2i(0, 0), [Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1)]],
    2: [Vector2i(0, 6), [Vector2i(3, 6), Vector2i(4, 6), Vector2i(3, 7), Vector2i(4, 7)]],
}
## Corner code -> patch tile offset (no inner corners in a 3x3 patch: three corners and the two
## diagonals use the full centre).
const PATCH_LAYOUT := [Vector2i(-1, -1), Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 2), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 1), Vector2i(2, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 1), Vector2i(1, 1), Vector2i(1, 1)]
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
    "ruin_hall": ["res://assets/game/world/ruins.png", Rect2(0, 0, 64, 48), Vector2(56, 18)],
    "ruin_statue": ["res://assets/game/world/ruins.png", Rect2(0, 48, 32, 48), Vector2(24, 12)],
    "ruin_pillar": ["res://assets/game/world/ruins.png", Rect2(48, 48, 16, 48), Vector2(12, 10)],
    "ruin_house": ["res://assets/game/world/ruins.png", Rect2(176, 0, 48, 48), Vector2(40, 18)],
    "house_a": ["res://assets/game/world/house.png", Rect2(0, 0, 48, 48), Vector2(40, 20)],
    "house_c": ["res://assets/game/world/house.png", Rect2(192, 0, 64, 48), Vector2(56, 20)],
    "tower": ["res://assets/game/world/desert.png", Rect2(48, 0, 32, 80), Vector2(26, 18)],
    "wall": ["res://assets/game/world/desert.png", Rect2(272, 64, 48, 48), Vector2(48, 18)],
}
## Hand-placed landmarks (tile positions of the foot).
const LANDMARKS := [
    ["ruin_hall", Vector2(246, 71.5)], ["ruin_pillar", Vector2(242, 70)], ["ruin_pillar", Vector2(250, 70)],
    ["house_a", Vector2(336, 88)], ["house_c", Vector2(352, 87)], ["house_a", Vector2(341, 101)], ["tower", Vector2(358, 100)],
    ["wall", Vector2(331, 80)], ["wall", Vector2(334, 80)], ["wall", Vector2(337, 80)], ["wall", Vector2(355, 80)], ["wall", Vector2(358, 80)], ["wall", Vector2(361, 80)],
    ["ruin_house", Vector2(150, 246)], ["ruin_statue", Vector2(212, 240)], ["ruin_hall", Vector2(262, 248)],
]
const PROP_SEED := 9001
## Built once per process and copied into every new world instance (worlds are reloaded often:
## title → world → title, tests). Layer cell data and the prop list.
static var _layer_cache: Dictionary = {}
static var _prop_cache: Array = []

var ground: TileMapLayer
## Rounded overlays: grass/autumn over sand, forest over grass.
var blend: TileMapLayer
var canopy: TileMapLayer
## Coasts, lakes, lava and paths on top of every land layer.
var features: TileMapLayer
var bridges: TileMapLayer
var props: Node2D
var collision: StaticBody2D

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

func _ready() -> void:
    name = "WorldTerrain"
    var tiles := tile_set()
    ground = TileMapLayer.new()
    ground.name = "Ground"
    ground.tile_set = tiles
    ground.z_index = -2
    add_child(ground)
    blend = _layer("Blend", tiles, -2)
    canopy = _layer("Forest", tiles, -2)
    features = _layer("Features", tiles, -2)
    bridges = TileMapLayer.new()
    bridges.name = "Bridges"
    bridges.tile_set = tiles
    bridges.z_index = -1
    add_child(bridges)
    if _layer_cache.is_empty():
        _fill()
        for layer in [ground, blend, canopy, features, bridges]:
            _layer_cache[layer.name] = layer.tile_map_data
    else:
        for layer in [ground, blend, canopy, features, bridges]:
            layer.tile_map_data = _layer_cache[layer.name]
    collision = StaticBody2D.new()
    collision.name = "Coasts"
    for rect in MAP.solid_rects():
        var shape := CollisionShape2D.new()
        var box := RectangleShape2D.new()
        box.size = rect.size
        shape.shape = box
        shape.position = rect.get_center()
        collision.add_child(shape)
    # World edge (beyond the ocean).
    var outer := MAP.bounds()
    for edge in [Rect2(outer.position - Vector2(16, 0), Vector2(16, outer.size.y)), Rect2(Vector2(outer.end.x, outer.position.y), Vector2(16, outer.size.y)), Rect2(outer.position - Vector2(0, 16), Vector2(outer.size.x, 16)), Rect2(Vector2(outer.position.x, outer.end.y), Vector2(outer.size.x, 16))]:
        var shape := CollisionShape2D.new()
        var box := RectangleShape2D.new()
        box.size = edge.size
        shape.shape = box
        shape.position = edge.get_center()
        collision.add_child(shape)
    add_child(collision)
    props = Node2D.new()
    props.name = "WorldProps"
    props.y_sort_enabled = true
    add_child(props)
    _place_props()

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
        return [DIRT_GRASS[0], CORNER_LAYOUT[code] + Vector2i(0, DIRT_GRASS[1])]
    return []

static func _variant(list: Array, x: int, y: int) -> Vector2i:
    return list[(x * 7 + y * 13 + x * y) % 23 % list.size()]

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
    for y in range(MAP.ROWS):
        for x in range(MAP.COLS):
            var cell := Vector2i(x, y) + offset
            var feature := feature_for(x, y)
            if not feature.is_empty():
                features.set_cell(cell, feature[0], feature[1])
            if feature.is_empty() or feature[1] != CORNER_LAYOUT[15] + Vector2i(0, SHORE_SAND[1]) or feature[0] != SHORE_SAND[0]:
                _land(x, y, cell)
            if map.bridge[MAP.tile_index(x, y)] == 1:
                bridges.set_cell(cell, Source.WATER, BRIDGE_TILE)

## Land under (x, y): ash or sand base, then rounded grass/autumn and forest overlays.
func _land(x: int, y: int, cell: Vector2i) -> void:
    var green := _ground_code(x, y, [MAP.Ground.GRASS, MAP.Ground.FOREST])
    var autumn := _ground_code(x, y, [MAP.Ground.AUTUMN])
    var ash := _ground_code(x, y, [MAP.Ground.ASH])
    var forest := _ground_code(x, y, [MAP.Ground.FOREST])
    if ash > 0:
        ground.set_cell(cell, Source.LAVA, Vector2i(0, 5))
    elif green < 15 and autumn < 15:
        ground.set_cell(cell, Source.WATER, Vector2i(0, 5))
    for overlay in [[green, 1], [autumn, 3]]:
        var code: int = overlay[0]
        if code == 0:
            continue
        var patch: Array = PATCHES[overlay[1]]
        if code == 15:
            if overlay[1] == 1 and forest == 15:
                continue
            var plain: Array = PLAIN[overlay[1]]
            blend.set_cell(cell, plain[0], _variant(plain[1], x, y))
        else:
            blend.set_cell(cell, Source.FIELD, patch[0] + PATCH_LAYOUT[code])
    if forest == 15:
        var plain: Array = PLAIN[MAP.Ground.FOREST]
        canopy.set_cell(cell, plain[0], _variant(plain[1], x, y))
    elif forest > 0:
        canopy.set_cell(cell, Source.FIELD, PATCHES[2][0] + PATCH_LAYOUT[forest])

func _prop(id: String, foot: Vector2) -> void:
    _prop_cache.append([id, foot])

func _spawn_prop(id: String, foot: Vector2) -> void:
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

## Deterministic scatter by ground type, kept off the clearing, paths, shores and landmarks.
func _place_props() -> void:
    if _prop_cache.is_empty():
        _plan_props()
    for entry in _prop_cache:
        _spawn_prop(entry[0], entry[1])

func _plan_props() -> void:
    var map: Dictionary = MAP.data()
    for landmark in LANDMARKS:
        _prop(landmark[0], MAP.to_world(landmark[1]))
    var rng := RandomNumberGenerator.new()
    rng.seed = PROP_SEED
    var keep_out := Rect2(MAP.CLEARING.position - Vector2i(3, 3), MAP.CLEARING.size + Vector2i(6, 6))
    var crater: Vector2 = MAP.AREAS[1][0]
    for angle_step in range(14):
        var at := crater + Vector2.from_angle(angle_step * TAU / 14.0) * Vector2(11, 8)
        _prop("boulder", MAP.to_world(at.round()))
    for cy in range(2, MAP.ROWS - 2, 3):
        for cx in range(2, MAP.COLS - 2, 3):
            var tile := Vector2i(cx + rng.randi_range(0, 2), cy + rng.randi_range(0, 2))
            var roll := rng.randf()
            var pick := rng.randi_range(0, 99)
            if keep_out.has_point(tile) or not _clear_ground(map, tile):
                continue
            var kind: int = map.ground[MAP.vertex_index(tile.x, tile.y)]
            var region: int = map.region[MAP.tile_index(tile.x, tile.y)]
            var id := ""
            match kind:
                MAP.Ground.FOREST:
                    if roll < 0.7:
                        id = ["pine", "pine", "tree_big", "tree_round"][pick % 4]
                MAP.Ground.GRASS:
                    if roll < 0.1:
                        id = ["tree_big", "tree_round", "bush", "bush"][pick % 4]
                MAP.Ground.AUTUMN:
                    if roll < 0.22:
                        id = ["tree_autumn", "tree_autumn", "bush"][pick % 3]
                MAP.Ground.ASH:
                    if region == MAP.Region.EMBERREACH and roll < 0.3:
                        id = ["tree_dead", "boulder", "pebbles"][pick % 3]
                    elif roll < 0.25:
                        id = ["boulder", "pebbles", "pebbles", "tree_dead"][pick % 4]
                MAP.Ground.SAND:
                    if roll < 0.015:
                        id = "bush"
            if not id.is_empty() and not _near_landmark(tile):
                _prop(id, MAP.to_world(Vector2(tile) + Vector2(0.5, 1.0)))

## Land around the tile, away from water, lava, paths and bridges.
func _clear_ground(map: Dictionary, tile: Vector2i) -> bool:
    for dy in range(-1, 3):
        for dx in range(-1, 2):
            var x := clampi(tile.x + dx, 0, MAP.COLS)
            var y := clampi(tile.y + dy, 0, MAP.ROWS)
            var vertex := MAP.vertex_index(x, y)
            if map.ocean[vertex] == 1 or map.lake[vertex] == 1 or map.lava[vertex] == 1 or map.dirt[vertex] == 1:
                return false
            if x < MAP.COLS and y < MAP.ROWS and map.bridge[MAP.tile_index(x, y)] == 1:
                return false
    return true

func _near_landmark(tile: Vector2i) -> bool:
    for landmark in LANDMARKS:
        if Vector2(tile).distance_to(landmark[1]) < 5.0:
            return true
    return Vector2(tile).distance_to(MAP.AREAS[1][0]) < 9.0
