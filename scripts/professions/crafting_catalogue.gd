extends RefCounted
## Smithing and Alchemy (M6c, user decisions in docs/M4_PLAN.md M6). Smithing smelts ores into bars
## and forges bars and logs into gear (weapons, armour, accessories) whose level follows the bar
## and whose rarity improves with Smithing; Alchemy brews herbs, fish and creature materials into
## potions and elixirs. Every recipe can be tried at any level (soft gate) and shows its chance;
## a failed try loses the ingredients (Thrifty, level 20: 20% kept). Smithing works at the camp's
## Forge or in any town; Alchemy at the camp's Essence Shrine or in any town.
const PRO := preload("res://scripts/professions/profession_catalogue.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")

## Bars: [name, Smithing level, price, colour, ingredients {id: count}]
const BARS := {
    "bar_bronze": ["Bronze Bar", 1, 30, Color("c88a4a"), {"ore_copper": 1, "ore_tin": 1}],
    "bar_iron": ["Iron Bar", 10, 50, Color("8a8f96"), {"ore_iron": 2}],
    "bar_steel": ["Steel Bar", 15, 80, Color("b8c4d0"), {"ore_iron": 1, "ore_coal": 2}],
    "bar_silver": ["Silver Bar", 18, 100, Color("e8eef4"), {"ore_silver": 2}],
    "bar_gold": ["Gold Bar", 25, 170, Color("f0c840"), {"ore_gold": 2}],
    "bar_mithril": ["Mithril Bar", 32, 300, Color("6fb8ff"), {"ore_mithril": 2, "ore_coal": 1}],
    "bar_adamantite": ["Adamantite Bar", 40, 480, Color("4fd08a"), {"ore_adamantite": 2, "ore_coal": 2}],
    "bar_starmetal": ["Starmetal Bar", 46, 800, Color("d8a0ff"), {"ore_starmetal": 2, "gem_sapphire": 1}],
}
## The gear level band each bar forges: [lowest, highest] base level.
const BAR_LEVELS := {
    "bar_bronze": [1, 4], "bar_iron": [4, 7], "bar_steel": [6, 9], "bar_silver": [8, 11],
    # M7b: the higher bars forge the level 24-48 tiers.
    "bar_gold": [12, 18], "bar_mithril": [18, 26], "bar_adamantite": [24, 38], "bar_starmetal": [36, 48],
}
## What can be forged: [name, bars, logs (any wood), gems (any)]
const FORGE := {
    "dagger": ["Dagger", 2, 1, 0], "sword": ["Sword", 3, 1, 0], "spear": ["Spear", 3, 2, 0],
    "scythe": ["Scythe", 4, 2, 0], "bow": ["Bow", 1, 3, 0],
    "head": ["Helmet", 3, 0, 0], "body": ["Armour", 5, 0, 0], "hands": ["Gloves", 2, 0, 0], "feet": ["Boots", 2, 0, 0],
    "accessory": ["Ring or amulet", 1, 0, 1],
}
const WEAPON_TYPES := ["dagger", "sword", "spear", "scythe", "bow"]


## Potions: [name, Alchemy level, price, effect, amount, seconds, ingredients, description]
## Effects: heal / tonic over 5 s, full (instant HP and Magicules), speed / might / iron buffs.
const POTIONS := {
    "healing_draught": ["Healing Draught", 1, 25, "heal", 40, 5.0, {"herb_mint": 2, "minnow": 1}, "Restores 40 HP over 5 s (Q)."],
    "magicule_tonic": ["Magicule Tonic", 3, 25, "tonic", 40, 5.0, {"herb_mint": 2, "gnasher_essence": 1}, "Restores 40 Magicules over 5 s (Z)."],
    "potion_greater_healing": ["Greater Healing Draught", 15, 120, "heal", 120, 5.0, {"herb_sunbloom": 2, "salmon": 1}, "Restores 120 HP over 5 s."],
    "potion_greater_tonic": ["Greater Magicule Tonic", 18, 120, "tonic", 120, 5.0, {"herb_ambercap": 2, "wisp_mote": 1}, "Restores 120 Magicules over 5 s."],
    "elixir_swiftness": ["Elixir of Swiftness", 22, 200, "speed", 25, 120.0, {"herb_sakura": 2, "koi": 1}, "+25% movement speed for 2 minutes."],
    "elixir_iron": ["Elixir of Iron Skin", 25, 220, "iron", 6, 120.0, {"herb_ambercap": 2, "bar_iron": 1}, "+6 defence for 2 minutes."],
    "elixir_might": ["Elixir of Might", 28, 260, "might", 20, 120.0, {"herb_bogmoss": 2, "ember_core": 1}, "+20% damage for 2 minutes."],
    "potion_moonlight": ["Moonlight Draught", 30, 400, "heal", 220, 5.0, {"herb_moonbloom": 2, "herb_storm_orchid": 1}, "Restores 220 HP over 5 s."],
    "senzu_bean": ["Senzu Bean", 45, 1500, "full", 0, 0.0, {"herb_senzu": 3, "ki_carp": 1}, "Instantly restores all HP and Magicules."],
}
## Potions that share the draught/tonic cooldown (the rest are elixirs with their own timers).
const COOLDOWN_EFFECTS := ["heal", "tonic", "full"]

static func is_bar(id: String) -> bool:
    return BARS.has(id)

static func is_herb(id: String) -> bool:
    return PRO.HERBS.has(id)

static func is_potion(id: String) -> bool:
    return POTIONS.has(id) and not id in ["healing_draught", "magicule_tonic"]

## Bag goods of this catalogue (herbs are profession resources, see ProfessionCatalogue).
static func is_good(id: String) -> bool:
    return is_bar(id) or is_potion(id)

static func good_info(id: String) -> Array:
    if is_bar(id):
        return [BARS[id][0], "Bars", "Smelted metal for forging gear (Smithing %d)." % BARS[id][1]]
    return [POTIONS[id][0], "Potions", POTIONS[id][7] + " Use it from the bag."]

static func price(id: String) -> int:
    if is_bar(id):
        return BARS[id][2]
    if POTIONS.has(id):
        return POTIONS[id][2]
    return 0

## Every recipe of a profession: {id: [name, level, ingredients {id or "log_*"/"gem_*": count}]}.
static func recipes(profession: String) -> Dictionary:
    var all := {}
    if profession == "smithing":
        for bar in BARS:
            all["smelt:" + bar] = ["Smelt " + BARS[bar][0], int(BARS[bar][1]), BARS[bar][4]]
        for bar in BARS:
            for kind in FORGE:
                var needs := {bar: int(FORGE[kind][1])}
                if int(FORGE[kind][2]) > 0:
                    needs["log_*"] = int(FORGE[kind][2])
                if int(FORGE[kind][3]) > 0:
                    needs["gem_*"] = int(FORGE[kind][3])
                all["forge:%s:%s" % [bar, kind]] = ["%s %s" % [BARS[bar][0].trim_suffix(" Bar"), FORGE[kind][0]], int(BARS[bar][1]) + 2, needs]
    elif profession == "alchemy":
        for potion in POTIONS:
            all["brew:" + potion] = ["Brew " + POTIONS[potion][0], int(POTIONS[potion][1]), POTIONS[potion][6]]
    return all

static func recipe(id: String) -> Array:
    for profession in ["smithing", "alchemy"]:
        var all := recipes(profession)
        if all.has(id):
            return [profession] + all[id]
    return []

## Gear rarity weights for a forged item: better with Smithing above the recipe, Mythic at 50.
static func forge_weights(level: int, required: int) -> Array:
    var q := clampf((level - required) / 10.0, 0.0, 3.0) + (0.5 if level >= 30 else 0.0)
    return [maxf(0.0, 50.0 - 15.0 * q), 30.0, 15.0 + 5.0 * q, 4.0 + 4.0 * q, 1.0 + 2.0 * q, 0.5 + q if level >= 50 else 0.0]

## A base of the kind at the bar's level band (no uniques or set pieces), allowed at `rarity`.
static func forge_base(kind: String, bar: String, rarity: int, rng: RandomNumberGenerator) -> String:
    var band: Array = BAR_LEVELS[bar]
    var pool: Array = []
    for id in GEAR.BASES:
        var spec: Dictionary = GEAR.BASES[id]
        var type: String = spec.get("weapon", spec.slot) if kind in WEAPON_TYPES else spec.slot
        if type != kind or spec.has("unique") or spec.has("set") or int(spec.get("min_rarity", 0)) > rarity:
            continue
        var level: int = int(spec.get("level", 1))
        if level >= band[0] and level <= band[1]:
            pool.append(id)
    if pool.is_empty():
        for id in GEAR.BASES:
            var spec: Dictionary = GEAR.BASES[id]
            var type: String = spec.get("weapon", spec.slot) if kind in WEAPON_TYPES else spec.slot
            if type == kind and not spec.has("unique") and not spec.has("set") and int(spec.get("min_rarity", 0)) <= rarity:
                pool.append(id)
    return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""
