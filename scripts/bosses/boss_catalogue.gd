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
    "boss_grumblehorn": ["Old Grumblehorn", "Terror of the Meadows", "gnasher", Vector2(170, 168), 9, 8, Color(0.9, 1.0, 0.75), ["slam", "charge"], ["boss_grumble_horn"]],
    "boss_gnashmaw": ["Gnashmaw", "Matriarch of Thornwood", "gnasher", Vector2(106, 85), 9, 11, Color(0.75, 1.0, 0.7), ["slam", "charge", "rain"], ["boss_thorncrown", "boss_matriarch_fang"]],
    "boss_quillback": ["Quillback Colossus", "Warden of Mirror Lake", "thornback", Vector2(222, 88), 8, 13, Color(0.7, 0.85, 1.0), ["slam", "rain", "ring"], ["boss_mirror_quill"]],
    "boss_cinderquill": ["Cinderquill", "Heart of the Crater", "thornback", Vector2(274, 166), 9, 17, Color(1.0, 0.6, 0.45), ["slam", "rain", "ring", "charge"], ["boss_crater_heart", "boss_ashen_spines"]],
    "boss_rimefang": ["Rimefang", "Glacier King", "frost_bear", Vector2(187, -97), 10, 22, Color(0.75, 0.9, 1.0), ["slam", "charge", "ring"], ["boss_rimefang_claw", "boss_glacier_mantle"]],
    "boss_sandmaw": ["Sandmaw", "Dune Serpent", "dune_viper", Vector2(-153, 103), 10, 21, Color(1.0, 0.85, 0.55), ["charge", "rain", "ring"], ["boss_sandmaw_fang", "boss_dune_wraps"]],
    "boss_hollowwing": ["Hollowwing", "Elder Owl of Ambervale", "amber_owl", Vector2(202, 338), 10, 26, Color(1.0, 0.75, 0.45), ["rain", "charge", "ring"], ["boss_hollow_quill", "boss_elder_feather"]],
    "boss_bog_shogun": ["The Bog Shogun", "Lord of Mirewood", "bog_kappa", Vector2(-170, 398), 10, 30, Color(0.65, 0.9, 0.6), ["slam", "rain", "ring", "charge"], ["boss_shogun_blade", "boss_kappa_shell"]],
    "boss_lantern_empress": ["The Lantern Empress", "Light of Sakura Vale", "paper_lantern", Vector2(573, 40), 10, 30, Color(1.0, 0.7, 0.8), ["rain", "ring", "slam"], ["boss_empress_lantern", "boss_sakura_veil"]],
    "boss_pyreclaw": ["Pyreclaw", "Salamander King", "salamander", Vector2(583, 313), 10, 34, Color(1.0, 0.5, 0.35), ["slam", "charge", "rain", "ring"], ["boss_pyreclaw_scythe", "boss_salamander_crown"]],
    "boss_rex_prime": ["Tyrant Rex Prime", "Apex of Raptor Gulch", "tyrant_rex", Vector2(-1150, -15), 12, 45, Color(1.0, 0.8, 0.7), ["slam", "charge", "rain", "ring"], ["boss_apex_fang", "boss_rex_hide"]],
    "boss_majin": ["Majin Overlord", "The Demon at the Canyon's End", "demon_king", Vector2(-760, 220), 12, 50, Color(1.0, 0.65, 0.9), ["slam", "charge", "rain", "ring"], ["boss_majin_halo", "boss_overlord_edge"]],
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

static func is_boss(id: String) -> bool:
    return RAID.has(id)

static func centre(id: String) -> Vector2:
    var map := preload("res://scripts/world/world_map.gd")
    return map.to_world(RAID[id][3]) + Vector2(map.TILE / 2.0, map.TILE / 2.0)

static func radius(id: String) -> float:
    return float(RAID[id][4]) * 16.0

static func level(id: String) -> int:
    return int(RAID[id][5])

static func display_name(id: String) -> String:
    return "%s, %s" % [RAID[id][0], RAID[id][1]]

## Phase (0-based) for a health share.
static func phase_for(share: float) -> int:
    var phase := 0
    for index in range(PHASES.size()):
        if share <= PHASES[index]:
            phase = index
    return phase

## Arena centre tiles (props keep clear of them, like other content spots).
static func arena_tiles() -> Array:
    return RAID.values().map(func(entry): return [entry[3], entry[4]])
