extends RefCounted
## Raid boss uniques (M7a, user decision: each boss has one or two items only it drops). They use
## the item expansion's unique art and abilities; their stats grow with the boss's level (a level
## 45 boss's weapon hits far harder than a level 10 boss's). Merged into GearCatalogue.BASES.
## No preloads (GearCatalogue preloads this file).

## [name, slot, weapon type ("" for armour), icon atlas, cell, ability, element, level, rarity floor]
const UNIQUES := {
    "boss_grumble_horn": ["Grumblehorn's Horn", "accessory", "", "amulet", 56, "berserker", "", 8, 4],
    "boss_thorncrown": ["Thorncrown", "head", "", "head", 56, "warden", "nature", 11, 4],
    "boss_matriarch_fang": ["Matriarch's Fang", "weapon", "dagger", "dagger", 122, "overgrowth", "nature", 11, 4],
    "boss_mirror_quill": ["Mirror Quill", "weapon", "spear", "spear", 95, "glacier", "frost", 13, 4],
    "boss_crater_heart": ["Heart of the Crater", "accessory", "", "amulet", 56, "phoenix", "fire", 17, 4],
    "boss_ashen_spines": ["Ashen Spines", "weapon", "scythe", "scythe", 78, "inferno", "fire", 17, 4],
    "boss_rimefang_claw": ["Rimefang Claw", "weapon", "sword", "sword", 118, "glacier", "frost", 22, 4],
    "boss_glacier_mantle": ["Glacier Mantle", "body", "", "body", 85, "warden", "frost", 22, 4],
    "boss_sandmaw_fang": ["Sandmaw Fang", "weapon", "dagger", "dagger", 121, "executioner", "", 21, 4],
    "boss_dune_wraps": ["Dune Wraps", "feet", "", "feet", 56, "windwalker", "", 21, 4],
    "boss_hollow_quill": ["Hollowwing Quill", "weapon", "bow", "bow", 103, "starfall", "holy", 26, 4],
    "boss_elder_feather": ["Elder Feather", "accessory", "", "ring", 24, "windwalker", "", 26, 4],
    "boss_shogun_blade": ["Shogun's Blade", "weapon", "sword", "sword", 119, "executioner", "shadow", 30, 4],
    "boss_kappa_shell": ["Kappa Shell", "body", "", "body", 85, "warden", "nature", 30, 4],
    "boss_empress_lantern": ["Empress's Lantern", "accessory", "", "amulet", 56, "radiance", "holy", 30, 4],
    "boss_sakura_veil": ["Sakura Veil", "head", "", "head", 56, "windwalker", "holy", 30, 4],
    "boss_pyreclaw_scythe": ["Pyreclaw", "weapon", "scythe", "scythe", 77, "inferno", "fire", 34, 4],
    "boss_salamander_crown": ["Salamander Crown", "head", "", "head", 56, "berserker", "fire", 34, 4],
    "boss_raijin_blade": ["Raijin's Blade", "weapon", "sword", "sword", 117, "thunderlord", "storm", 27, 4],
    "boss_storm_kabuto": ["Storm Kabuto", "head", "", "head", 56, "warden", "storm", 27, 4],
    "boss_gloom_tentacle": ["Gloom Tentacle", "weapon", "scythe", "scythe", 79, "bloodthirst", "shadow", 33, 4],
    "boss_ink_mantle": ["Ink Mantle", "body", "", "body", 84, "phoenix", "shadow", 33, 4],
    "boss_skylord_fan": ["Skylord's Fan", "weapon", "bow", "bow", 101, "starfall", "storm", 40, 5],
    "boss_peak_crown": ["Crown of the Peaks", "head", "", "head", 56, "windwalker", "frost", 40, 5],
    "boss_apex_fang": ["Apex Fang", "weapon", "spear", "spear", 93, "thunderlord", "storm", 45, 5],
    "boss_rex_hide": ["Rex Hide", "body", "", "body", 84, "phoenix", "", 45, 5],
    "boss_majin_halo": ["Majin Halo", "accessory", "", "ring", 25, "eclipse", "shadow", 50, 5],
    "boss_overlord_edge": ["Overlord's Edge", "weapon", "sword", "sword", 117, "eclipse", "shadow", 50, 5],
    # M9d: the Eclipse Wyrm, the story's final boss.
    "boss_wyrm_scale": ["Eclipse Wyrm Scale", "body", "", "body", 84, "warden", "shadow", 50, 5],
    "boss_wyrmfang": ["Wyrmfang", "weapon", "spear", "spear", 94, "eclipse", "shadow", 50, 5],
    # M9d: the story's ending rewards (never dropped; given by the ending choice).
    "story_moonwarden_crescent": ["Moonwarden's Crescent", "weapon", "scythe", "scythe", 78, "moonwarden", "holy", 50, 5],
    "story_eclipse_reaper": ["Eclipse Sovereign's Reaper", "weapon", "scythe", "scythe", 77, "sovereign", "shadow", 50, 5],
}

## Common-rarity stat ranges of the best item-expansion uniques (level 18-20), per type.
const TEMPLATES := {
    "sword": {"damage": [28, 35]}, "dagger": {"damage": [18, 25]}, "spear": {"damage": [30, 39]},
    "scythe": {"damage": [35, 46]}, "bow": {"damage": [21, 28]},
    "head": {"hp": [13, 22], "defense": [2, 4], "speed": [4, 9]},
    "body": {"hp": [23, 37], "defense": [3, 8], "strike": [2, 5]},
    "feet": {"speed": [8, 20], "hp": [6, 12]},
    "accessory": {"regen": [0.5, 1.2], "strike": [2, 5], "hp": [8, 16]},
}

static var BASES: Dictionary = _build()

## Stats grow 3% per level above 18 (shrink below it, at most to 70%).
static func level_factor(level: int) -> float:
    return clampf(1.0 + 0.03 * (level - 18), 0.7, 3.0)

static func _build() -> Dictionary:
    var all := {}
    for id in UNIQUES:
        var spec: Array = UNIQUES[id]
        var type: String = spec[2] if not String(spec[2]).is_empty() else spec[1]
        var factor := level_factor(int(spec[7]))
        var stats := {}
        for stat in TEMPLATES[type]:
            var low: float = TEMPLATES[type][stat][0]
            var high: float = TEMPLATES[type][stat][1]
            if stat == "regen":
                stats[stat] = [snappedf(low * factor, 0.1), snappedf(high * factor, 0.1)]
            else:
                stats[stat] = [int(round(low * factor)), int(round(high * factor))]
        var base := {"slot": spec[1], "unique": spec[5], "name": spec[0], "look": "icon", "element": spec[6], "level": int(spec[7]), "min_rarity": int(spec[8]), "icon": spec[3], "cell": int(spec[4]), "archetype": "", "stats": stats, "boss": true}
        if not String(spec[2]).is_empty():
            base["weapon"] = spec[2]
        all[id] = base
    return all
