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
    "scythe": ["Scythe", 4, 2, 0], "bow": ["Bow", 1, 3, 0], "staff": ["Staff", 1, 3, 1], "fist": ["Fist weapon", 2, 1, 0],
    "head": ["Helmet", 3, 0, 0], "body": ["Armour", 5, 0, 0], "hands": ["Gloves", 2, 0, 0], "feet": ["Boots", 2, 0, 0],
    "accessory": ["Ring or amulet", 1, 0, 1],
}
const WEAPON_TYPES := ["dagger", "sword", "spear", "scythe", "bow", "staff", "fist"]


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

## --- M11e: Cooking, Enchanting and Tailoring.
## Meals, same shape as POTIONS ("fish_*" is any fish). "wisdom" gives more XP from everything.
const FOODS := {
    "food_grilled_fish": ["Grilled Fish", 1, 30, "heal", 60, 5.0, {"fish_*": 1}, "Restores 60 HP over 5 s."],
    "food_herb_bread": ["Herb Bread", 6, 45, "heal", 100, 5.0, {"herb_mint": 2, "herb_sunbloom": 1}, "Restores 100 HP over 5 s."],
    "food_fisherman_stew": ["Fisherman's Stew", 12, 120, "iron", 5, 600.0, {"fish_*": 2, "herb_sunbloom": 1}, "+5 defence for 10 minutes."],
    "food_ember_skewer": ["Ember Skewer", 20, 220, "might", 15, 600.0, {"salamander_scale": 1, "fish_*": 1, "herb_ambercap": 1}, "+15% damage for 10 minutes."],
    "food_sakura_rice_ball": ["Sakura Rice Ball", 26, 260, "speed", 20, 600.0, {"herb_sakura": 2, "fish_*": 1}, "+20% movement speed for 10 minutes."],
    "food_scholars_soup": ["Scholar's Soup", 32, 400, "wisdom", 20, 900.0, {"herb_steppe_sage": 2, "fish_*": 2}, "+20% XP from everything for 15 minutes."],
    "food_moonlit_feast": ["Moonlit Feast", 40, 900, "wisdom", 35, 900.0, {"herb_moonbloom": 1, "herb_jade_lotus": 1, "fish_*": 3}, "+35% XP from everything for 15 minutes."],
    "food_dragon_banquet": ["Dragon Banquet", 46, 1600, "full", 0, 0.0, {"herb_dragon_blossom": 1, "fish_*": 3, "ember_core": 1}, "Instantly restores all HP and Magicules."],
}
## Runes inscribed by Enchanting: rune → [level, ingredients].
const ENCHANTS := {
    "rune_vigor": [1, {"gem_*": 1, "gnasher_essence": 2}],
    "rune_focus": [6, {"gem_*": 1, "wisp_mote": 2}],
    "rune_swift": [12, {"gem_*": 1, "owl_feather": 2}],
    "rune_might": [18, {"gem_*": 1, "ember_core": 1, "thornback_quill": 2}],
    "rune_ward": [24, {"gem_*": 2, "kappa_shell": 2}],
    "rune_flow": [30, {"gem_*": 2, "mirecap_spore": 2}],
    "rune_leech": [38, {"gem_ruby": 1, "viper_scale": 3, "herb_nightshade": 2}],
    "rune_thorns": [44, {"gem_emerald": 2, "thornback_quill": 4, "bar_adamantite": 1}],
}
## Tailoring materials → [name, Tailoring level, gear level band].
const CLOTHS := {
    "bamboo_fiber": ["Bamboo Weave", 1, [1, 6]],
    "frost_pelt": ["Frost Pelt", 8, [5, 11]],
    "viper_scale": ["Viperscale", 14, [9, 16]],
    "owl_feather": ["Featherdown", 20, [14, 22]],
    "salamander_scale": ["Salamander Hide", 28, [20, 32]],
    "kappa_shell": ["Kappa Shell", 36, [28, 40]],
    "lantern_paper": ["Spirit Silk", 44, [36, 48]],
}
## Pieces Tailoring sews: [name, materials, extra (a herb for dye, any)].
const TAILOR := {"head": ["Hood", 2], "body": ["Robe", 4], "hands": ["Gloves", 2], "feet": ["Boots", 2]}

static func is_food(id: String) -> bool:
    return FOODS.has(id)

## A meal's or potion's row (POTIONS shape).
static func consumable(id: String) -> Array:
    return FOODS[id] if FOODS.has(id) else POTIONS.get(id, [])

## A light-armour base of a slot inside a cloth's level band (the high bands' pieces have a rarity
## floor; the sewn piece is then at least that rare, see Player.craft).
static func tailor_base(slot: String, cloth: String, _rarity: int, rng: RandomNumberGenerator) -> String:
    var band: Array = CLOTHS[cloth][2]
    var pool: Array = []
    for id in GEAR.BASES:
        var spec: Dictionary = GEAR.BASES[id]
        if spec.slot != slot or spec.has("unique") or spec.has("set"):
            continue
        var level: int = int(spec.get("level", 1))
        if level >= band[0] and level <= band[1]:
            pool.append(id)
    return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""

static func is_bar(id: String) -> bool:
    return BARS.has(id)

static func is_herb(id: String) -> bool:
    return PRO.HERBS.has(id)

static func is_potion(id: String) -> bool:
    return POTIONS.has(id) and not id in ["healing_draught", "magicule_tonic"]

## Bag goods of this catalogue (herbs are profession resources, see ProfessionCatalogue).
static func is_good(id: String) -> bool:
    return is_bar(id) or is_potion(id) or is_food(id)

static func good_info(id: String) -> Array:
    if is_bar(id):
        return [BARS[id][0], "Bars", "Smelted metal for forging gear (Smithing %d)." % BARS[id][1]]
    if is_food(id):
        return [FOODS[id][0], "Meals", FOODS[id][7] + " Eat it from the bag."]
    return [POTIONS[id][0], "Potions", POTIONS[id][7] + " Use it from the bag."]

static func price(id: String) -> int:
    if is_bar(id):
        return BARS[id][2]
    if POTIONS.has(id):
        return POTIONS[id][2]
    if FOODS.has(id):
        return FOODS[id][2]
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
        # User request after M15: forge a boss's uniques from its own material and bars of the tier.
        var loot := preload("res://scripts/bosses/boss_loot.gd")
        var bosses := preload("res://scripts/bosses/boss_catalogue.gd")
        for boss in bosses.all_ids():
            for base in bosses.entry(boss)[8]:
                if not GEAR.BASES.has(base):
                    continue
                var level: int = int(GEAR.BASES[base].get("level", 1))
                var needs := {loot.material(boss): int(loot.FORGE_COST[loot.kind(boss)]), bar_for_level(level): loot.FORGE_BARS}
                all["bossforge:" + base] = ["Forge %s" % GEAR.BASES[base].name, mini(50, level), needs]
    elif profession == "alchemy":
        for potion in POTIONS:
            all["brew:" + potion] = ["Brew " + POTIONS[potion][0], int(POTIONS[potion][1]), POTIONS[potion][6]]
    elif profession == "cooking":
        for food in FOODS:
            all["cook:" + food] = ["Cook " + FOODS[food][0], int(FOODS[food][1]), FOODS[food][6]]
    elif profession == "enchanting":
        var upgrades := preload("res://scripts/items/upgrade_catalogue.gd")
        for rune in ENCHANTS:
            all["enchant:" + rune] = ["Inscribe " + upgrades.RUNES[rune][0], int(ENCHANTS[rune][0]), ENCHANTS[rune][1]]
    elif profession == "tailoring":
        for cloth in CLOTHS:
            for slot in TAILOR:
                all["tailor:%s:%s" % [cloth, slot]] = ["%s %s" % [CLOTHS[cloth][0], TAILOR[slot][0]], int(CLOTHS[cloth][1]) + 2, {cloth: int(TAILOR[slot][1])}]
    return all

static func recipe(id: String) -> Array:
    for profession in ["smithing", "alchemy", "cooking", "enchanting", "tailoring"]:
        var all := recipes(profession)
        if all.has(id):
            return [profession] + all[id]
    return []

## The bar whose forging band holds an item level (the highest band below it when none does).
static func bar_for_level(level: int) -> String:
    var best := "bar_bronze"
    for bar in BAR_LEVELS:
        if level >= int(BAR_LEVELS[bar][0]):
            best = bar
    return best

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
