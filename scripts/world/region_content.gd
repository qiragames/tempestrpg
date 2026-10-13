extends RefCounted
## Content of the archipelago's regions (M4.5b): creatures, resource deposits and chests outside
## the First Clearing. Fixed like the map itself (the world seed still lays out the clearing), so
## every world has them at the same places, with stable IDs for saves and multiplayer.
##
## Creatures respawn like the clearing's (17d2). Deposits are outlying: players gather them into
## the camp's shared stock, allied workers stay near the camp. Chests open once per character;
## the keep's and the crater's use the trial's better rarity odds. Harrowmere is peaceful.
const MAP := preload("res://scripts/world/world_map.gd")

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
    return CREATURES.map(func(entry): return entry[0])

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
    var stats: Dictionary = preload("res://scripts/enemies/forest_gnasher.gd").TIER_STATS[entry[3]]
    var spot := at(entry[2])
    return {"id": entry[0], "kind": entry[1], "position": [spot.x, spot.y], "home": [spot.x, spot.y], "difficulty": entry[3], "hp": stats.health, "maximum_hp": stats.health, "immunity": 0.0, "state": 0, "state_time": 0.0, "target": ""}

## Tiles props must keep clear of (content spots).
static func spots() -> Array:
    var all: Array = []
    for entry in CREATURES:
        all.append(entry[2])
    for entry in DEPOSITS + CHESTS:
        all.append(entry[1])
    return all
