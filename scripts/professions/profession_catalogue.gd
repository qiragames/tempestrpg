extends RefCounted
## Professions (M6, user decisions in docs/M4_PLAN.md M6): Woodcutting, Mining, Fishing, Smithing
## and Alchemy level 1–50 by doing them. Gates are soft: anything can be tried, but below the
## required level it is slower and fails more often — and the success chance is always shown.
## Levels give small perks (faster work, a double-yield chance) and a milestone every 10 levels.
## Pure data and rules; ResourceNodes, Player and the panels apply them.
const MAP := preload("res://scripts/world/world_map.gd")

const MAX_LEVEL := 50
## [name, short description]
const PROFESSIONS := {
    "woodcutting": ["Woodcutting", "Fell trees with an axe for logs. Rarer woods grow in harder regions."],
    "mining": ["Mining", "Break ore rocks with a pickaxe for ores and the odd gem."],
    "fishing": ["Fishing", "Catch fish with a rod at lakes and the sea."],
    "smithing": ["Smithing", "Smelt ores into bars and forge gear (camp Forge or any town)."],
    "alchemy": ["Alchemy", "Brew potions from herbs, fish and creature materials (camp Shrine or any town)."],
    # M11e (user request): three more crafts.
    "cooking": ["Cooking", "Cook fish and herbs into meals that heal and give long buffs (camp Shrine or any town)."],
    "enchanting": ["Enchanting", "Inscribe runes for your gear's sockets from gems and creature materials (camp Shrine or any town)."],
    "tailoring": ["Tailoring", "Sew light armour from pelts, scales, feathers and shells (camp Forge or any town)."],
}
const ORDER := ["woodcutting", "mining", "fishing", "smithing", "alchemy", "cooking", "enchanting", "tailoring"]

## Milestones every 10 levels: [level, name, description]. Effects are applied by the rules below.
const MILESTONES := {
    "woodcutting": [[10, "Sure Grip", "+5% success chance"], [20, "Lumberjack", "Trees give 1 more log"], [30, "Heartwood", "Rare sap from any tree (1%)"], [40, "Second Wind", "+10% double-log chance"], [50, "Master Woodcutter", "+10% faster swings, golden axe"]],
    "mining": [[10, "Sure Grip", "+5% success chance"], [20, "Keen Eye", "Gem chance doubled"], [30, "Deep Veins", "Rocks give 1 more ore"], [40, "Second Wind", "+10% double-ore chance"], [50, "Master Miner", "+10% faster swings, golden pickaxe"]],
    "fishing": [[10, "Steady Hands", "+5% catch chance"], [20, "Patient", "Bites come 25% sooner"], [30, "Lure Lore", "Rare fish chance ×1.5"], [40, "Sea Legend", "Mythical creature chance ×2"], [50, "Master Angler", "Golden rod, +10% catch chance"]],
    "smithing": [[10, "Sure Hand", "+5% success chance"], [20, "Thrifty", "20% chance to keep a bar"], [30, "Fine Temper", "Forged gear one rarity step better more often"], [40, "Double Smelt", "+10% double-bar chance"], [50, "Master Smith", "Forged gear can be Mythic"]],
    "alchemy": [[10, "Sure Hand", "+5% success chance"], [20, "Thrifty", "20% chance to keep an ingredient"], [30, "Potent", "Potions last 50% longer"], [40, "Double Brew", "+10% double-potion chance"], [50, "Master Alchemist", "Elixirs brew twice"]],
    # M11e.
    "cooking": [[10, "Sure Hand", "+5% success chance"], [20, "Thrifty", "20% chance to keep the ingredients"], [30, "Hearty", "Meals last 50% longer"], [40, "Second Helping", "+10% double-meal chance"], [50, "Master Chef", "The title, and the finest cooking"]],
    "enchanting": [[10, "Sure Hand", "+5% success chance"], [20, "Thrifty", "20% chance to keep the ingredients"], [30, "Steady Script", "20% chance to inscribe a second rune"], [40, "Twin Runes", "+10% double-rune chance"], [50, "Master Enchanter", "The title, and the finest runes"]],
    "tailoring": [[10, "Sure Hand", "+5% success chance"], [20, "Thrifty", "20% chance to keep the materials"], [30, "Fine Stitching", "Sewn gear one rarity step better more often"], [40, "Double Stitch", "10% chance to sew a second piece"], [50, "Master Tailor", "Sewn gear can be Mythic"]],
}

static func xp_for(level: int) -> int:
    return int(round(30.0 * pow(maxf(0, level - 1), 2.3)))

static func max_xp() -> int:
    return xp_for(MAX_LEVEL)

static func level_for(xp: int) -> int:
    var level := 1
    while level < MAX_LEVEL and xp >= xp_for(level + 1):
        level += 1
    return level

static func initial_state() -> Dictionary:
    var state := {}
    for id in ORDER:
        state[id] = 0
    return state

static func valid(professions: Variant) -> bool:
    if not professions is Dictionary or professions.size() != ORDER.size():
        return false
    for id in ORDER:
        var value: Variant = professions.get(id)
        if not (value is int or value is float) or value != floor(value) or value < 0 or value > max_xp():
            return false
    return true

static func level_of(progression: Dictionary, profession: String) -> int:
    return level_for(int(progression.get("professions", {}).get(profession, 0)))

static func has_milestone(level: int, milestone: int) -> bool:
    return level >= milestone

## Success chance of one attempt (soft gate, always shown): 70% at the required level, +2% per
## level above (max 98%), −4% per level below (min 5%); milestone and tool bonuses on top.
static func chance(level: int, required: int, bonus: float = 0.0) -> float:
    var diff := level - required
    var base: float = 0.70 + 0.02 * diff if diff >= 0 else 0.70 + 0.04 * diff
    if level >= 10:
        base += 0.05
    return clampf(base + bonus, 0.05, 0.98)

## Seconds per swing (or per step of work): faster with level (−0.6% per level), slower below
## the requirement (+6% per level short, at most double), tool tier −8% each.
static func work_seconds(base: float, level: int, required: int, tool_tier: int = 0) -> float:
    var factor := 1.0 - 0.006 * level - 0.08 * clampi(tool_tier, 0, 3)
    if level >= 50:
        factor -= 0.1
    factor *= minf(2.0, 1.0 + 0.06 * maxi(0, required - level))
    return base * maxf(0.35, factor)

## Chance that a success yields twice.
static func double_chance(level: int) -> float:
    return 0.004 * level + (0.1 if level >= 40 else 0.0)

## XP for one success at a required level (a failed try teaches a fifth of it).
static func xp_reward(required: int) -> int:
    return 6 + 4 * required

## --- Woods and ores. [name, required level, sell base price, colour, prop kinds, regions, weight]
## A tree or rock prop of a listed kind in a listed region can be that resource; rarer resources
## have lower weights. Regions are WorldMap.REGION_NAMES values.
const HOME := ["The First Clearing", "Verdant Isle", "Thornwood", "Mirror Lake", "Harrowmere"]
const WOODS := {
    "log_oak": ["Oak Log", 1, 5, Color("a0743f"), ["tree_round", "tree_big", "pine"], ["The First Clearing", "Verdant Isle", "Thornwood", "Mirror Lake", "Harrowmere"], 10],
    "log_birch": ["Birch Log", 5, 8, Color("e6dcc0"), ["tree_round", "tree_big"], ["Thornwood", "Mirror Lake", "Harrowmere"], 6],
    "log_pine": ["Pine Log", 10, 12, Color("7a5230"), ["pine", "pine_snow", "tree_snow"], ["Thornwood", "Frostpeak"], 6],
    "log_palm": ["Palm Log", 12, 14, Color("c8a060"), ["palm"], ["Sunscorch Desert", "The Ki Realm"], 10],
    "log_maple": ["Maple Log", 15, 20, Color("c2532d"), ["tree_autumn", "tree_big", "tree_round"], ["Ambervale"], 10],
    "log_bamboo": ["Bamboo Cane", 18, 18, Color("8fbf4a"), ["bamboo"], ["Sakura Vale", "Jade Terraces"], 10],
    "log_frostbark": ["Frostbark Log", 20, 30, Color("a8d4e8"), ["tree_snow", "tree_snow_big", "pine_snow"], ["Frostpeak"], 5],
    "log_cherry": ["Cherrywood Log", 25, 40, Color("e88aa8"), ["tree_pink", "tree_blossom"], ["Sakura Vale"], 10],
    "log_bogwood": ["Bogwood Log", 28, 50, Color("4f5a36"), ["tree_dead"], ["Mirewood Marsh"], 10],
    "log_ironwood": ["Ironwood Log", 30, 70, Color("5a5f66"), ["tree_big"], ["Thornwood", "Ambervale", "Harrowmere"], 1],
    "log_emberwood": ["Emberwood Log", 35, 90, Color("e0602a"), ["tree_dead"], ["Emberreach Isles", "Cinder Crater"], 10],
    # M7b: the Eastern Reaches.
    "log_acacia": ["Acacia Log", 23, 60, Color("c89a4a"), ["tree_acacia", "tree_steppe"], ["Goldwind Steppe"], 10],
    "log_gloomwood": ["Gloomwood Log", 30, 100, Color("6e4a8c"), ["tree_gloom", "tree_gloom_big", "tree_gloom_dead"], ["Gloomveil"], 10],
    "log_jadewood": ["Jadewood Log", 36, 130, Color("3fae7e"), ["tree_jade", "pine_jade"], ["Jade Terraces"], 10],
    "log_spiritwood": ["Spiritwood Log", 42, 150, Color("8fe8ff"), ["tree_round", "tree_big", "pine", "palm", "tree_dead", "pine_snow", "tree_snow"], ["The Ki Realm"], 10],
    "log_worldtree": ["World Tree Branch", 48, 260, Color("ffe27a"), ["tree_big", "tree_snow_big"], ["The Ki Realm"], 1],
}
const ORES := {
    "ore_copper": ["Copper Ore", 1, 6, Color("e0803a"), ["boulder"], ["The First Clearing", "Verdant Isle", "Thornwood", "Mirror Lake"], 10],
    "ore_tin": ["Tin Ore", 5, 8, Color("c8ccd0"), ["boulder"], ["Verdant Isle", "Thornwood", "Mirror Lake", "Harrowmere"], 7],
    "ore_iron": ["Iron Ore", 10, 14, Color("9a6a58"), ["boulder", "boulder_snow"], ["Harrowmere", "Sunscorch Desert", "Frostpeak", "Ambervale", "Goldwind Steppe"], 8],
    "ore_coal": ["Coal", 12, 12, Color("2a2a2e"), ["boulder"], ["Sunscorch Desert", "Cinder Crater", "Ambervale"], 8],
    "ore_silver": ["Silver Ore", 18, 26, Color("e8eef4"), ["boulder", "boulder_snow"], ["Frostpeak", "Ambervale", "Sakura Vale"], 6],
    "ore_gold": ["Gold Ore", 25, 45, Color("f0c840"), ["boulder"], ["Cinder Crater", "Sunscorch Desert", "Emberreach Isles", "Goldwind Steppe"], 8],
    "ore_mithril": ["Mithril Ore", 32, 80, Color("6fb8ff"), ["boulder", "boulder_snow"], ["Frostpeak", "Cinder Crater", "Emberreach Isles", "Gloomveil"], 5],
    "ore_shadowite": ["Shadowite Ore", 30, 90, Color("9a5ad0"), ["boulder"], ["Gloomveil"], 8],
    "ore_jade": ["Jade Ore", 37, 150, Color("4fd09a"), ["boulder"], ["Jade Terraces"], 8],
    "ore_adamantite": ["Adamantite Ore", 40, 130, Color("4fd08a"), ["boulder"], ["Emberreach Isles", "The Ki Realm", "Jade Terraces"], 6],
    "ore_starmetal": ["Starmetal Ore", 46, 220, Color("d8a0ff"), ["boulder", "boulder_snow"], ["The Ki Realm"], 4],
}
## Herbs gathered from bushes (Alchemy, picked by hand): [name, level, price, colour, props, regions, weight]
const HERBS := {
    "herb_mint": ["Meadow Mint", 1, 6, Color("7ed07e"), ["bush"], ["The First Clearing", "Verdant Isle", "Thornwood", "Mirror Lake", "Harrowmere"], 10],
    "herb_sunbloom": ["Sunbloom", 10, 14, Color("ffd04a"), ["bush"], ["Sunscorch Desert"], 10],
    "herb_ambercap": ["Ambercap", 14, 18, Color("e0803a"), ["bush"], ["Ambervale"], 10],
    "herb_sakura": ["Sakura Petal", 18, 24, Color("ff9ac0"), ["bush"], ["Sakura Vale"], 10],
    "herb_bogmoss": ["Bogmoss", 24, 30, Color("6a8a3a"), ["bush"], ["Mirewood Marsh"], 10],
    "herb_steppe_sage": ["Steppe Sage", 22, 40, Color("d8c070"), ["bush", "bush_dry"], ["Goldwind Steppe"], 10],
    "herb_nightshade": ["Nightshade", 30, 60, Color("8a4ad0"), ["bush", "bush_gloom"], ["Gloomveil"], 10],
    "herb_jade_lotus": ["Jade Lotus", 36, 90, Color("7ae0b0"), ["bush"], ["Jade Terraces"], 10],
    "herb_senzu": ["Senzu Sprout", 42, 120, Color("a8ff6a"), ["bush"], ["The Ki Realm"], 10],
    # M9b: no bush grows these; picking any herb at night (Moonbloom) or in a thunderstorm (Storm
    # Orchid) can turn one up.
    "herb_moonbloom": ["Moonbloom", 12, 45, Color("c8d8ff"), ["bush"], [], 0],
    "herb_storm_orchid": ["Storm Orchid", 25, 80, Color("a8a0ff"), ["bush"], [], 0],
    "herb_dragon_blossom": ["Dragon Blossom", 48, 200, Color("ff7a5a"), ["bush"], ["The Ki Realm"], 4],
}
const HERB_PROPS := ["bush", "bush_gloom", "bush_dry"]

## Gems a mining success can turn up (by the ore's level): [name, price, from ore level]
const GEMS := {
    "gem_sapphire": ["Sapphire", 120, 1],
    "gem_emerald": ["Emerald", 160, 12],
    "gem_ruby": ["Ruby", 220, 25],
    "gem_diamond": ["Diamond", 400, 32],
    "gem_ki_crystal": ["Ki Crystal", 700, 42],
}
const GEM_CHANCE := 0.012
## Woodcutting milestone 30: rare sap.
const SAP := {"amber_sap": ["Amber Sap", 150]}

const TREE_PROPS := ["pine", "tree_big", "tree_round", "tree_autumn", "tree_dead", "pine_snow", "tree_snow", "tree_snow_big", "tree_pink", "tree_blossom", "bamboo", "palm", "tree_gloom", "tree_gloom_dead", "tree_gloom_big", "tree_acacia", "tree_steppe", "tree_jade", "pine_jade"]
const ROCK_PROPS := ["boulder", "boulder_snow"]

## Swings per unit of a resource and the units a node holds.
const SWINGS_PER_UNIT := 3
const BASE_SWING := 0.55

static func is_resource(id: String) -> bool:
    return WOODS.has(id) or ORES.has(id) or GEMS.has(id) or SAP.has(id) or HERBS.has(id)

static func resource_info(id: String) -> Array:
    if WOODS.has(id):
        return [WOODS[id][0], "Logs", "Wood for smithing and crafting (Woodcutting %d). Merchants buy it." % WOODS[id][1]]
    if ORES.has(id):
        return [ORES[id][0], "Ores", "Ore to smelt into bars (Mining %d). Merchants buy it." % ORES[id][1]]
    if GEMS.has(id):
        return [GEMS[id][0], "Gems", "A rare gem found while mining. Merchants pay well for it."]
    if HERBS.has(id):
        return [HERBS[id][0], "Herbs", "A herb for alchemy (Alchemy %d), picked from bushes." % HERBS[id][1]]
    return [SAP[id][0], "Logs", "Rare sap found in old trees. Merchants pay well for it."]

static func resource_price(id: String) -> int:
    if WOODS.has(id):
        return WOODS[id][2]
    if ORES.has(id):
        return ORES[id][2]
    if GEMS.has(id):
        return GEMS[id][1]
    if SAP.has(id):
        return SAP[id][1]
    if HERBS.has(id):
        return HERBS[id][2]
    return 0

static func all_resources() -> Array:
    return WOODS.keys() + ORES.keys() + GEMS.keys() + SAP.keys() + HERBS.keys()

## Which resource a prop is (deterministic from its plan index): "" when none fits.
static func resource_for(prop: String, region: String, index: int) -> String:
    var table: Dictionary = WOODS if prop in TREE_PROPS else (ORES if prop in ROCK_PROPS else (HERBS if prop in HERB_PROPS else {}))
    var pool: Array = []
    var total := 0
    for id in table:
        if prop in table[id][4] and region in table[id][5]:
            pool.append(id)
            total += int(table[id][6])
    if pool.is_empty():
        # Any other region: the easiest wood or ore that grows on this kind of prop.
        if table.is_empty():
            return ""
        var best := ""
        for id in table:
            if prop in table[id][4] and (best.is_empty() or int(table[id][1]) < int(table[best][1])):
                best = id
        if best.is_empty():
            best = "log_oak" if table == WOODS else ("ore_copper" if table == ORES else "herb_mint")
        return best
    var roll: int = absi(hash(index * 7919 + 17)) % total
    for id in pool:
        roll -= int(table[id][6])
        if roll < 0:
            return id
    return pool[-1]

static func profession_for(resource: String) -> String:
    return "woodcutting" if WOODS.has(resource) else ("alchemy" if HERBS.has(resource) else "mining")

static func required_level(resource: String) -> int:
    for table in [WOODS, ORES, HERBS]:
        if table.has(resource):
            return int(table[resource][1])
    return 1

## Units a node holds when full (milestone 20/30 add one).
static func units_for(resource: String, index: int) -> int:
    if HERBS.has(resource):
        return 2 + absi(hash(index * 31 + 5)) % 2
    return (4 if WOODS.has(resource) else 3) + absi(hash(index * 31 + 5)) % 3

## Seconds a felled tree or broken rock takes to grow back.
static func regrow_seconds(resource: String) -> float:
    return (60.0 if HERBS.has(resource) else 90.0) + 6.0 * required_level(resource)

## Herbs for the Alchemy tab: [name, required level, where].
static func entries_for(profession: String) -> Array:
    var rows: Array = []
    if profession == "alchemy":
        for id in HERBS:
            rows.append(["Herb: " + HERBS[id][0], int(HERBS[id][1]), ", ".join(HERBS[id][5])])
    return rows

## A gem for an ore success, by ore level (rarer gems from better ores).
static func gem_for(ore_level: int, roll: int) -> String:
    var pool: Array = []
    for id in GEMS:
        if ore_level >= int(GEMS[id][2]):
            pool.append(id)
    return pool[roll % pool.size()] if not pool.is_empty() else "gem_sapphire"
