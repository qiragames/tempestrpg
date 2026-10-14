extends RefCounted
## Content of the archipelago's regions (M4.5b): creatures, resource deposits and chests outside
## the First Clearing. Fixed like the map itself (the world seed still lays out the clearing), so
## every world has them at the same places, with stable IDs for saves and multiplayer.
##
## Creatures respawn like the clearing's (17d2). Deposits are outlying: players gather them into
## the camp's shared stock, allied workers stay near the camp. Chests open once per character;
## the keep's and the crater's use the trial's better rarity odds. Harrowmere is peaceful.
const MAP := preload("res://scripts/world/world_map.gd")

## Creature levels (24a): the clearing's by tier, the regions' by place. Levels show above the
## health bar, scale XP and set the Magicule cost of naming a monster.
const TIER_LEVELS := [1, 2, 4]
const LEVELS := {
    "thornwood_gnasher_1": 6, "thornwood_gnasher_2": 6, "thornwood_gnasher_3": 8, "thornwood_thornback_1": 7,
    "meadow_gnasher_1": 2, "meadow_gnasher_2": 2, "meadow_gnasher_3": 3,
    "lakeshore_gnasher_1": 5, "lakeshore_thornback_1": 5,
    "crater_thornback_1": 11, "crater_thornback_2": 11, "crater_gnasher_1": 12,
    "beach_gnasher_1": 2,
}

static func level_of(id: String, difficulty: int) -> int:
    if LEVELS.has(id):
        return LEVELS[id]
    for spot in SPOTS:
        if id.begins_with(spot[0] + "_"):
            return spot[4]
    return TIER_LEVELS[clampi(difficulty, 0, 2)]

## [id, kind, tile, difficulty (0 Easy, 1 Standard, 2 Elite)]
const CREATURES := [
    ["thornwood_gnasher_1", "gnasher", Vector2(96, 78), 1],
    ["thornwood_gnasher_2", "gnasher", Vector2(118, 92), 1],
    ["thornwood_gnasher_3", "gnasher", Vector2(102, 104), 2],
    ["thornwood_thornback_1", "thornback", Vector2(112, 68), 1],
    ["meadow_gnasher_1", "gnasher", Vector2(150, 150), 0],
    ["meadow_gnasher_2", "gnasher", Vector2(214, 150), 0],
    ["meadow_gnasher_3", "gnasher", Vector2(132, 140), 1],
    ["lakeshore_gnasher_1", "gnasher", Vector2(230, 96), 1],
    ["lakeshore_thornback_1", "thornback", Vector2(264, 94), 1],
    ["crater_thornback_1", "thornback", Vector2(250, 168), 2],
    ["crater_thornback_2", "thornback", Vector2(262, 162), 2],
    ["crater_gnasher_1", "gnasher", Vector2(256, 186), 2],
    ["beach_gnasher_1", "gnasher", Vector2(174, 186), 0],
]
## Hidden leveling spots (24a, user decision: two per creature region, unmarked until a character
## discovers them): [id, kind, centre tile, difficulty, level, creatures]. Their creatures respawn
## three times faster than usual.
const SPOTS := [
    ["spot_meadow_a", "gnasher", Vector2(140, 160), 0, 3, 3],
    ["spot_meadow_b", "gnasher", Vector2(232, 142), 0, 3, 2],
    ["spot_thornwood_a", "gnasher", Vector2(90, 86), 1, 7, 3],
    ["spot_thornwood_b", "thornback", Vector2(126, 104), 1, 8, 2],
    ["spot_lake_a", "gnasher", Vector2(214, 78), 1, 5, 2],
    ["spot_lake_b", "thornback", Vector2(276, 62), 1, 6, 2],
    ["spot_crater_a", "thornback", Vector2(238, 152), 2, 12, 2],
    ["spot_crater_b", "gnasher", Vector2(274, 178), 2, 13, 3],
]
const SPOT_NAMES := {
    "spot_meadow_a": "Gnasher Hollow", "spot_meadow_b": "Eastern Thicket", "spot_thornwood_a": "Fang Grove",
    "spot_thornwood_b": "Quill Den", "spot_lake_a": "Reed Shallows", "spot_lake_b": "Keepward Rocks",
    "spot_crater_a": "Ember Rim", "spot_crater_b": "Ashen Pit",
}
## Discovered within this many pixels of a spot's centre.
const DISCOVER_RADIUS := 96.0
const SPOT_OFFSETS := [Vector2(-2, 0), Vector2(2, 0), Vector2(0, 2)]
## Respawn seconds by tier (Easy, Standard, Elite); leveling spots divide by SPOT_SPEEDUP.
const RESPAWN_SECONDS := [45.0, 90.0, 180.0]
const SPOT_SPEEDUP := 3.0

## Every leveling-spot creature as a CREATURES-style entry: [id, kind, tile, difficulty].
static func spot_creatures() -> Array:
    var all: Array = []
    for spot in SPOTS:
        for index in range(spot[5]):
            all.append(["%s_%d" % [spot[0], index + 1], spot[1], spot[2] + SPOT_OFFSETS[index], spot[3]])
    return all

## Every fixed creature outside the clearing (regions and leveling spots).
static func all_creatures() -> Array:
    return CREATURES + spot_creatures()

static func is_spot_creature(id: String) -> bool:
    return id.begins_with("spot_")

static func respawn_seconds(id: String, difficulty: int) -> float:
    var base: float = RESPAWN_SECONDS[clampi(difficulty, 0, 2)]
    return base / SPOT_SPEEDUP if is_spot_creature(id) else base

## Region deposits live in the camp's reference table (FirstCamp.DEPOSITS, after the seeded
## ones), so every camp state and save includes them; their tiles here keep props clear.
const DEPOSITS := [
    ["wood_thornwood_1", Vector2(92, 96)], ["wood_thornwood_2", Vector2(124, 78)],
    ["stone_crater_1", Vector2(244, 178)], ["stone_crater_2", Vector2(270, 156)],
    ["stone_lakeshore_1", Vector2(232, 88)], ["wood_meadow_1", Vector2(200, 178)],
]
## [id, tile, rich] — rich chests roll with the trial's odds (Rare or Epic).
const CHESTS := [
    ["chest_thornwood", Vector2(100, 90), false],
    ["chest_keep", Vector2(243, 73), true],
    ["chest_crater", Vector2(256, 172), true],
    ["chest_harrowmere", Vector2(346, 97), false],
    ["chest_beach", Vector2(192, 188), false],
]

static func at(tile: Vector2) -> Vector2:
    return MAP.to_world(tile) + Vector2(MAP.TILE / 2.0, MAP.TILE / 2.0)

static func creature_ids() -> Array:
    return all_creatures().map(func(entry): return entry[0])

static func chest_ids() -> Array:
    return CHESTS.map(func(entry): return entry[0])

## Region deposit entries from the camp's table.
static func deposits() -> Dictionary:
    var camp := preload("res://scripts/settlement/first_camp.gd")
    var table := {}
    for entry in DEPOSITS:
        table[entry[0]] = camp.DEPOSITS[entry[0]]
    return table

## Chest entries (same shape as WorldLayout chests) plus the `rich` flag.
static func chests() -> Array:
    return CHESTS.map(func(entry): return {"id": entry[0], "position": at(entry[1]), "rich": entry[2]})

static func is_rich_chest(id: String) -> bool:
    return CHESTS.any(func(entry): return entry[0] == id and entry[2])

## Saved enemy entry for a fresh region creature (used by the v20 migration).
static func fresh_enemy(entry: Array) -> Dictionary:
    var health: int = preload("res://scripts/enemies/forest_gnasher.gd").scaled_health(entry[3], level_of(entry[0], entry[3]))
    var spot := at(entry[2])
    return {"id": entry[0], "kind": entry[1], "position": [spot.x, spot.y], "home": [spot.x, spot.y], "difficulty": entry[3], "hp": health, "maximum_hp": health, "immunity": 0.0, "state": 0, "state_time": 0.0, "target": ""}

## Tiles props must keep clear of (content spots).
static func spots() -> Array:
    var all: Array = []
    for entry in all_creatures():
        all.append(entry[2])
    for entry in DEPOSITS + CHESTS:
        all.append(entry[1])
    return all
