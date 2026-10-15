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
    "raptor_1": 40, "raptor_2": 40, "tyrant_rex_1": 43, "gi_fighter_1": 40, "monkey_brawler_1": 42,
    "android_scout_1": 42, "android_tank_1": 45, "bio_android_1": 47, "demon_king_1": 48,
    # The bigger realm (user request).
    "raptor_3": 42, "raptor_4": 42, "tyrant_rex_2": 45, "gi_fighter_2": 42, "monkey_brawler_2": 43,
    "android_scout_2": 43, "android_tank_2": 47, "ki_bear_1": 43, "ki_bear_2": 45, "ki_wisp_1": 43,
    "ki_viper_1": 42, "ki_salamander_1": 45, "demon_king_2": 48,
    # M7b, the Eastern Reaches: Stormreach 22-27, Duskfen 28-33, Skyreach Peaks 34-40.
    "storm_storm_bat_1": 22, "storm_gale_beast_1": 22, "storm_cliff_lizard_1": 23, "storm_thunder_eye_1": 23, "storm_storm_bat_2": 24, "storm_gale_beast_2": 25, "storm_cliff_lizard_2": 25, "storm_thunder_eye_2": 26, "storm_storm_bat_3": 26, "storm_gale_beast_3": 27, "dusk_dusk_spider_1": 28, "dusk_fen_octopus_1": 28, "dusk_shade_spirit_1": 29, "dusk_fen_skull_1": 29, "dusk_dusk_spider_2": 30, "dusk_fen_octopus_2": 31, "dusk_shade_spirit_2": 31, "dusk_fen_skull_2": 32, "dusk_dusk_spider_3": 32, "dusk_fen_octopus_3": 33, "sky_crystal_cyclops_1": 34, "sky_sky_dragonling_1": 34, "sky_peak_reptile_1": 35, "sky_frost_spirit_1": 35, "sky_crystal_cyclops_2": 36, "sky_sky_dragonling_2": 37, "sky_peak_reptile_2": 37, "sky_frost_spirit_2": 38, "sky_crystal_cyclops_3": 38, "sky_sky_dragonling_3": 39,
}

static func level_of(id: String, difficulty: int) -> int:
    if id.begins_with("dg_"):
        return preload("res://scripts/dungeons/dungeon_catalogue.gd").creature_level(id)
    if preload("res://scripts/bosses/boss_catalogue.gd").is_boss(id):
        return preload("res://scripts/bosses/boss_catalogue.gd").level(id)
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
    ["raptor_1", "raptor", Vector2(-1150, -30), 1], ["raptor_2", "raptor", Vector2(-1090, -80), 1], ["tyrant_rex_1", "tyrant_rex", Vector2(-1200, 20), 2],
    ["raptor_3", "raptor", Vector2(-1060, -40), 1], ["raptor_4", "raptor", Vector2(-1120, -110), 1], ["tyrant_rex_2", "tyrant_rex", Vector2(-1170, 10), 2],
    ["gi_fighter_1", "gi_fighter", Vector2(-700, 180), 1], ["monkey_brawler_1", "monkey_brawler", Vector2(-650, 160), 1],
    ["gi_fighter_2", "gi_fighter", Vector2(-760, 150), 1], ["monkey_brawler_2", "monkey_brawler", Vector2(-640, 210), 1],
    ["android_scout_1", "android_scout", Vector2(-640, -70), 1], ["android_tank_1", "android_tank", Vector2(-590, -30), 2], ["bio_android_1", "bio_android", Vector2(-630, -10), 2],
    ["android_scout_2", "android_scout", Vector2(-680, -20), 1], ["android_tank_2", "android_tank", Vector2(-700, -60), 2],
    ["demon_king_1", "demon_king", Vector2(-790, 235), 2], ["demon_king_2", "demon_king", Vector2(-1250, 300), 2],
    ["ki_bear_1", "frost_bear", Vector2(-1080, -170), 1], ["ki_bear_2", "frost_bear", Vector2(-920, -200), 2], ["ki_wisp_1", "snow_wisp", Vector2(-980, -150), 1],
    ["ki_viper_1", "dune_viper", Vector2(-1160, 280), 1], ["ki_salamander_1", "salamander", Vector2(-600, 230), 1],
    # M7b, the Eastern Reaches (tiles found on open ground by a placement tool).
    ["storm_storm_bat_1", "storm_bat", Vector2(874, -173), 1],
    ["storm_gale_beast_1", "gale_beast", Vector2(1097, 31), 1],
    ["storm_cliff_lizard_1", "cliff_lizard", Vector2(958, -53), 1],
    ["storm_thunder_eye_1", "thunder_eye", Vector2(1009, -159), 2],
    ["storm_storm_bat_2", "storm_bat", Vector2(1167, -16), 1],
    ["storm_gale_beast_2", "gale_beast", Vector2(1077, -73), 1],
    ["storm_cliff_lizard_2", "cliff_lizard", Vector2(1060, -87), 1],
    ["storm_thunder_eye_2", "thunder_eye", Vector2(939, -143), 2],
    ["storm_storm_bat_3", "storm_bat", Vector2(1037, -23), 1],
    ["storm_gale_beast_3", "gale_beast", Vector2(1047, -69), 2],
    ["dusk_dusk_spider_1", "dusk_spider", Vector2(1025, 277), 1],
    ["dusk_fen_octopus_1", "fen_octopus", Vector2(880, 298), 1],
    ["dusk_shade_spirit_1", "shade_spirit", Vector2(939, 278), 1],
    ["dusk_fen_skull_1", "fen_skull", Vector2(980, 353), 2],
    ["dusk_dusk_spider_2", "dusk_spider", Vector2(907, 250), 1],
    ["dusk_fen_octopus_2", "fen_octopus", Vector2(877, 262), 1],
    ["dusk_shade_spirit_2", "shade_spirit", Vector2(940, 246), 1],
    ["dusk_fen_skull_2", "fen_skull", Vector2(1010, 240), 2],
    ["dusk_dusk_spider_3", "dusk_spider", Vector2(1149, 376), 1],
    ["dusk_fen_octopus_3", "fen_octopus", Vector2(969, 388), 2],
    ["sky_crystal_cyclops_1", "crystal_cyclops", Vector2(1412, -34), 1],
    ["sky_sky_dragonling_1", "sky_dragonling", Vector2(1249, 48), 1],
    ["sky_peak_reptile_1", "peak_reptile", Vector2(1443, 89), 1],
    ["sky_frost_spirit_1", "frost_spirit", Vector2(1336, 138), 2],
    ["sky_crystal_cyclops_2", "crystal_cyclops", Vector2(1364, -21), 1],
    ["sky_sky_dragonling_2", "sky_dragonling", Vector2(1267, -125), 1],
    ["sky_peak_reptile_2", "peak_reptile", Vector2(1332, 247), 1],
    ["sky_frost_spirit_2", "frost_spirit", Vector2(1326, -49), 2],
    ["sky_crystal_cyclops_3", "crystal_cyclops", Vector2(1308, -44), 1],
    ["sky_sky_dragonling_3", "sky_dragonling", Vector2(1257, -10), 2],
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
    ["spot_ki_a", "raptor", Vector2(-1120, -50), 1, 42, 3],
    ["spot_ki_b", "android_scout", Vector2(-610, -60), 1, 45, 2],
    ["spot_ki_c", "frost_bear", Vector2(-960, -185), 1, 47, 2],
    ["spot_ki_d", "gi_fighter", Vector2(-730, 200), 1, 48, 3],
    # M7b.
    ["spot_storm_a", "gale_beast", Vector2(875, -120), 1, 24, 3],
    ["spot_storm_b", "thunder_eye", Vector2(1075, -128), 1, 26, 2],
    ["spot_dusk_a", "dusk_spider", Vector2(991, 370), 1, 30, 3],
    ["spot_dusk_b", "shade_spirit", Vector2(1110, 255), 1, 32, 2],
    ["spot_sky_a", "crystal_cyclops", Vector2(1282, 115), 1, 36, 3],
    ["spot_sky_b", "sky_dragonling", Vector2(1301, 163), 1, 39, 2],
]
const SPOT_NAMES := {
    "spot_storm_a": "Howling Gorge", "spot_storm_b": "Eye of the Storm", "spot_dusk_a": "Webbed Hollow", "spot_dusk_b": "Shade Pools", "spot_sky_a": "Cyclops Steps", "spot_sky_b": "Dragon Roost",
    "spot_meadow_a": "Gnasher Hollow", "spot_meadow_b": "Eastern Thicket", "spot_thornwood_a": "Fang Grove",
    "spot_thornwood_b": "Quill Den", "spot_lake_a": "Reed Shallows", "spot_lake_b": "Keepward Rocks",
    "spot_crater_a": "Ember Rim", "spot_crater_b": "Ashen Pit",
    "spot_frost_a": "Bear Hollow", "spot_frost_b": "Whisper Drifts", "spot_desert_a": "Viper Dunes", "spot_desert_b": "Scuttle Flats",
    "spot_amber_a": "Owlwood", "spot_amber_b": "Molehill Fields", "spot_mire_a": "Spore Bog", "spot_mire_b": "Kappa Pools",
    "spot_sakura_a": "Bamboo Maze", "spot_sakura_b": "Lantern Glade", "spot_ember_a": "Cinder Flats", "spot_ember_b": "Salamander Den",
    "spot_ki_a": "Raptor Nest", "spot_ki_b": "Scrap Yard", "spot_ki_c": "Glacier Den", "spot_ki_d": "Fighters' Pit",
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
    # M7c: the dungeons' creatures too.
    return CREATURES + spot_creatures() + preload("res://scripts/dungeons/dungeon_catalogue.gd").all_creatures().map(func(entry): return entry.slice(0, 4))

static func is_spot_creature(id: String) -> bool:
    return id.begins_with("spot_")

static func respawn_seconds(id: String, difficulty: int) -> float:
    if preload("res://scripts/bosses/boss_catalogue.gd").is_boss(id):
        return preload("res://scripts/bosses/boss_catalogue.gd").respawn(id)
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

## M7 (user request): the level range of a region's creatures, [lowest, highest] ([] when it
## has none) — shown on the world map. Computed once from the creatures' homes.
static var _ranges: Dictionary = {}

static func level_range(region_name: String) -> Array:
    if _ranges.is_empty():
        for entry in all_creatures():
            var name: String = MAP.region_name(at(entry[2]))
            var creature_level: int = level_of(entry[0], entry[3])
            var range: Array = _ranges.get(name, [creature_level, creature_level])
            _ranges[name] = [mini(range[0], creature_level), maxi(range[1], creature_level)]
        # The clearing's own three creatures (levels by tier).
        var clearing: Array = _ranges.get("The First Clearing", [TIER_LEVELS[0], TIER_LEVELS[2]])
        _ranges["The First Clearing"] = [mini(clearing[0], TIER_LEVELS[0]), maxi(clearing[1], TIER_LEVELS[2])]
    return _ranges.get(region_name, [])

static func range_text(region_name: String) -> String:
    var range := level_range(region_name)
    if range.is_empty():
        return ""
    return "Lv %d" % range[0] if range[0] == range[1] else "Lv %d–%d" % [range[0], range[1]]

static func at(tile: Vector2) -> Vector2:
    return MAP.to_world(tile) + Vector2(MAP.TILE / 2.0, MAP.TILE / 2.0)

static func creature_ids() -> Array:
    return all_creatures().map(func(entry): return entry[0])

static func chest_ids() -> Array:
    return chests().map(func(entry): return entry.id)

## Region deposit entries from the camp's table.
static func deposits() -> Dictionary:
    var camp := preload("res://scripts/settlement/first_camp.gd")
    var table := {}
    for entry in DEPOSITS:
        table[entry[0]] = camp.DEPOSITS[entry[0]]
    return table

## Chest entries (same shape as WorldLayout chests) plus the `rich` flag.
static func chests() -> Array:
    var dungeons := preload("res://scripts/dungeons/dungeon_catalogue.gd")
    # M7c: each dungeon's boss chamber holds a rich chest.
    return CHESTS.map(func(entry): return {"id": entry[0], "position": at(entry[1]), "rich": entry[2]}) + dungeons.ORDER.map(func(id): return {"id": dungeons.chest_id(id), "position": at(dungeons.chest_tile(id)), "rich": true})

static func is_rich_chest(id: String) -> bool:
    return id.begins_with("chest_dg_") or CHESTS.any(func(entry): return entry[0] == id and entry[2])

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
