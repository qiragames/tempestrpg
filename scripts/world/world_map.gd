extends RefCounted
## The archipelago (M4.5a, grown about 9x in M4.5c): a fixed, hand-designed world map (original
## regions, loosely inspired by the user's Siagarta reference) built on a 16 px tile grid. The
## First Clearing keeps its exact coordinates (0,0)-(960,640), and every tile coordinate written
## before M4.5c keeps its meaning: tile (0, 0) is still at ORIGIN, the grid simply extends to
## negative tiles (MIN) and beyond the old edge, so saved positions and content stay valid.
##
## Terrain is defined on the grid's vertices (corners of tiles). A tile is drawn from its four
## corners with the 16-combination corner sets of the Ninja Adventure sheets (dual grid), which
## gives rounded coasts, lake shores, lava pools and paths. The same data decides collisions, the
## region names and the world map, and it is identical on every machine (no randomness besides
## a fixed noise seed), so hosts and friends always see the same world. Building it takes several
## seconds, so it ships precomputed in WorldCache (rebuilt with tools/build_world_cache.gd).
const TILE := 16
## First tile of the grid (in the tile frame used since M4.5a) and the grid size.
const MIN := Vector2i(-400, -256)
const COLS := 1200
const ROWS := 768
## World position of tile (0, 0) (unchanged since M4.5a).
const ORIGIN := Vector2(-2560, -1536)
const SIZE := Vector2(COLS * TILE, ROWS * TILE)
## The First Clearing in tiles (its own scene content, roads and obstacles stay as before).
const CLEARING := Rect2i(160, 96, 60, 40)
const NOISE_SEED := 4410

enum Ground {SAND, GRASS, FOREST, AUTUMN, ASH, SNOW, BLOSSOM, MUD}
enum Region {SEA, CLEARING, THORNWOOD, MIRROR_LAKE, CINDER_CRATER, VERDANT, HARROWMERE, AMBERVALE, EMBERREACH, FROSTPEAK, SUNSCORCH, SAKURA_VALE, MIREWOOD}
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
    Region.FROSTPEAK: "Frostpeak",
    Region.SUNSCORCH: "Sunscorch Desert",
    Region.SAKURA_VALE: "Sakura Vale",
    Region.MIREWOOD: "Mirewood Marsh",
}
## The home continent (user decision, M4.5c): Verdant Isle joined by land to Frostpeak and the
## Sunscorch Desert, plus Harrowmere over its bridge — all reachable on foot. The southern
## continent (Ambervale and Mirewood Marsh), Sakura Vale and the Emberreach Isles are reached by
## ferry from the harbours (HARBOURS).
const REACHABLE := [Region.CLEARING, Region.THORNWOOD, Region.MIRROR_LAKE, Region.CINDER_CRATER, Region.VERDANT, Region.HARROWMERE, Region.FROSTPEAK, Region.SUNSCORCH]
const BY_FERRY := [Region.AMBERVALE, Region.MIREWOOD, Region.SAKURA_VALE, Region.EMBERREACH]
## Ground of each region's open land.
const REGION_GROUND := {
    Region.VERDANT: Ground.GRASS, Region.HARROWMERE: Ground.GRASS, Region.AMBERVALE: Ground.AUTUMN, Region.EMBERREACH: Ground.ASH,
    Region.FROSTPEAK: Ground.SNOW, Region.SUNSCORCH: Ground.SAND, Region.SAKURA_VALE: Ground.BLOSSOM, Region.MIREWOOD: Ground.MUD,
}

## Land masses: [centre (tiles), radii (tiles), region]. A vertex is land when its distance to a
## blob (ellipse norm) plus coast noise is below 1; the first matching blob names it.
const LAND := [
    [Vector2(182, 118), Vector2(104, 80), Region.VERDANT],
    [Vector2(250, 70), Vector2(42, 34), Region.VERDANT],
    [Vector2(255, 165), Vector2(44, 40), Region.VERDANT],
    [Vector2(96, 118), Vector2(44, 52), Region.VERDANT],
    [Vector2(348, 94), Vector2(34, 28), Region.HARROWMERE],
    [Vector2(356, 182), Vector2(16, 11), Region.EMBERREACH],
    [Vector2(379, 204), Vector2(11, 8), Region.EMBERREACH],
    [Vector2(340, 214), Vector2(9, 6), Region.EMBERREACH],
    [Vector2(386, 166), Vector2(8, 6), Region.EMBERREACH],
    [Vector2(560, 330), Vector2(110, 80), Region.EMBERREACH],
    [Vector2(180, 320), Vector2(250, 90), Region.AMBERVALE],
    [Vector2(190, -95), Vector2(230, 95), Region.FROSTPEAK],
    [Vector2(-140, 110), Vector2(150, 140), Region.SUNSCORCH],
    [Vector2(-170, 380), Vector2(140, 95), Region.MIREWOOD],
    [Vector2(540, 40), Vector2(140, 120), Region.SAKURA_VALE],
    # The home continent (user feedback via SVE): Verdant, Frostpeak and the desert grow into
    # each other over what was open sea between them, merging like Ambervale and the marsh do.
    [Vector2(150, 30), Vector2(80, 56), Region.VERDANT],
    [Vector2(60, 80), Vector2(70, 62), Region.VERDANT],
    [Vector2(90, -20), Vector2(150, 56), Region.FROSTPEAK],
    [Vector2(-30, 50), Vector2(100, 90), Region.SUNSCORCH],
    [Vector2(-60, -40), Vector2(90, 50), Region.SUNSCORCH],
    # Lobes and peninsulas so the coasts are not plain ellipses.
    [Vector2(40, -170), Vector2(64, 40), Region.FROSTPEAK],
    [Vector2(372, -40), Vector2(44, 28), Region.FROSTPEAK],
    [Vector2(-300, 30), Vector2(64, 52), Region.SUNSCORCH],
    [Vector2(-50, 214), Vector2(52, 38), Region.SUNSCORCH],
    [Vector2(610, -70), Vector2(64, 40), Region.SAKURA_VALE],
    [Vector2(-300, 450), Vector2(60, 36), Region.MIREWOOD],
    [Vector2(330, 410), Vector2(90, 34), Region.AMBERVALE],
    [Vector2(640, 400), Vector2(50, 40), Region.EMBERREACH],
    # Islets out at sea.
    [Vector2(705, 200), Vector2(14, 10), Region.SAKURA_VALE],
    [Vector2(-356, 236), Vector2(11, 8), Region.SUNSCORCH],
    [Vector2(450, -190), Vector2(13, 8), Region.FROSTPEAK],
    [Vector2(720, 470), Vector2(12, 9), Region.EMBERREACH],
    [Vector2(30, 470), Vector2(18, 10), Region.AMBERVALE],
    [Vector2(-330, -160), Vector2(16, 10), Region.FROSTPEAK],
]
## Sub-regions on land: [centre, radii, region, ground].
const AREAS := [
    [Vector2(104, 84), Vector2(42, 38), Region.THORNWOOD, Ground.FOREST],
    [Vector2(256, 166), Vector2(30, 26), Region.CINDER_CRATER, Ground.ASH],
]
const LAKE := [Vector2(246, 72), Vector2(24, 15)]
const LAKE_ISLET := [Vector2(246, 70), Vector2(6, 4)]
## Further lakes and pools: [centre, radii] (Mirror Lake above keeps its own region and islet).
const LAKES := [
    [Vector2(100, -120), Vector2(20, 10)], [Vector2(300, -60), Vector2(10, 6)],
    [Vector2(-170, 62), Vector2(7, 5)],
    [Vector2(-220, 350), Vector2(10, 6)], [Vector2(-120, 412), Vector2(8, 5)], [Vector2(-205, 432), Vector2(9, 5)], [Vector2(-262, 398), Vector2(6, 4)],
    [Vector2(60, 352), Vector2(14, 8)],
    [Vector2(605, -18), Vector2(10, 6)],
]
const LAVA_POOLS := [
    [Vector2(356, 181), Vector2(6, 4)], [Vector2(379, 204), Vector2(3, 2)], [Vector2(256, 166), Vector2(5, 4)],
    [Vector2(595, 352), Vector2(8, 5)], [Vector2(520, 372), Vector2(5, 3)], [Vector2(612, 290), Vector2(4, 3)],
]
## Dirt paths (tile polylines): the clearing's roads continue west into Thornwood and on to the
## desert bridge, east to Harrowmere and Sakura Vale, north to Frostpeak and south to Sunfall
## Beach and Ambervale; every town and village is linked to them.
const PATHS := [
    [Vector2(160, 116.5), Vector2(132, 116.5), Vector2(112, 104), Vector2(96, 96)],
    [Vector2(220, 116.5), Vector2(246, 116.5), Vector2(266, 104), Vector2(284, 91.5)],
    [Vector2(190, 136), Vector2(191, 168), Vector2(186, 192)],
    [Vector2(246, 116.5), Vector2(246, 89)],
    # Verdant Isle's town and villages.
    [Vector2(132, 116.5), Vector2(120, 136), Vector2(110, 150)],
    [Vector2(96, 96), Vector2(78, 108)],
    [Vector2(246, 89), Vector2(232, 70), Vector2(225, 58)],
    [Vector2(191, 168), Vector2(214, 176), Vector2(232, 176)],
    [Vector2(186, 192), Vector2(186, 194)],
    # North to Frostpeak.
    [Vector2(232, 116.5), Vector2(210, 95), Vector2(200.5, 62)],
    [Vector2(200.5, 62), Vector2(200, 10), Vector2(195, -70)],
    [Vector2(195, -70), Vector2(120, -88), Vector2(60, -100)],
    [Vector2(195, -70), Vector2(270, -100), Vector2(330, -120)],
    [Vector2(330, -120), Vector2(327, -165)],
    # West to the Sunscorch Desert and south to Mirewood Marsh.
    [Vector2(132, 116.5), Vector2(60, 117.5), Vector2(-4, 117.5), Vector2(-60, 118), Vector2(-120, 120)],
    [Vector2(-120, 120), Vector2(-165, 72)],
    [Vector2(-120, 120), Vector2(-180, 170), Vector2(-220, 190)],
    [Vector2(-120, 120), Vector2(-150, 200), Vector2(-154, 244)],
    [Vector2(-150, 292), Vector2(-170, 370)],
    [Vector2(-170, 370), Vector2(-250, 320)],
    [Vector2(-170, 370), Vector2(-100, 440)],
    [Vector2(-170, 370), Vector2(-90, 330), Vector2(-40, 320), Vector2(40, 300)],
    # South to Ambervale and on to the Emberreach Isles.
    [Vector2(195, 235), Vector2(180, 320)],
    [Vector2(40, 300), Vector2(110, 312), Vector2(180, 320)],
    [Vector2(180, 320), Vector2(260, 340), Vector2(320, 350)],
    [Vector2(320, 350), Vector2(380, 320), Vector2(424, 304)],
    [Vector2(456, 304), Vector2(500, 290), Vector2(555, 320)],
    [Vector2(555, 320), Vector2(568, 362), Vector2(620, 370)],
    # East from Harrowmere to Sakura Vale.
    [Vector2(322, 91.5), Vector2(378, 94)],
    [Vector2(416, 70), Vector2(490, 60), Vector2(545, 40)],
    [Vector2(545, 40), Vector2(480, -30)],
    [Vector2(545, 40), Vector2(600, 110)],
    # Up to Sakura Vale's hilltop shrine.
    [Vector2(545, 40), Vector2(575, 4), Vector2(600, -40)],
]
const PATH_HALF_WIDTH := 1.6
## Bridges (tile rects, walkable over water).
const BRIDGES := [
    Rect2i(282, 90, 40, 3), Rect2i(245, 74, 3, 14),
    Rect2i(-84, 318, 36, 3),
]
## Harbours (M4.5c piers, M4.5d proper harbours in every region): [id, name, dock tile (on the
## shore), pier direction, has a shipwright]. Each has a pier, a ferryman selling tickets and
## passes to every other harbour, and a berth where an owner's ship can be summoned.
const HARBOURS := [
    ["sunfall", "Sunfall Harbour", Vector2(186, 194), Vector2i.DOWN, false],
    ["harrowmere", "Harrowmere Harbour", Vector2(378, 94), Vector2i.RIGHT, true],
    ["rimehaven", "Rimehaven", Vector2(327, -165), Vector2i.UP, false],
    ["dunemarch", "Dunemarch Harbour", Vector2(-154, 244), Vector2i.DOWN, false],
    ["amberhold", "Amberhold Harbour", Vector2(195, 235), Vector2i.UP, true],
    ["copperleaf", "Copperleaf Harbour", Vector2(424, 304), Vector2i.RIGHT, false],
    ["bogsend", "Bogsend Harbour", Vector2(-150, 292), Vector2i.UP, false],
    ["hanamura", "Hanamura Harbour", Vector2(416, 70), Vector2i.LEFT, false],
    ["cinderport", "Cinderport Harbour", Vector2(456, 304), Vector2i.LEFT, true],
]
const PIER_LENGTH := 6
const BEACH := 2
## Verticality (M4.5c, user request): raised plateaus and peaks — [centre, radii, level]. A
## plateau's rim is a ledge nobody can climb, and its south face is a two-tile rock wall; roads
## crossing a rim are ramps (stairs on the wall). Nested entries make higher levels.
const HIGHLANDS := [
    [Vector2(190, -150), Vector2(118, 38), 1], [Vector2(180, -158), Vector2(48, 16), 2],
    [Vector2(330, -40), Vector2(30, 16), 1],
    [Vector2(-200, 0), Vector2(40, 24), 1], [Vector2(-290, 60), Vector2(28, 20), 1], [Vector2(-40, 196), Vector2(30, 18), 1],
    [Vector2(60, 40), Vector2(40, 22), 1],
    [Vector2(600, -50), Vector2(38, 24), 1],
    [Vector2(100, 372), Vector2(40, 18), 1], [Vector2(262, 290), Vector2(40, 16), 1],
    [Vector2(592, 352), Vector2(40, 28), 1], [Vector2(594, 352), Vector2(20, 13), 2],
]
const MAX_LEVEL := 2

## Towns and villages (M4.5c): [id, name, region, centre tile, kind, theme]. Each has a dirt
## plaza; WorldTerrain places theme-fitting buildings around it, and the region's merchant
## stands in its town.
const TOWNS := [
    ["brookhaven", "Brookhaven", Region.VERDANT, Vector2(110, 150), "town", "verdant"],
    ["thornhollow", "Thornhollow", Region.THORNWOOD, Vector2(78, 108), "village", "verdant"],
    ["mirrorwick", "Mirrorwick", Region.VERDANT, Vector2(225, 58), "village", "verdant"],
    ["ashgate", "Ashgate", Region.CINDER_CRATER, Vector2(232, 176), "village", "ember"],
    ["harrowmere", "Harrowmere", Region.HARROWMERE, Vector2(347, 93), "town", "harrow"],
    ["saltwick", "Saltwick", Region.HARROWMERE, Vector2(330, 108), "village", "verdant"],
    ["rimeholm", "Rimeholm", Region.FROSTPEAK, Vector2(195, -70), "town", "frost"],
    ["snowdrift", "Snowdrift", Region.FROSTPEAK, Vector2(60, -100), "village", "frost"],
    ["glacierwatch", "Glacierwatch", Region.FROSTPEAK, Vector2(330, -120), "village", "frost"],
    ["dunemarch", "Dunemarch", Region.SUNSCORCH, Vector2(-120, 120), "town", "desert"],
    ["oasis_rest", "Oasis Rest", Region.SUNSCORCH, Vector2(-165, 76), "village", "desert"],
    ["saltpan", "Saltpan", Region.SUNSCORCH, Vector2(-220, 190), "village", "desert"],
    ["bogsend", "Bogsend", Region.MIREWOOD, Vector2(-170, 370), "town", "marsh"],
    ["reedmoor", "Reedmoor", Region.MIREWOOD, Vector2(-250, 320), "village", "marsh"],
    ["fenwick", "Fenwick", Region.MIREWOOD, Vector2(-100, 440), "village", "marsh"],
    ["amberhold", "Amberhold", Region.AMBERVALE, Vector2(180, 320), "town", "amber"],
    ["harvest_hill", "Harvest Hill", Region.AMBERVALE, Vector2(40, 300), "village", "amber"],
    ["copperleaf", "Copperleaf", Region.AMBERVALE, Vector2(320, 350), "village", "amber"],
    ["cinderport", "Cinderport", Region.EMBERREACH, Vector2(555, 320), "town", "ember"],
    ["slagwatch", "Slagwatch", Region.EMBERREACH, Vector2(500, 290), "village", "ember"],
    ["ashfall", "Ashfall", Region.EMBERREACH, Vector2(620, 370), "village", "ember"],
    ["hanamura", "Hanamura", Region.SAKURA_VALE, Vector2(545, 40), "town", "sakura"],
    ["bamboo_hollow", "Bamboo Hollow", Region.SAKURA_VALE, Vector2(480, -30), "village", "sakura"],
    ["koi_pond", "Koi Pond", Region.SAKURA_VALE, Vector2(600, 110), "village", "sakura"],
]
## Plaza radius (tiles) and the radius within which the HUD names the place.
const PLAZA := {"town": 4.5, "village": 2.5}
const PLACE_RADIUS := {"town": 16.0, "village": 9.0}

static var _cache: Dictionary = {}
static var _rects: Array = []
## Set false by the cache builder to force a fresh computation.
static var use_cache := true

static func vertex_index(x: int, y: int) -> int:
    return (y - MIN.y) * (COLS + 1) + (x - MIN.x)

static func tile_index(x: int, y: int) -> int:
    return (y - MIN.y) * COLS + (x - MIN.x)

## Whether a tile lies on the grid.
static func in_grid(tile: Vector2i) -> bool:
    return tile.x >= MIN.x and tile.y >= MIN.y and tile.x < MIN.x + COLS and tile.y < MIN.y + ROWS

static func to_world(tile: Vector2) -> Vector2:
    return ORIGIN + tile * TILE

static func to_tile(world: Vector2) -> Vector2i:
    return Vector2i(((world - ORIGIN) / TILE).floor())

static func bounds() -> Rect2:
    return Rect2(ORIGIN + Vector2(MIN) * TILE, SIZE)

static func _norm(point: Vector2, centre: Vector2, radii: Vector2) -> float:
    var d := (point - centre) / radii
    return d.length_squared()

static func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
    var ab := b - a
    var t := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
    return point.distance_to(a + ab * t)

## Vertex range (clamped to the grid) covering a box around `centre`.
static func _span(centre: Vector2, half: Vector2) -> Rect2i:
    var from := Vector2i((centre - half).floor()).max(MIN)
    var to := Vector2i((centre + half).ceil()).min(MIN + Vector2i(COLS, ROWS))
    return Rect2i(from, to - from + Vector2i.ONE)

## The whole map (built once per process; identical everywhere). Loaded from WorldCache when it
## matches the current sources, computed otherwise.
static func data() -> Dictionary:
    if not _cache.is_empty():
        return _cache
    if use_cache:
        var cached: Variant = preload("res://scripts/world/world_cache.gd").load_part("map")
        if cached is Dictionary or cached is Array:
            _cache = cached
            return _cache
    _cache = compute()
    return _cache

static func compute() -> Dictionary:
    var noise := FastNoiseLite.new()
    noise.seed = NOISE_SEED
    noise.frequency = 0.045
    noise.fractal_octaves = 3
    var vertex_count := (COLS + 1) * (ROWS + 1)
    var wobble := PackedFloat32Array()
    wobble.resize(vertex_count)
    for y in range(MIN.y, MIN.y + ROWS + 1):
        for x in range(MIN.x, MIN.x + COLS + 1):
            wobble[vertex_index(x, y)] = noise.get_noise_2d(x, y) * 0.35
    var ocean := PackedByteArray()
    ocean.resize(vertex_count)
    ocean.fill(1)
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
    # Land: blobs in order, each only over its own box (the first match names the vertex).
    for blob in LAND:
        var span := _span(blob[0], blob[1] * 1.2 + Vector2(2, 2))
        for y in range(span.position.y, span.end.y):
            for x in range(span.position.x, span.end.x):
                var index := vertex_index(x, y)
                if ocean[index] == 1 and _norm(Vector2(x, y), blob[0], blob[1]) + wobble[index] < 1.0:
                    ocean[index] = 0
                    land_region[index] = blob[2]
                    ground[index] = REGION_GROUND[blob[2]]
    var clearing := Rect2i(CLEARING.position - Vector2i(6, 6), CLEARING.size + Vector2i(12, 12))
    for y in range(clearing.position.y, clearing.end.y):
        for x in range(clearing.position.x, clearing.end.x):
            var index := vertex_index(x, y)
            ocean[index] = 0
            land_region[index] = Region.VERDANT
            ground[index] = Ground.GRASS
    for area in AREAS:
        var span := _span(area[0], area[1] * 1.2 + Vector2(2, 2))
        for y in range(span.position.y, span.end.y):
            for x in range(span.position.x, span.end.x):
                var index := vertex_index(x, y)
                if ocean[index] == 0 and _norm(Vector2(x, y), area[0], area[1]) + wobble[index] * 0.6 < 1.0:
                    ground[index] = area[3]
                    land_region[index] = area[2]
    # Mirror Lake (its own region, with the keep's islet), then the other lakes and pools.
    var span_lake := _span(LAKE[0], LAKE[1] * 1.2 + Vector2(2, 2))
    for y in range(span_lake.position.y, span_lake.end.y):
        for x in range(span_lake.position.x, span_lake.end.x):
            var index := vertex_index(x, y)
            if ocean[index] == 0 and _norm(Vector2(x, y), LAKE[0], LAKE[1]) + wobble[index] * 0.4 < 1.0:
                land_region[index] = Region.MIRROR_LAKE
                if _norm(Vector2(x, y), LAKE_ISLET[0], LAKE_ISLET[1]) >= 1.0:
                    lake[index] = 1
    for pool in LAKES:
        _paint(pool, lake, ocean, wobble, 0.4)
    # Heights: highest entry wins; never in the sea, the clearing or Mirror Lake's basin.
    var height := PackedByteArray()
    height.resize(vertex_count)
    var flat := Rect2i(CLEARING.position - Vector2i(4, 4), CLEARING.size + Vector2i(8, 8))
    for hill in HIGHLANDS:
        var span := _span(hill[0], hill[1] * 1.2 + Vector2(2, 2))
        for y in range(span.position.y, span.end.y):
            for x in range(span.position.x, span.end.x):
                var index := vertex_index(x, y)
                if ocean[index] == 0 and not flat.has_point(Vector2i(x, y)) and _norm(Vector2(x, y), hill[0], hill[1]) + wobble[index] * 0.5 < 1.0:
                    height[index] = maxi(height[index], hill[2])
    for pool in LAVA_POOLS:
        _paint(pool, lava, ocean, wobble, 0.5)
    # The clearing's pond (its own collision rectangle; water drawn just inside it).
    var layout := preload("res://scripts/world/world_layout.gd")
    var pond := Rect2i(to_tile(layout.POND.position), Vector2i(layout.POND.size / TILE) + Vector2i(2, 2))
    for y in range(pond.position.y, pond.end.y):
        for x in range(pond.position.x, pond.end.x):
            if layout.POND.grow(-1).has_point(to_world(Vector2(x, y))):
                lake[vertex_index(x, y)] = 1
    # Beaches: land vertices within BEACH of the ocean are sand (not ash, snow or mud; never the
    # clearing). Separable dilation of the ocean mask keeps this fast.
    var rows_near := PackedByteArray()
    rows_near.resize(vertex_count)
    for y in range(MIN.y, MIN.y + ROWS + 1):
        for x in range(MIN.x, MIN.x + COLS + 1):
            for dx in range(-BEACH, BEACH + 1):
                if ocean[vertex_index(clampi(x + dx, MIN.x, MIN.x + COLS), y)] == 1:
                    rows_near[vertex_index(x, y)] = 1
                    break
    var inner := Rect2i(CLEARING.position - Vector2i(6, 6), CLEARING.size + Vector2i(12, 12))
    for y in range(MIN.y, MIN.y + ROWS + 1):
        for x in range(MIN.x, MIN.x + COLS + 1):
            var index := vertex_index(x, y)
            if ocean[index] == 1 or ground[index] in [Ground.ASH, Ground.SNOW, Ground.MUD] or inner.has_point(Vector2i(x, y)):
                continue
            for dy in range(-BEACH, BEACH + 1):
                if rows_near[vertex_index(x, clampi(y + dy, MIN.y, MIN.y + ROWS))] == 1:
                    ground[index] = Ground.SAND
                    break
    # Paths: the clearing's roads, the polylines (each over its own box) and the town plazas.
    for road in layout.ROADS:
        var area := Rect2i(to_tile(road.position) - Vector2i.ONE, Vector2i(road.size / TILE) + Vector2i(3, 3))
        for y in range(area.position.y, area.end.y):
            for x in range(area.position.x, area.end.x):
                if road.grow(1).has_point(to_world(Vector2(x, y))):
                    _dirt(dirt, ocean, lake, ground, land_region, x, y)
    for line in PATHS:
        for segment in range(line.size() - 1):
            var a: Vector2 = line[segment]
            var b: Vector2 = line[segment + 1]
            var box := Rect2(a, Vector2.ZERO).expand(b).grow(PATH_HALF_WIDTH + 1)
            var area := _span(box.get_center(), box.size / 2.0)
            for y in range(area.position.y, area.end.y):
                for x in range(area.position.x, area.end.x):
                    if _segment_distance(Vector2(x, y), a, b) <= PATH_HALF_WIDTH:
                        _dirt(dirt, ocean, lake, ground, land_region, x, y)
    for town in TOWNS:
        var radius: float = PLAZA[town[4]]
        var area := _span(town[3], Vector2(radius + 1, radius + 1))
        for y in range(area.position.y, area.end.y):
            for x in range(area.position.x, area.end.x):
                if Vector2(x, y).distance_to(town[3]) <= radius:
                    _dirt(dirt, ocean, lake, ground, land_region, x, y)
    # Per-tile: bridge flags and region (by the tile's top-left vertex, clearing first).
    var bridge := PackedByteArray()
    bridge.resize(COLS * ROWS)
    for rect in BRIDGES + piers():
        for y in range(rect.position.y, rect.end.y):
            for x in range(rect.position.x, rect.end.x):
                if in_grid(Vector2i(x, y)):
                    bridge[tile_index(x, y)] = 1
    var region_tiles := PackedByteArray()
    region_tiles.resize(COLS * ROWS)
    for y in range(MIN.y, MIN.y + ROWS):
        for x in range(MIN.x, MIN.x + COLS):
            var index := tile_index(x, y)
            var vertex := vertex_index(x, y)
            region_tiles[index] = Region.CLEARING if CLEARING.has_point(Vector2i(x, y)) else (Region.SEA if ocean[vertex] == 1 and bridge[index] == 0 else land_region[vertex])
    return {"ocean": ocean, "lake": lake, "lava": lava, "dirt": dirt, "ground": ground, "bridge": bridge, "region": region_tiles, "height": height}

static func _paint(pool: Array, mask: PackedByteArray, ocean: PackedByteArray, wobble: PackedFloat32Array, strength: float) -> void:
    var span := _span(pool[0], pool[1] * 1.2 + Vector2(2, 2))
    for y in range(span.position.y, span.end.y):
        for x in range(span.position.x, span.end.x):
            var index := vertex_index(x, y)
            if ocean[index] == 0 and _norm(Vector2(x, y), pool[0], pool[1]) + wobble[index] * strength < 1.0:
                mask[index] = 1

static func _dirt(dirt: PackedByteArray, ocean: PackedByteArray, lake: PackedByteArray, ground: PackedByteArray, region: PackedByteArray, x: int, y: int) -> void:
    if not in_grid(Vector2i(x, y)):
        return
    var index := vertex_index(x, y)
    # No dirt on beaches; the desert's roads cross its sand.
    if ocean[index] == 0 and lake[index] == 0 and (ground[index] != Ground.SAND or region[index] == Region.SUNSCORCH):
        dirt[index] = 1

## 4-bit corner code of a vertex mask for tile (x, y): top-left 8, top-right 4, bottom-left 2,
## bottom-right 1.
static func corners(mask: PackedByteArray, x: int, y: int) -> int:
    return mask[vertex_index(x, y)] * 8 + mask[vertex_index(x + 1, y)] * 4 + mask[vertex_index(x, y + 1)] * 2 + mask[vertex_index(x + 1, y + 1)]

## Tiles nobody can walk on: three or more corners water/lava, unless bridged. The clearing
## keeps its own collisions (pond, rocks, trees) and is never blocked by the map.
static func solid(x: int, y: int) -> bool:
    if not in_grid(Vector2i(x, y)):
        return true
    var map := data()
    if CLEARING.has_point(Vector2i(x, y)) or map.bridge[tile_index(x, y)] == 1:
        return false
    var wet := 0
    for mask in [map.ocean, map.lake, map.lava]:
        wet = maxi(wet, _count(corners(mask, x, y)))
    return wet >= 3 or cliff(x, y) != Cliff.NONE

enum Cliff {NONE, RIM, WALL_TOP, WALL_BOTTOM}

## Heights at a tile's four corners: [top-left, top-right, bottom-left, bottom-right].
static func heights(x: int, y: int) -> Array:
    var height: PackedByteArray = data().height
    return [height[vertex_index(x, y)], height[vertex_index(x + 1, y)], height[vertex_index(x, y + 1)], height[vertex_index(x + 1, y + 1)]]

## A road crossing (any dirt corner) turns a rim or wall into a ramp.
static func ramp(x: int, y: int) -> bool:
    return in_grid(Vector2i(x, y)) and corners(data().dirt, x, y) > 0

## Rim: the tile's corners lie on different levels. A south rim (top corners higher) has the
## wall below it: two tiles of rock face. Ramps (roads) are never cliffs.
static func cliff(x: int, y: int) -> int:
    if not in_grid(Vector2i(x, y)) or not in_grid(Vector2i(x + 1, y + 1)) or not in_grid(Vector2i(x, y - 2)):
        return Cliff.NONE
    var here := heights(x, y)
    if here.min() != here.max():
        return Cliff.NONE if ramp(x, y) else Cliff.RIM
    for step in [1, 2]:
        if _south_rim(x, y - step) and not ramp(x, y - step) and not ramp(x, y) and here[0] < heights(x, y - step).max():
            return Cliff.WALL_TOP if step == 1 else Cliff.WALL_BOTTOM
    return Cliff.NONE

static func _south_rim(x: int, y: int) -> bool:
    var h := heights(x, y)
    return h[0] > h[2] or h[1] > h[3]

static func _count(code: int) -> int:
    return (code >> 3 & 1) + (code >> 2 & 1) + (code >> 1 & 1) + (code & 1)

static func region_at(world: Vector2) -> int:
    var tile := to_tile(world)
    if not in_grid(tile):
        return Region.SEA
    return data().region[tile_index(tile.x, tile.y)]

static func region_name(world: Vector2) -> String:
    return REGION_NAMES[region_at(world)]

## The town or village around a position ([] when none).
static func town_at(world: Vector2) -> Array:
    var tile := (world - ORIGIN) / TILE
    for town in TOWNS:
        if tile.distance_to(town[3]) <= PLACE_RADIUS[town[4]]:
            return town
    return []

## What the HUD shows: the town or village you are in, else the region.
static func place_name(world: Vector2) -> String:
    var town := town_at(world)
    return town[1] if not town.is_empty() else region_name(world)

## The pier of each harbour (tile rects, 2 wide, PIER_LENGTH long towards the sea).
static func piers() -> Array:
    var rects: Array = []
    for ferry in HARBOURS:
        var dock := Vector2i(ferry[2])
        var direction: Vector2i = ferry[3]
        var end := dock + direction * PIER_LENGTH
        var from := dock.min(end)
        var to := dock.max(end)
        if direction.x == 0:
            rects.append(Rect2i(from.x, from.y, 2, to.y - from.y + 1))
        else:
            rects.append(Rect2i(from.x, from.y, to.x - from.x + 1, 2))
    return rects

static func harbour(id: String) -> Array:
    for entry in HARBOURS:
        if entry[0] == id:
            return entry
    return []

## World position where a character arrives at a harbour (on the pier, just off the shore).
static func dock_position(id: String) -> Vector2:
    var entry := harbour(id)
    return to_world(Vector2(entry[2]) + Vector2(entry[3]) * 1.5 + Vector2(1, 0.5))

## Where the harbour's ferryman stands (on the shore beside the pier).
static func ferryman_position(id: String) -> Vector2:
    var entry := harbour(id)
    var side := Vector2(entry[3].y, entry[3].x).abs()
    return to_world(Vector2(entry[2]) - Vector2(entry[3]) * 1.0 + side * 3.0 + Vector2(0.5, 0.5))

## Where an owner's ship lies at the harbour (beside the pier's end, on the water).
static func berth_position(id: String) -> Vector2:
    var entry := harbour(id)
    var side := Vector2(entry[3].y, entry[3].x).abs()
    return to_world(Vector2(entry[2]) + Vector2(entry[3]) * (PIER_LENGTH - 1.0) - side * 3.5 + Vector2(1, 1))

static func town(id: String) -> Array:
    for entry in TOWNS:
        if entry[0] == id:
            return entry
    return []

## Merged collision rectangles (world pixels) for every solid tile: runs per row, then rows
## with identical runs stacked into one rectangle.
static func solid_rects() -> Array:
    if not _rects.is_empty():
        return _rects
    if use_cache:
        var cached: Variant = preload("res://scripts/world/world_cache.gd").load_part("rects")
        if cached is Dictionary or cached is Array:
            _rects = cached
            return _rects
    var open: Dictionary = {}
    var rects: Array = []
    for y in range(MIN.y, MIN.y + ROWS):
        var runs: Dictionary = {}
        var x := MIN.x
        while x < MIN.x + COLS:
            if solid(x, y):
                var start := x
                while x < MIN.x + COLS and solid(x, y):
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
        rects.append(Rect2(to_world(Vector2(run.x, open[run])), Vector2(run.y - run.x, MIN.y + ROWS - open[run]) * TILE))
    _rects = rects
    return rects
