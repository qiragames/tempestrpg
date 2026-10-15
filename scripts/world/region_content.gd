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
    # M4.5c: the home continent's new regions, then the ferry lands (harder).
    "frost_bear_1": 10, "frost_bear_2": 13, "snow_wisp_1": 9, "snow_wisp_2": 11,
    "dune_viper_1": 8, "dune_viper_2": 10, "sand_scuttler_1": 9, "sand_scuttler_2": 12,
    "amber_owl_1": 12, "amber_owl_2": 13, "burrow_mole_1": 12, "burrow_mole_2": 15,
    "bog_kappa_1": 15, "bog_kappa_2": 17, "mirecap_1": 15, "mirecap_2": 16,
    "bamboo_sprite_1": 14, "bamboo_sprite_2": 16, "paper_lantern_1": 14, "paper_lantern_2": 15,
    "ember_flame_1": 17, "ember_flame_2": 19, "salamander_1": 18, "salamander_2": 20,
    # M4.7 the Ki Realm.
    "raptor_1": 17, "raptor_2": 17, "tyrant_rex_1": 19, "gi_fighter_1": 17, "monkey_brawler_1": 18,
    "android_scout_1": 18, "android_tank_1": 20, "bio_android_1": 21, "demon_king_1": 22,
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
    # M4.5c region creatures (their own kinds).
    ["frost_bear_1", "frost_bear", Vector2(130, -100), 1], ["frost_bear_2", "frost_bear", Vector2(262, -92), 2],
    ["snow_wisp_1", "snow_wisp", Vector2(80, -64), 1], ["snow_wisp_2", "snow_wisp", Vector2(310, -78), 1],
    ["dune_viper_1", "dune_viper", Vector2(-60, 92), 1], ["dune_viper_2", "dune_viper", Vector2(-230, 120), 1],
    ["sand_scuttler_1", "sand_scuttler", Vector2(-150, 160), 1], ["sand_scuttler_2", "sand_scuttler", Vector2(-100, 44), 2],
    ["amber_owl_1", "amber_owl", Vector2(100, 300), 1], ["amber_owl_2", "amber_owl", Vector2(250, 372), 1],
    ["burrow_mole_1", "burrow_mole", Vector2(130, 345), 1], ["burrow_mole_2", "burrow_mole", Vector2(380, 352), 2],
    ["bog_kappa_1", "bog_kappa", Vector2(-222, 382), 1], ["bog_kappa_2", "bog_kappa", Vector2(-120, 362), 2],
    ["mirecap_1", "mirecap", Vector2(-196, 408), 1], ["mirecap_2", "mirecap", Vector2(-262, 352), 1],
    ["bamboo_sprite_1", "bamboo_sprite", Vector2(500, 20), 1], ["bamboo_sprite_2", "bamboo_sprite", Vector2(604, 64), 2],
    ["paper_lantern_1", "paper_lantern", Vector2(520, 100), 1], ["paper_lantern_2", "paper_lantern", Vector2(650, 14), 1],
    ["ember_flame_1", "ember_flame", Vector2(520, 330), 1], ["ember_flame_2", "ember_flame", Vector2(645, 328), 2],
    ["salamander_1", "salamander", Vector2(580, 280), 1], ["salamander_2", "salamander", Vector2(660, 404), 2],
    # M4.7 the Ki Realm: dinosaurs in Raptor Gulch, fighters in Wasteland Canyon, androids at the
    # Works, the Demon King at the canyon's far end.
    ["raptor_1", "raptor", Vector2(-330, -160), 1], ["raptor_2", "raptor", Vector2(-312, -142), 1], ["tyrant_rex_1", "tyrant_rex", Vector2(-326, -154), 2],
    ["gi_fighter_1", "gi_fighter", Vector2(-222, -156), 1], ["monkey_brawler_1", "monkey_brawler", Vector2(-214, -140), 1],
    ["android_scout_1", "android_scout", Vector2(-224, -198), 1], ["android_tank_1", "android_tank", Vector2(-218, -200), 2], ["bio_android_1", "bio_android", Vector2(-230, -210), 2],
    ["demon_king_1", "demon_king", Vector2(-204, -160), 2],
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
    ["spot_frost_a", "frost_bear", Vector2(100, -58), 1, 11, 3],
    ["spot_frost_b", "snow_wisp", Vector2(280, -60), 1, 12, 2],
    ["spot_desert_a", "dune_viper", Vector2(-240, 170), 1, 10, 3],
    ["spot_desert_b", "sand_scuttler", Vector2(-40, 140), 1, 11, 2],
    ["spot_amber_a", "amber_owl", Vector2(40, 330), 1, 13, 3],
    ["spot_amber_b", "burrow_mole", Vector2(330, 380), 1, 14, 2],
    ["spot_mire_a", "mirecap", Vector2(-250, 440), 1, 16, 3],
    ["spot_mire_b", "bog_kappa", Vector2(-90, 400), 2, 17, 2],
    ["spot_sakura_a", "bamboo_sprite", Vector2(470, 60), 1, 15, 3],
    ["spot_sakura_b", "paper_lantern", Vector2(650, -20), 1, 16, 2],
    ["spot_ember_a", "ember_flame", Vector2(500, 360), 1, 18, 3],
    ["spot_ember_b", "salamander", Vector2(600, 300), 2, 19, 2],
    ["spot_ki_a", "raptor", Vector2(-318, -164), 1, 18, 3],
    ["spot_ki_b", "android_scout", Vector2(-238, -192), 1, 20, 2],
]
const SPOT_NAMES := {
    "spot_meadow_a": "Gnasher Hollow", "spot_meadow_b": "Eastern Thicket", "spot_thornwood_a": "Fang Grove",
    "spot_thornwood_b": "Quill Den", "spot_lake_a": "Reed Shallows", "spot_lake_b": "Keepward Rocks",
    "spot_crater_a": "Ember Rim", "spot_crater_b": "Ashen Pit",
    "spot_frost_a": "Bear Hollow", "spot_frost_b": "Whisper Drifts", "spot_desert_a": "Viper Dunes", "spot_desert_b": "Scuttle Flats",
    "spot_amber_a": "Owlwood", "spot_amber_b": "Molehill Fields", "spot_mire_a": "Spore Bog", "spot_mire_b": "Kappa Pools",
    "spot_sakura_a": "Bamboo Maze", "spot_sakura_b": "Lantern Glade", "spot_ember_a": "Cinder Flats", "spot_ember_b": "Salamander Den",
    "spot_ki_a": "Raptor Nest", "spot_ki_b": "Scrap Yard",
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
    ["chest_glacier", Vector2(60, -150), false],
    ["chest_dunes", Vector2(-280, 140), false],
    ["chest_marsh", Vector2(-282, 420), true],
    ["chest_shrine", Vector2(606, -50), true],
    ["chest_amber", Vector2(300, 392), false],
    ["chest_volcano", Vector2(580, 374), true],
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
