extends RefCounted
## Dungeon caves (M7c, user decision: enterable caves with rooms and an end boss). The dungeons lie
## in the Underdeep, a hidden strip of the map between the archipelago and the Ki Realm (never on
## the normal maps; inside one, the map shows only that dungeon). Each is four cave rooms joined by
## rope bridges over dark chasms: the entry room (with the way out), two rooms of creatures and the
## boss's chamber with a rich chest. A cave mouth in the dungeon's region leads in (F).
## Pure data; WorldMap draws the rooms, RegionContent adds the creatures and chests, BossCatalogue
## the end bosses, DungeonGate the way in and out.

## The Underdeep strip (tiles) and each dungeon's band in it.
const STRIP := Rect2i(-478, -256, 74, 768)
const BAND := 150
const CENTRE_X := -441
## Rooms relative to a dungeon's origin: [offset, radii] — entry, two halls, the boss chamber.
const ROOMS := [[Vector2(-18, 16), Vector2(8, 6)], [Vector2(14, 42), Vector2(10, 8)], [Vector2(-14, 74), Vector2(10, 8)], [Vector2(6, 112), Vector2(15, 12)]]
const BRIDGE_WIDTH := 3

## [name, region (for the cave mouth), cave mouth tile, levels [low, high], creature kinds,
## boss name, boss sprite, boss level]
const DUNGEONS := {
    "thornwood_hollow": ["Thornwood Hollow", "Thornwood", Vector2(76, 76), [8, 11], ["gnasher", "thornback"], "Rootmaw, the Rotting King", "mirecap", 12],
    "frostfang_cavern": ["Frostfang Cavern", "Frostpeak", Vector2(315, -97), [14, 17], ["frost_bear", "snow_wisp"], "Frostfang, the Ice Cyclops", "crystal_cyclops", 18],
    "ember_depths": ["Ember Depths", "Emberreach Isles", Vector2(546, 396), [20, 24], ["ember_flame", "salamander"], "Magmaw, the Lava Wyrm", "salamander", 25],
    "gloom_catacombs": ["Gloom Catacombs", "Gloomveil", Vector2(1138, 249), [30, 34], ["fen_skull", "shade_spirit"], "The Bone Abbot", "fen_skull", 35],
    "jade_grotto": ["Jade Grotto", "Jade Terraces", Vector2(1291, -19), [38, 42], ["peak_reptile", "frost_spirit"], "The Jade Spirit Guardian", "giant_spirit", 43],
}
const ORDER := ["thornwood_hollow", "frostfang_cavern", "ember_depths", "gloom_catacombs", "jade_grotto"]
## How close (px) a character must stand to a cave mouth or the way out to use it (F).
const GATE_REACH := 30.0

static func origin(id: String) -> Vector2:
    return Vector2(CENTRE_X, STRIP.position.y + 6 + BAND * ORDER.find(id))

## [centre tile, radii] of a dungeon's rooms (index 0 = entry, 3 = boss chamber).
static func rooms(id: String) -> Array:
    var base := origin(id)
    var flip := 1.0 if ORDER.find(id) % 2 == 0 else -1.0
    return ROOMS.map(func(room): return [base + Vector2(room[0].x * flip, room[0].y), room[1]])

## Rope bridges between consecutive rooms: an L of two tile rects (across, then down).
static func bridges(id: String) -> Array:
    var all: Array = []
    var list := rooms(id)
    for index in range(list.size() - 1):
        var a: Vector2 = list[index][0]
        var b: Vector2 = list[index + 1][0]
        var half := BRIDGE_WIDTH / 2
        var left := int(minf(a.x, b.x))
        all.append(Rect2i(left, int(a.y) - half, int(absf(b.x - a.x)) + 1, BRIDGE_WIDTH))
        var top := int(minf(a.y, b.y))
        all.append(Rect2i(int(b.x) - half, top, BRIDGE_WIDTH, int(absf(b.y - a.y)) + 1))
    return all

static func entry_tile(id: String) -> Vector2:
    return rooms(id)[0][0]

## Where the way out stands (the entry room's north side) and where a character arrives.
static func exit_tile(id: String) -> Vector2:
    return entry_tile(id) + Vector2(0, -3)

static func boss_id(id: String) -> String:
    return "dungeon_" + id

static func chest_id(id: String) -> String:
    return "chest_dg_" + id

static func chest_tile(id: String) -> Vector2:
    return rooms(id)[3][0] + Vector2(0, 8)

## Creatures: three in each of the two halls — [id, kind, tile, difficulty, level].
static func creatures(id: String) -> Array:
    var spec: Array = DUNGEONS[id]
    var list := rooms(id)
    var all: Array = []
    var offsets := [Vector2(-4, -2), Vector2(4, 1), Vector2(0, 4)]
    for hall in [1, 2]:
        for index in range(3):
            var kind: String = spec[4][(hall + index) % spec[4].size()]
            var level: int = int(lerpf(spec[3][0], spec[3][1], (hall - 1) * 0.5 + index / 6.0))
            all.append(["dg_%s_%d_%d" % [id, hall, index + 1], kind, list[hall][0] + offsets[index], 2 if index == 2 else 1, level])
    return all

static func all_creatures() -> Array:
    var all: Array = []
    for id in ORDER:
        all.append_array(creatures(id))
    return all

static func creature_level(creature_id: String) -> int:
    for entry in all_creatures():
        if entry[0] == creature_id:
            return entry[4]
    return -1

static func in_strip(tile: Vector2i) -> bool:
    return STRIP.has_point(tile)

## The dungeon a tile lies in ("" outside the Underdeep).
static func at_tile(tile: Vector2i) -> String:
    if not in_strip(tile):
        return ""
    var index: int = clampi((tile.y - STRIP.position.y) / BAND, 0, ORDER.size() - 1)
    return ORDER[index]

## A dungeon's map view (tiles).
static func view(id: String) -> Rect2i:
    return Rect2i(STRIP.position.x, int(origin(id).y) - 6, STRIP.size.x, BAND)
