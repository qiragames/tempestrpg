extends RefCounted
## Boss drops (user request after M15): every raid boss, hidden elite and dungeon boss drops its
## own material, themed after it and belonging to it alone (a few for every helper), besides the
## chance at its uniques; the material and bars of the item's tier forge that boss's uniques at
## Smithing ("bossforge:<item>"). The boss bar shows what a boss can drop: its uniques (icon and
## name in their rarity's colour) and its material with how many each helper gets.
const BOSS := preload("res://scripts/bosses/boss_catalogue.gd")
const ICONS := "res://assets/game/ui/icons/boss_materials/%s.png"
## boss id → its material's name.
const NAMES := {
    "boss_grumblehorn": "Grumblehorn's Tusk",
    "boss_gnashmaw": "Gnashmaw's Brood Fangs",
    "boss_quillback": "Croaker's Pearl",
    "boss_cinderquill": "Crater Ember Core",
    "boss_rimefang": "Glacier King's Claw",
    "boss_sandmaw": "Sandmaw Scale",
    "boss_hollowwing": "Hollowwing Plume",
    "boss_bog_shogun": "Shogun's Lily Pad",
    "boss_lantern_empress": "Crimson Tengu Feather",
    "boss_pyreclaw": "Pyreclaw's Cinder Spine",
    "boss_raijin": "Raijin's Thunder Seal",
    "boss_gloomtide": "Gloomtide Tentacle",
    "boss_skylord": "Jade Tengu Feather",
    "boss_rex_prime": "Tyrant Rex Tooth",
    "boss_eclipse_wyrm": "Eclipse Wyrm Heartscale",
    "boss_majin": "Majin's Demon Horn",
    "elite_oakfang": "Oakfang Root",
    "elite_snowmane": "Snowmane's Frost Shard",
    "elite_dune_stalker": "Dune Stalker's Skull",
    "elite_ambershriek": "Ambershriek Talon",
    "elite_fen_witch": "Fen Witch's Spore Cap",
    "elite_bamboo_ronin": "Ronin's Bamboo Sprig",
    "elite_storm_eye": "Storm Eye Lens",
    "elite_nightweaver": "Nightweaver Egg Cluster",
    "elite_cloud_serpent": "Cloud Serpent Pearl",
    "elite_rex_alpha": "Alpha Raptor Bone",
    "dungeon_thornwood_hollow": "Rootmaw's Rotten Heart",
    "dungeon_frostfang_cavern": "Cyclops Frost Eye",
    "dungeon_ember_depths": "Magmaw's Molten Core",
    "dungeon_gloom_catacombs": "Abbot's Bone Relic",
    "dungeon_jade_grotto": "Jade Spirit Shard",
}
## Trophies each helper gets: [min, max] by kind of boss.
const COUNTS := {"raid": [2, 3], "elite": [1, 2], "dungeon": [1, 3]}
## Trophies needed to forge one of the boss's uniques.
const FORGE_COST := {"raid": 6, "elite": 4, "dungeon": 5}
const FORGE_BARS := 3
const PRICE := 60

static func kind(boss_id: String) -> String:
    return "raid" if BOSS.is_raid(boss_id) else ("elite" if BOSS.is_hidden_elite(boss_id) else "dungeon")

static func material(boss_id: String) -> String:
    return "bossmat_" + boss_id

static func is_material(id: String) -> bool:
    return id.begins_with("bossmat_") and BOSS.is_boss(id.trim_prefix("bossmat_"))

static func boss_of(material_id: String) -> String:
    return material_id.trim_prefix("bossmat_")

static func name_of(material_id: String) -> String:
    return String(NAMES.get(boss_of(material_id), "%s's Trophy" % BOSS.entry(boss_of(material_id))[0]))

static func icon(material_id: String) -> Texture2D:
    var path := ICONS % boss_of(material_id)
    return load(path) if ResourceLoader.exists(path) else null

static func good_info(material_id: String) -> Array:
    var boss := boss_of(material_id)
    return [name_of(material_id), "Boss materials", "Dropped by %s. %d of them (and %d bars) forge one of its uniques at Smithing." % [BOSS.entry(boss)[0], int(FORGE_COST[kind(boss)]), FORGE_BARS]]

static func count_range(boss_id: String) -> Array:
    return COUNTS[kind(boss_id)]

## What a boss can drop: [{"base": id} for its uniques..., {"material": id, "min": n, "max": n}].
static func drops(boss_id: String) -> Array:
    var list: Array = []
    for base in BOSS.entry(boss_id)[8]:
        list.append({"base": base})
    var counts := count_range(boss_id)
    list.append({"material": material(boss_id), "min": int(counts[0]), "max": int(counts[1])})
    return list

## Every boss's trophy (for bag checks and prices).
static func all_materials() -> Array:
    return BOSS.all_ids().map(func(id): return material(id))

## The boss whose uniques include `base` ("" when none).
static func boss_for_item(base: String) -> String:
    for id in BOSS.all_ids():
        if base in BOSS.entry(id)[8]:
            return id
    return ""
