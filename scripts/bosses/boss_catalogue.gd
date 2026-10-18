extends RefCounted
## Raid bosses (M7a, user decisions in docs/M4_PLAN.md M7): one huge boss per major region (two in
## the Ki Realm), built for two to five characters — a high-level character can solo a starter
## boss. Each lives in a marked arena, fights in two or three phases with telegraphed attacks (red
## zones before they land), grows its HP with the characters nearby, resets when everyone leaves
## the arena and comes back RESPAWN seconds after its defeat. Everyone who helped gets personal
## loot (Epic and better), a chance at the boss's own uniques, and big XP and Zeni.
## Pure data; RaidBoss and BossFx apply it.

## [name, title, sprite kind, arena centre tile, arena radius (tiles), level, tint, attacks, uniques]
## Attacks: slam (circle around the boss), charge (a line it dashes along), rain (circles under
## the characters), ring (a ring around the boss: stand close to it or far away).
const RAID := {
    "boss_grumblehorn": ["Old Grumblehorn", "Terror of the Meadows", "giant_racoon", Vector2(170, 168), 9, 8, Color(0.9, 1.0, 0.75), ["slam", "charge"], ["boss_grumble_horn"]],
    "boss_gnashmaw": ["Gnashmaw", "Matriarch of Thornwood", "gnasher", Vector2(106, 85), 9, 11, Color(0.75, 1.0, 0.7), ["slam", "charge", "rain"], ["boss_thorncrown", "boss_matriarch_fang"]],
    "boss_quillback": ["Old Croaker", "Warden of Mirror Lake", "giant_frog_blue", Vector2(222, 88), 8, 13, Color(0.7, 0.85, 1.0), ["slam", "rain", "ring"], ["boss_mirror_quill"]],
    "boss_cinderquill": ["Cinderheart", "Flame of the Crater", "giant_flam", Vector2(274, 166), 9, 17, Color(1.0, 0.6, 0.45), ["slam", "rain", "ring", "charge"], ["boss_crater_heart", "boss_ashen_spines"]],
    "boss_rimefang": ["Rimefang", "Glacier King", "frost_bear", Vector2(187, -97), 10, 22, Color(0.75, 0.9, 1.0), ["slam", "charge", "ring"], ["boss_rimefang_claw", "boss_glacier_mantle"]],
    "boss_sandmaw": ["Sandmaw", "Dune Serpent", "dune_viper", Vector2(-153, 103), 10, 21, Color(1.0, 0.85, 0.55), ["charge", "rain", "ring"], ["boss_sandmaw_fang", "boss_dune_wraps"]],
    "boss_hollowwing": ["Hollowwing", "Elder Owl of Ambervale", "amber_owl", Vector2(202, 338), 10, 26, Color(1.0, 0.75, 0.45), ["rain", "charge", "ring"], ["boss_hollow_quill", "boss_elder_feather"]],
    "boss_bog_shogun": ["The Bog Shogun", "Lord of Mirewood", "giant_frog", Vector2(-170, 398), 10, 30, Color(0.65, 0.9, 0.6), ["slam", "rain", "ring", "charge"], ["boss_shogun_blade", "boss_kappa_shell"]],
    "boss_lantern_empress": ["The Crimson Tengu", "Lord of Sakura Vale", "tengu_red", Vector2(573, 40), 10, 30, Color(1.0, 0.7, 0.8), ["rain", "ring", "slam"], ["boss_empress_lantern", "boss_sakura_veil"]],
    "boss_pyreclaw": ["Pyreclaw", "Salamander King", "salamander", Vector2(583, 313), 10, 34, Color(1.0, 0.5, 0.35), ["slam", "charge", "rain", "ring"], ["boss_pyreclaw_scythe", "boss_salamander_crown"]],
    # M7b: the Eastern Reaches.
    "boss_raijin": ["Raijin", "Storm Samurai of the Goldwind Steppe", "blue_samurai", Vector2(1124, -76), 10, 27, Color(0.85, 0.95, 1.0), ["charge", "slam", "rain", "ring"], ["boss_raijin_blade", "boss_storm_kabuto"]],
    "boss_gloomtide": ["Gloomtide", "Kraken of Gloomveil", "squid_red", Vector2(975, 233), 10, 33, Color(0.9, 0.8, 1.0), ["rain", "ring", "slam", "charge"], ["boss_gloom_tentacle", "boss_ink_mantle"]],
    "boss_skylord": ["The Jade Tengu", "Lord of the Jade Terraces", "tengu_blue", Vector2(1347, -4), 10, 40, Color(0.9, 0.95, 1.0), ["charge", "rain", "ring", "slam"], ["boss_skylord_fan", "boss_peak_crown"]],
    "boss_rex_prime": ["Tyrant Rex Prime", "Apex of Raptor Gulch", "tyrant_rex", Vector2(-1150, -15), 12, 47, Color(1.0, 0.8, 0.7), ["slam", "charge", "rain", "ring"], ["boss_apex_fang", "boss_rex_hide"]],
    # M9d: the main story's final boss at the foot of the Sage Spire (the Pale Regent unbound).
    "boss_eclipse_wyrm": ["The Eclipse Wyrm", "The Pale Regent Unbound", "eclipse_wyrm", Vector2(-760, -76), 11, 50, Color(0.72, 0.62, 0.95), ["rain", "ring", "charge", "slam"], ["boss_wyrm_scale", "boss_wyrmfang"]],
    "boss_majin": ["Majin Overlord", "The Demon at the Canyon's End", "demon_cyclops", Vector2(-760, 220), 12, 50, Color(1.0, 0.65, 0.9), ["slam", "charge", "rain", "ring"], ["boss_majin_halo", "boss_overlord_edge"]],
}

const RESPAWN := 1800.0
## HP: this many times an Elite of the same level, +60% per extra character in the arena.
const HEALTH_FACTOR := 22.0
const GROUP_BONUS := 0.6
## The basic bite hits for this many times an Elite's bite; attacks for their own factors.
const DAMAGE_FACTOR := 1.3
## Phases start below these shares of the health (the first phase at full health).
const PHASES := [1.0, 0.66, 0.33]
## Attack timing: [wind-up seconds, damage factor, size (px)]; slower in phase 1.
const ATTACKS := {
    "slam": [1.2, 2.0, 70.0],
    "charge": [1.0, 1.6, 34.0],
    "rain": [1.4, 1.4, 34.0],
    "ring": [1.5, 1.8, 120.0],
}
## Seconds between attacks by phase.
const ATTACK_GAP := [5.0, 3.8, 2.8]
## Credit share that counts as helping (lower than ordinary creatures: raids are shared).
const HELP_SHARE := 0.05
## Chance that a helper's personal drop is one of the boss's uniques instead of Epic+ gear.
const UNIQUE_CHANCE := 0.25
const XP_FACTOR := 25
const ZENI_FACTOR := 30
## Characters further than this from the arena's edge count as gone (the boss resets).
const LEASH_MARGIN := 80.0

## --- M7c (user decision: hidden elites in forests, on plateaus and in caves, and dungeon end
## bosses): the same fights on a smaller scale — two phases, a small arena, 7 × an Elite's HP, a
## guaranteed Rare-or-better personal drop for every helper, back after 10 minutes. Hidden elites
## show on the world map once a character has come near; dungeon bosses guard their chamber.
## Same shape as RAID (user request after M15: each has its own unique).
const ELITES := {
    "elite_oakfang": ["Old Oakfang", "Hidden in Thornwood", "gnasher", Vector2(125, 64), 5, 9, Color(0.8, 1.0, 0.7), ["slam", "charge"], ["elite_oakfang_cleaver"]],
    "elite_snowmane": ["Snowmane", "Ghost of the Glacier", "frost_bear", Vector2(13, -170), 5, 15, Color(0.85, 0.95, 1.0), ["slam", "ring"], ["elite_snowmane_hood"]],
    "elite_dune_stalker": ["The Dune Stalker", "Terror of the Sands", "dune_viper", Vector2(-125, 162), 5, 14, Color(1.0, 0.85, 0.6), ["charge", "rain"], ["elite_stalker_kris"]],
    "elite_ambershriek": ["Ambershriek", "Owl of the Harvest Moon", "amber_owl", Vector2(172, 366), 5, 17, Color(1.0, 0.75, 0.5), ["rain", "charge"], ["elite_shriekfeather_bow"]],
    "elite_fen_witch": ["The Fen Witch", "Mother of Mirecaps", "mirecap", Vector2(-139, 305), 5, 19, Color(0.75, 0.9, 0.7), ["rain", "ring"], ["elite_fen_witch_rod"]],
    "elite_bamboo_ronin": ["The Bamboo Ronin", "Wanderer of Sakura Vale", "bamboo_sprite", Vector2(517, 83), 5, 18, Color(0.85, 1.0, 0.75), ["charge", "slam"], ["elite_ronin_knuckles"]],
    "elite_storm_eye": ["The Storm Eye", "Watcher of the Steppe", "thunder_eye", Vector2(1051, -178), 5, 26, Color(0.85, 0.9, 1.0), ["rain", "ring"], ["elite_storm_eye_amulet"]],
    "elite_nightweaver": ["Nightweaver", "Queen of Gloomveil's Webs", "dusk_spider", Vector2(939, 230), 5, 32, Color(0.85, 0.7, 1.0), ["slam", "rain"], ["elite_nightweaver_mantle"]],
    "elite_cloud_serpent": ["The Cloud Serpent", "Spirit of the Terraces", "sky_dragonling", Vector2(1373, 0), 5, 39, Color(0.85, 1.0, 0.95), ["charge", "ring"], ["elite_cloud_serpent_lance"]],
    "elite_rex_alpha": ["Rex Alpha", "The Gulch's Fiercest", "raptor", Vector2(-704, 31), 5, 46, Color(1.0, 0.85, 0.75), ["charge", "slam"], ["elite_alpha_reaper"]],
}
const ELITE_HEALTH := 7.0
const ELITE_RESPAWN := 600.0
const ELITE_PHASES := [1.0, 0.5]
## Hidden elites are discovered from this far (px).
const DISCOVER_RADIUS := 140.0

## The dungeon end bosses' own uniques (user request after M15).
const DUNGEON_UNIQUES := {
    "dungeon_thornwood_hollow": ["dungeon_rootmaw_crown", "dungeon_rotting_staff"],
    "dungeon_frostfang_cavern": ["dungeon_cyclops_ring", "dungeon_frostfang_fists"],
    "dungeon_ember_depths": ["dungeon_magmaw_fang", "dungeon_lava_plate"],
    "dungeon_gloom_catacombs": ["dungeon_abbot_staff", "dungeon_abbot_cowl"],
    "dungeon_jade_grotto": ["dungeon_jade_blade", "dungeon_jade_charm"],
}
## Dungeon end bosses, built from the dungeon catalogue: [name, title, sprite, arena (boss
## chamber), radius, level, tint, attacks, uniques].
static var DUNGEON_BOSSES: Dictionary = _dungeon_bosses()

static func _dungeon_bosses() -> Dictionary:
    var dungeons := preload("res://scripts/dungeons/dungeon_catalogue.gd")
    var all := {}
    for id in dungeons.ORDER:
        var spec: Array = dungeons.DUNGEONS[id]
        var chamber: Array = dungeons.rooms(id)[3]
        all[dungeons.boss_id(id)] = [spec[5], spec[0], spec[6], chamber[0], int(chamber[1].x) - 3, int(spec[7]), Color(0.9, 0.85, 1.0), ["slam", "rain", "ring", "charge"], DUNGEON_UNIQUES.get(dungeons.boss_id(id), [])]
    return all

static func entry(id: String) -> Array:
    if RAID.has(id):
        return RAID[id]
    if ELITES.has(id):
        return ELITES[id]
    return DUNGEON_BOSSES.get(id, [])

static func all_ids() -> Array:
    return RAID.keys() + ELITES.keys() + DUNGEON_BOSSES.keys()

static func is_boss(id: String) -> bool:
    return RAID.has(id) or ELITES.has(id) or DUNGEON_BOSSES.has(id)

static func is_raid(id: String) -> bool:
    return RAID.has(id)

static func is_hidden_elite(id: String) -> bool:
    return ELITES.has(id)

static func centre(id: String) -> Vector2:
    var map := preload("res://scripts/world/world_map.gd")
    return map.to_world(entry(id)[3]) + Vector2(map.TILE / 2.0, map.TILE / 2.0)

static func radius(id: String) -> float:
    return float(entry(id)[4]) * 16.0

static func level(id: String) -> int:
    # M11b: a heroic dungeon's end boss is stronger.
    if DUNGEON_BOSSES.has(id):
        return preload("res://scripts/dungeons/dungeon_catalogue.gd").boss_level(id.trim_prefix("dungeon_"))
    return int(entry(id)[5])

static func display_name(id: String) -> String:
    return "%s, %s" % [entry(id)[0], entry(id)[1]]

static func health_factor(id: String) -> float:
    return HEALTH_FACTOR if is_raid(id) else ELITE_HEALTH

static func respawn(id: String) -> float:
    return RESPAWN if is_raid(id) else ELITE_RESPAWN

static func phases(id: String) -> Array:
    return PHASES if is_raid(id) else ELITE_PHASES

## Phase (0-based) for a health share.
static func phase_for(share: float, id: String = "") -> int:
    var list: Array = phases(id) if not id.is_empty() else PHASES
    var phase := 0
    for index in range(list.size()):
        if share <= list[index]:
            phase = index
    return phase

## Arena centre tiles of overworld bosses (props keep clear of them, like other content spots).
static func arena_tiles() -> Array:
    return (RAID.values() + ELITES.values()).map(func(entry): return [entry[3], entry[4]])
