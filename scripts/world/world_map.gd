extends RefCounted
## The archipelago (M4.5a): a fixed, hand-designed world map (original regions, loosely inspired
## by the user's Siagarta reference) built on a 16 px tile grid. The First Clearing keeps its exact
## coordinates (0,0)-(960,640); the world spans ORIGIN..ORIGIN+SIZE around it, so saved positions
## from older versions stay valid.
##
## Terrain is defined on the grid's vertices (corners of tiles). A tile is drawn from its four
## corners with the 16-combination corner sets of the Ninja Adventure sheets (dual grid), which
## gives rounded coasts, lake shores, lava pools and paths. The same data decides collisions, the
## region names and the world map, and it is identical on every machine (no randomness besides
## a fixed noise seed), so hosts and friends always see the same world.
const TILE := 16
const COLS := 400
const ROWS := 256
const ORIGIN := Vector2(-2560, -1536)
const SIZE := Vector2(COLS * TILE, ROWS * TILE)
## The First Clearing in tiles (its own scene content, roads and obstacles stay as before).
const CLEARING := Rect2i(160, 96, 60, 40)
const NOISE_SEED := 4410

enum Ground {SAND, GRASS, FOREST, AUTUMN, ASH}
enum Region {SEA, CLEARING, THORNWOOD, MIRROR_LAKE, CINDER_CRATER, VERDANT, HARROWMERE, AMBERVALE, EMBERREACH}
const REGION_NAMES := {
    Region.SEA: "The Sapphire Sea",
    Region.CLEARING: "The First Clearing",
    Region.THORNWOOD: "Thornwood",
    Region.MIRROR_LAKE: "Mirror Lake",
    Region.CINDER_CRATER: "Cinder Crater",
    Region.VERDANT: "Verdant Isle",
    Region.HARROWMERE: "Harrowmere",
    Region.AMBERVALE: "Ambervale",
    Region.EMBERREACH: "Emberreach Isles",
}
## Reachable on foot now; the others need the ferries/ships of a later M4.5 step.
const REACHABLE := [Region.CLEARING, Region.THORNWOOD, Region.MIRROR_LAKE, Region.CINDER_CRATER, Region.VERDANT, Region.HARROWMERE]

## Land masses: [centre (tiles), radii (tiles), region]. A vertex is land when its distance to a
## blob (ellipse norm) plus coast noise is below 1.
const LAND := [
    [Vector2(182, 118), Vector2(104, 80), Region.VERDANT],
    [Vector2(250, 70), Vector2(42, 34), Region.VERDANT],
    [Vector2(255, 165), Vector2(44, 40), Region.VERDANT],
    [Vector2(96, 118), Vector2(44, 52), Region.VERDANT],
    [Vector2(346, 92), Vector2(28, 24), Region.HARROWMERE],
    [Vector2(180, 304), Vector2(250, 74), Region.AMBERVALE],
    [Vector2(356, 182), Vector2(16, 11), Region.EMBERREACH],
    [Vector2(379, 204), Vector2(11, 8), Region.EMBERREACH],
    [Vector2(340, 214), Vector2(9, 6), Region.EMBERREACH],
    [Vector2(386, 166), Vector2(8, 6), Region.EMBERREACH],
]
## Sub-regions on land: [centre, radii, region, ground].
const AREAS := [
    [Vector2(104, 84), Vector2(42, 38), Region.THORNWOOD, Ground.FOREST],
    [Vector2(256, 166), Vector2(30, 26), Region.CINDER_CRATER, Ground.ASH],
]
const LAKE := [Vector2(246, 72), Vector2(24, 15)]
const LAKE_ISLET := [Vector2(246, 70), Vector2(6, 4)]
const LAVA_POOLS := [[Vector2(356, 181), Vector2(6, 4)], [Vector2(379, 204), Vector2(3, 2)], [Vector2(256, 166), Vector2(5, 4)]]
## Dirt paths (tile polylines) continuing the clearing's roads: west into Thornwood, east to the
## Harrowmere bridge, south to Sunfall Beach, and around Mirror Lake to its bridge.
const PATHS := [
    [Vector2(160, 116.5), Vector2(132, 116.5), Vector2(112, 104), Vector2(96, 96)],
    [Vector2(220, 116.5), Vector2(246, 116.5), Vector2(266, 104), Vector2(284, 91.5)],
    [Vector2(190, 136), Vector2(191, 168), Vector2(186, 192)],
    [Vector2(246, 116.5), Vector2(246, 89)],
]
const PATH_HALF_WIDTH := 1.6
## Bridges (tile rects, walkable over water).
const BRIDGES := [Rect2i(282, 90, 40, 3), Rect2i(245, 74, 3, 14)]
const BEACH := 2

static var _cache: Dictionary = {}
static var _rects: Array = []

static func vertex_index(x: int, y: int) -> int:
    return y * (COLS + 1) + x

static func tile_index(x: int, y: int) -> int:
    return y * COLS + x

static func to_world(tile: Vector2) -> Vector2:
    return ORIGIN + tile * TILE

static func to_tile(world: Vector2) -> Vector2i:
    return Vector2i(((world - ORIGIN) / TILE).floor())

static func bounds() -> Rect2:
    return Rect2(ORIGIN, SIZE)

static func _norm(point: Vector2, centre: Vector2, radii: Vector2) -> float:
    var d := (point - centre) / radii
    return d.length_squared()

static func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
    var ab := b - a
    var t := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
    return point.distance_to(a + ab * t)

## The whole map (built once per process; identical everywhere).
static func data() -> Dictionary:
    if not _cache.is_empty():
        return _cache
    var noise := FastNoiseLite.new()
    noise.seed = NOISE_SEED
    noise.frequency = 0.045
    noise.fractal_octaves = 3
    var vertex_count := (COLS + 1) * (ROWS + 1)
    var ocean := PackedByteArray()
    ocean.resize(vertex_count)
    var lake := PackedByteArray()
    lake.resize(vertex_count)
    var lava := PackedByteArray()
    lava.resize(vertex_count)
    var dirt := PackedByteArray()
    dirt.resize(vertex_count)
    var ground := PackedByteArray()
    ground.resize(vertex_count)
    var land_region := PackedByteArray()
    land_region.resize(vertex_count)
    var clearing := Rect2(CLEARING.position - Vector2i(6, 6), CLEARING.size + Vector2i(12, 12))
    var layout := preload("res://scripts/world/world_layout.gd")
    for y in range(ROWS + 1):
        for x in range(COLS + 1):
            var point := Vector2(x, y)
            var index := vertex_index(x, y)
            var wobble := noise.get_noise_2d(x, y) * 0.35
            var region := -1
            for blob in LAND:
                if _norm(point, blob[0], blob[1]) + wobble < 1.0:
                    region = blob[2]
                    break
            if clearing.has_point(point):
                region = Region.VERDANT
            if region < 0:
                ocean[index] = 1
                continue
            land_region[index] = region
            ground[index] = Ground.AUTUMN if region == Region.AMBERVALE else (Ground.ASH if region == Region.EMBERREACH else Ground.GRASS)
            for area in AREAS:
                if _norm(point, area[0], area[1]) + wobble * 0.6 < 1.0:
                    ground[index] = area[3]
                    land_region[index] = area[2]
            if _norm(point, LAKE[0], LAKE[1]) + wobble * 0.4 < 1.0 and _norm(point, LAKE_ISLET[0], LAKE_ISLET[1]) >= 1.0:
                lake[index] = 1
                land_region[index] = Region.MIRROR_LAKE
            # The clearing's pond (its own collision rectangle; water drawn just inside it).
            if layout.POND.grow(-1).has_point(to_world(point)):
                lake[index] = 1
            for pool in LAVA_POOLS:
                if _norm(point, pool[0], pool[1]) + wobble * 0.5 < 1.0:
                    lava[index] = 1
    # Beaches: land vertices within BEACH of the ocean are sand (never inside the clearing).
    # Separable dilation of the ocean mask keeps this fast.
    var rows_near := PackedByteArray()
    rows_near.resize(vertex_count)
    for y in range(ROWS + 1):
        for x in range(COLS + 1):
            for dx in range(-BEACH, BEACH + 1):
                if ocean[vertex_index(clampi(x + dx, 0, COLS), y)] == 1:
                    rows_near[vertex_index(x, y)] = 1
                    break
    for y in range(ROWS + 1):
        for x in range(COLS + 1):
            var index := vertex_index(x, y)
            if ocean[index] == 1 or ground[index] == Ground.ASH or clearing.has_point(Vector2(x, y)):
                continue
            for dy in range(-BEACH, BEACH + 1):
                if rows_near[vertex_index(x, clampi(y + dy, 0, ROWS))] == 1:
                    ground[index] = Ground.SAND
                    break
    # Paths: the clearing's roads (vertices inside its road rects) plus the polylines (only
    # checked near their bounding boxes).
    var boxes: Array = []
    for line in PATHS:
        var box := Rect2(line[0], Vector2.ZERO)
        for point in line:
            box = box.expand(point)
        boxes.append(box.grow(PATH_HALF_WIDTH + 1))
    for y in range(ROWS + 1):
        for x in range(COLS + 1):
            var index := vertex_index(x, y)
            if ocean[index] == 1 or lake[index] == 1:
                continue
            var world := to_world(Vector2(x, y))
            var on_path := false
            for road in layout.ROADS:
                on_path = on_path or road.grow(1).has_point(world)
            for line_index in range(PATHS.size()):
                if on_path or not boxes[line_index].has_point(Vector2(x, y)):
                    continue
                var line: Array = PATHS[line_index]
                for segment in range(line.size() - 1):
                    on_path = on_path or _segment_distance(Vector2(x, y), line[segment], line[segment + 1]) <= PATH_HALF_WIDTH
            if on_path and ground[index] != Ground.SAND:
                dirt[index] = 1
    # Per-tile: bridge flags and region (by the tile's top-left vertex, clearing first).
    var bridge := PackedByteArray()
    bridge.resize(COLS * ROWS)
    var region_tiles := PackedByteArray()
    region_tiles.resize(COLS * ROWS)
    for y in range(ROWS):
        for x in range(COLS):
            var index := tile_index(x, y)
            for rect in BRIDGES:
                if rect.has_point(Vector2i(x, y)):
                    bridge[index] = 1
            var vertex := vertex_index(x, y)
            region_tiles[index] = Region.CLEARING if CLEARING.has_point(Vector2i(x, y)) else (Region.SEA if ocean[vertex] == 1 and bridge[index] == 0 else land_region[vertex])
    _cache = {"ocean": ocean, "lake": lake, "lava": lava, "dirt": dirt, "ground": ground, "bridge": bridge, "region": region_tiles}
    return _cache

## 4-bit corner code of a vertex mask for tile (x, y): top-left 8, top-right 4, bottom-left 2,
## bottom-right 1.
static func corners(mask: PackedByteArray, x: int, y: int) -> int:
    return mask[vertex_index(x, y)] * 8 + mask[vertex_index(x + 1, y)] * 4 + mask[vertex_index(x, y + 1)] * 2 + mask[vertex_index(x + 1, y + 1)]

## Tiles nobody can walk on: three or more corners water/lava, unless bridged. The clearing
## keeps its own collisions (pond, rocks, trees) and is never blocked by the map.
static func solid(x: int, y: int) -> bool:
    var map := data()
    if CLEARING.has_point(Vector2i(x, y)) or map.bridge[tile_index(x, y)] == 1:
        return false
    var wet := 0
    for mask in [map.ocean, map.lake, map.lava]:
        wet = maxi(wet, _count(corners(mask, x, y)))
    return wet >= 3

static func _count(code: int) -> int:
    return (code >> 3 & 1) + (code >> 2 & 1) + (code >> 1 & 1) + (code & 1)

static func region_at(world: Vector2) -> int:
    var tile := to_tile(world)
    if tile.x < 0 or tile.y < 0 or tile.x >= COLS or tile.y >= ROWS:
        return Region.SEA
    return data().region[tile_index(tile.x, tile.y)]

static func region_name(world: Vector2) -> String:
    return REGION_NAMES[region_at(world)]

## Merged collision rectangles (world pixels) for every solid tile: runs per row, then rows
## with identical runs stacked into one rectangle.
static func solid_rects() -> Array:
    if not _rects.is_empty():
        return _rects
    var open: Dictionary = {}
    var rects: Array = []
    for y in range(ROWS):
        var runs: Dictionary = {}
        var x := 0
        while x < COLS:
            if solid(x, y):
                var start := x
                while x < COLS and solid(x, y):
                    x += 1
                runs[Vector2i(start, x)] = true
            else:
                x += 1
        var next: Dictionary = {}
        for run in runs:
            next[run] = open.get(run, y)
        for run in open:
            if not runs.has(run):
                rects.append(Rect2(to_world(Vector2(run.x, open[run])), Vector2(run.y - run.x, y - open[run]) * TILE))
        open = next
    for run in open:
        rects.append(Rect2(to_world(Vector2(run.x, open[run])), Vector2(run.y - run.x, ROWS - open[run]) * TILE))
    _rects = rects
    return rects
