extends RefCounted
## Zeni, goods, merchants and ferries (M4.5c, user decisions in docs/M4_PLAN.md). Pure data and
## rules; WorldTrade applies them on the host.
##
## Zeni (per character): creature defeats (split by damage share among the qualifying
## characters), chests and selling. A defeat drops DEATH_SHARE of it into the pile. Selling gives
## SELL_SHARE of the buy price. Merchants restock every RESTOCK_SECONDS of world time.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const SOURCES := preload("res://scripts/items/gear_sources.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const TRAVEL := preload("res://scripts/travel/travel_catalogue.gd")
const UPGRADES := preload("res://scripts/items/upgrade_catalogue.gd")
const REALM := preload("res://scripts/realm/realm_catalogue.gd")

const DEATH_SHARE := 0.1
const SELL_SHARE := 0.3
const RESTOCK_SECONDS := 900.0
const MAX_ZENI := 10000000
const REACH := 36.0
const CONSUMABLE_COOLDOWN := 20.0
const CONSUMABLE_SECONDS := 5.0

## Zeni a defeated creature yields (split by damage share): grows with level and tier.
static func zeni_for(level: int, tier: int) -> int:
    return int(round((3.0 + 1.2 * level) * [1.0, 1.6, 3.0][clampi(tier, 0, 2)]))

## Zeni in a chest (plus its item); rich chests hold more.
static func chest_zeni(rich: bool, rng: RandomNumberGenerator) -> int:
    return rng.randi_range(60, 120) if rich else rng.randi_range(20, 45)

## Gear price by rarity, raised by the merchant's region level.
const RARITY_PRICE := [30, 80, 200, 500, 1200, 3500]

static func gear_price(item: Dictionary, level: int = 1) -> int:
    return int(round(RARITY_PRICE[clampi(int(item.get("rarity", 0)), 0, RARITY_PRICE.size() - 1)] * (1.0 + 0.04 * maxi(0, level - 1))))

## Material values (what a merchant asks; selling gives SELL_SHARE).
const MATERIAL_PRICE := {
    "gnasher_essence": 8, "thornback_quill": 10,
    "frost_pelt": 18, "wisp_mote": 16, "viper_scale": 16, "scuttler_shell": 18,
    "owl_feather": 20, "mole_claw": 22, "kappa_shell": 26, "mirecap_spore": 24,
    "bamboo_fiber": 24, "lantern_paper": 24, "ember_core": 30, "salamander_scale": 32,
}

## Goods that are not creature materials: consumables and skill scrolls. They live in the bag
## next to materials. [name, category, price, description]
const CONSUMABLES := {
    "healing_draught": ["Healing Draught", "Consumables", 25, "Restores 40 HP over 5 s (Q). Shares a 20 s cooldown with tonics."],
    "magicule_tonic": ["Magicule Tonic", "Consumables", 25, "Restores 40 Magicules over 5 s (Z). Shares a 20 s cooldown with draughts."],
}
## Scrolls teaching skills that can also be learned by analysis (Common).
const COMMON_SCROLLS := ["rending_bite", "thorn_lash", "frost_maul", "chill_touch", "venom_fang", "sand_burst", "mire_grasp", "spore_cloud", "bamboo_thrust", "lantern_flare", "gale_wing", "burrow_strike", "ember_burst", "magma_bite"]
## Much rarer scrolls teaching skills that exist nowhere else (user decision).
const RARE_SCROLLS := ["tempest_edge", "glacial_nova", "meteor_fall", "phantom_step"]
const COMMON_SCROLL_PRICE := 320
const RARE_SCROLL_PRICE := 4800

static func scroll_id(skill: String) -> String:
    return "scroll_" + skill

static func scroll_skill(id: String) -> String:
    return id.trim_prefix("scroll_") if id.begins_with("scroll_") else ""

static func is_rare_scroll(id: String) -> bool:
    return scroll_skill(id) in RARE_SCROLLS

## Every good id: consumables, scrolls and (M4.5d) ferry tickets, fish, runes and augments.
static func goods() -> Array:
    var all: Array = CONSUMABLES.keys()
    for skill in COMMON_SCROLLS + RARE_SCROLLS:
        all.append(scroll_id(skill))
    for harbour in MAP.HARBOURS:
        all.append(TRAVEL.ticket_id(harbour[0]))
    all.append_array(TRAVEL.FISH.keys())
    all.append_array(UPGRADES.RUNES.keys())
    all.append_array(UPGRADES.AUGMENTS.keys())
    return all

## Anything a bag may hold: creature materials, consumables and scrolls.
static func bag_item(id: String) -> bool:
    return preload("res://scripts/skills/skill_catalogue.gd").MATERIALS.has(id) or is_good(id)

static func is_good(id: String) -> bool:
    return CONSUMABLES.has(id) or scroll_skill(id) in COMMON_SCROLLS + RARE_SCROLLS or not TRAVEL.ticket_harbour(id).is_empty() or TRAVEL.is_fish(id) or UPGRADES.is_rune(id) or UPGRADES.is_augment(id) or REALM.is_orb(id)

## [name, category, description] of a good.
static func good_info(id: String) -> Array:
    if CONSUMABLES.has(id):
        return [CONSUMABLES[id][0], CONSUMABLES[id][1], CONSUMABLES[id][3]]
    if not TRAVEL.ticket_harbour(id).is_empty():
        var harbour: Array = MAP.harbour(TRAVEL.ticket_harbour(id))
        return ["Ferry ticket: %s" % harbour[1], "Tickets", "One trip to %s with the ferry, from any harbour. Hand it in at the harbour (F)." % harbour[1]]
    if TRAVEL.is_fish(id):
        return [TRAVEL.FISH[id][0], "Fish", "Caught with a fishing rod. Merchants buy fish."]
    if UPGRADES.is_rune(id):
        return [UPGRADES.RUNES[id][0], "Runes", UPGRADES.describe(id)]
    if UPGRADES.is_augment(id):
        return [UPGRADES.AUGMENTS[id][0], "Augments", UPGRADES.describe(id)]
    if REALM.is_orb(id):
        var stars := int(id.trim_prefix("wish_orb_"))
        return ["Wish Orb (%d star%s)" % [stars, "" if stars == 1 else "s"], "Wish Orbs", "One of the seven wish orbs of the Ki Realm. Bring all seven to the Guardian's altar."]
    var skill := scroll_skill(id)
    var data: Resource = load(preload("res://scripts/skills/skill_catalogue.gd").SKILLS[skill])
    return ["Scroll: %s" % data.display_name, "Scrolls", ("A very rare scroll teaching %s, a skill found nowhere else. Read it from the bag." if skill in RARE_SCROLLS else "Teaches %s without analysis. Read it from the bag.") % data.display_name]

## Buy price of a bag good or material ("" for unknown).
static func price(id: String) -> int:
    if MATERIAL_PRICE.has(id):
        return MATERIAL_PRICE[id]
    if CONSUMABLES.has(id):
        return CONSUMABLES[id][2]
    if TRAVEL.is_fish(id):
        return TRAVEL.FISH[id][1]
    if UPGRADES.is_rune(id):
        return UPGRADES.RUNES[id][3]
    if UPGRADES.is_augment(id):
        return UPGRADES.AUGMENTS[id][3]
    var skill := scroll_skill(id)
    if skill in RARE_SCROLLS:
        return RARE_SCROLL_PRICE
    if skill in COMMON_SCROLLS:
        return COMMON_SCROLL_PRICE
    return 0

static func sell_price(buy: int) -> int:
    return maxi(1, int(floor(buy * SELL_SHARE)))

## Merchants: [id, display name, npc sprite, kind, town id ("" = camp/traveller), level].
## Kinds: "town" (gear, materials, consumables, scrolls), "trader" (camp: materials,
## consumables, scrolls), "smith" (camp: gear), "traveller" (better gear and scrolls).
const MERCHANTS := [
    ["merchant_brookhaven", "Brookhaven Trader", "merchant_verdant", "town", "brookhaven", 4],
    ["merchant_harrowmere", "Harrowmere Outfitter", "merchant_harrow", "town", "harrowmere", 6],
    ["merchant_rimeholm", "Rimeholm Furrier", "merchant_frost", "town", "rimeholm", 11],
    ["merchant_dunemarch", "Dunemarch Bazaar", "merchant_desert", "town", "dunemarch", 10],
    ["merchant_amberhold", "Amberhold Market", "merchant_amber", "town", "amberhold", 13],
    ["merchant_bogsend", "Bogsend Peddler", "merchant_marsh", "town", "bogsend", 16],
    ["merchant_hanamura", "Hanamura Emporium", "merchant_sakura", "town", "hanamura", 15],
    ["merchant_cinderport", "Cinderport Exchange", "merchant_ember", "town", "cinderport", 18],
    ["camp_trader", "Camp Trader", "camp_trader", "trader", "", 4],
    ["camp_smith", "Camp Smith", "camp_smith", "smith", "", 6],
    ["traveller", "Travelling Merchant", "traveller", "traveller", "", 16],
]
## Stables (M4.5d): merchant → mounts it sells.
const STABLES := {"merchant_brookhaven": ["donkey", "horse"], "merchant_amberhold": ["horse", "black_horse"], "merchant_dunemarch": ["donkey", "horse"]}
## Where the town merchant stands, from the plaza centre (tiles).
const STALL_OFFSET := Vector2(3, 1.5)

static func merchant(id: String) -> Array:
    for entry in MERCHANTS:
        if entry[0] == id:
            return entry
    return []

## Where a town merchant stands (world position); camp staff and the traveller are placed by
## WorldTrade.
static func town_merchant_position(entry: Array) -> Vector2:
    var town: Array = MAP.town(entry[4])
    return MAP.to_world(Vector2(town[3]) + STALL_OFFSET)

## Rarity odds by merchant kind and level: [Common, Uncommon, Rare, Epic, Legendary, Mythic].
static func rarity_weights(kind: String, level: int) -> Array:
    if kind == "traveller":
        return [0, 0, 20, 54, 24, 2]
    if level >= 15:
        return [5, 30, 40, 20, 5, 0]
    if level >= 10:
        return [15, 40, 33, 11, 1, 0]
    return [45, 38, 15, 2, 0, 0]

## A fresh stock for one restock cycle: entries {"kind": "gear"|"good"|"material", "id",
## "item" (gear only), "price", "count"}.
static func roll_stock(entry: Array, rng: RandomNumberGenerator) -> Array:
    var kind: String = entry[3]
    var level: int = entry[5]
    var stock: Array = []
    var gear_count: int = {"town": 4, "trader": 0, "smith": 6, "traveller": 4}[kind]
    for _i in range(gear_count):
        var rarity: int = SOURCES._weighted(rng, rarity_weights(kind, level))
        var item: Dictionary = GEAR.roll(SOURCES._base(rng, [], rarity, level + (4 if kind == "traveller" else 0)), rarity, rng)
        stock.append({"kind": "gear", "id": item.id, "item": item, "price": gear_price(item, level), "count": 1})
    # Tools (M4.5d): every town sells the tiers its level allows (fixed, not random).
    if kind == "town":
        var top: int = 1 if level < 10 else (2 if level < 15 else 3)
        for tool in TRAVEL.TOOLS:
            for tier in range(1, top + 1):
                stock.append({"kind": "tool", "id": TRAVEL.tool_item(tool, tier), "price": TRAVEL.tool_price(tool, tier), "count": 99})
    # Mounts at the stables of Brookhaven, Amberhold and Dunemarch.
    for mount in STABLES.get(entry[0], []):
        stock.append({"kind": "mount", "id": TRAVEL.mount_item(mount), "price": TRAVEL.MOUNTS[mount][2], "count": 99})
    # Runes and augments: now and then in towns, more often from the traveller.
    var rune_chance: float = {"town": 0.12, "trader": 0.0, "smith": 0.25, "traveller": 1.0}[kind]
    for _i in range(2 if kind == "traveller" else 1):
        if rng.randf() < rune_chance:
            var rune: String = UPGRADES.RUNES.keys()[rng.randi_range(0, UPGRADES.RUNES.size() - 1)]
            if not stock.any(func(existing): return existing.id == rune):
                stock.append({"kind": "good", "id": rune, "price": price(rune), "count": 1})
    var augment_chance: float = {"town": 0.3 if level >= 10 else 0.0, "trader": 0.0, "smith": 0.0, "traveller": 0.8}[kind]
    if rng.randf() < augment_chance:
        var augment: String = UPGRADES.AUGMENTS.keys()[rng.randi_range(0, UPGRADES.AUGMENTS.size() - 1)]
        stock.append({"kind": "good", "id": augment, "price": price(augment), "count": 1})
    if kind in ["town", "trader", "traveller"]:
        for id in CONSUMABLES:
            stock.append({"kind": "good", "id": id, "price": price(id), "count": rng.randi_range(3, 6)})
    if kind in ["town", "trader"]:
        var materials: Array = MATERIAL_PRICE.keys()
        for _i in range(2):
            var id: String = materials[rng.randi_range(0, materials.size() - 1)]
            if not stock.any(func(existing): return existing.id == id):
                stock.append({"kind": "material", "id": id, "price": price(id), "count": rng.randi_range(2, 5)})
    # Scrolls: common ones now and then; rare ones from the traveller, and very, very rarely in
    # a big town.
    var common_chance: float = {"town": 0.4, "trader": 0.3, "smith": 0.0, "traveller": 1.0}[kind]
    var rare_chance: float = {"town": 0.02, "trader": 0.0, "smith": 0.0, "traveller": 0.35}[kind]
    if rng.randf() < common_chance:
        var id := scroll_id(COMMON_SCROLLS[rng.randi_range(0, COMMON_SCROLLS.size() - 1)])
        stock.append({"kind": "good", "id": id, "price": price(id), "count": 1})
    if rng.randf() < rare_chance:
        var id := scroll_id(RARE_SCROLLS[rng.randi_range(0, RARE_SCROLLS.size() - 1)])
        stock.append({"kind": "good", "id": id, "price": price(id), "count": 1})
    return stock

static func valid_stock(stock: Variant) -> bool:
    if not stock is Array or stock.size() > 40:
        return false
    var ids := {}
    for entry in stock:
        if not entry is Dictionary or not entry.get("kind") in ["gear", "good", "material", "tool", "mount"] or not entry.get("id") is String or ids.has(entry.id):
            return false
        ids[entry.id] = true
        if not _whole(entry.get("price"), 1, 100000) or not _whole(entry.get("count"), 0, 99):
            return false
        match entry.kind:
            "gear":
                if entry.size() != 5 or not GEAR.valid_item(entry.get("item")) or entry.item.id != entry.id:
                    return false
            "good":
                if entry.size() != 4 or not is_good(entry.id):
                    return false
            "material":
                if entry.size() != 4 or not MATERIAL_PRICE.has(entry.id):
                    return false
            "tool":
                if entry.size() != 4 or TRAVEL.parse_tool(entry.id)[0] == "":
                    return false
            "mount":
                if entry.size() != 4 or not TRAVEL.MOUNTS.has(entry.id.trim_prefix("mount_")):
                    return false
    return true

static func _whole(value: Variant, low: float, high: float) -> bool:
    return (value is int or value is float) and value == floor(value) and value >= low and value <= high

## Roadside spots the travelling merchant may appear at (tiles), across the whole world.
const TRAVELLER_SPOTS := [
    Vector2(160, 70), Vector2(150, -40), Vector2(-20, 110), Vector2(-190, 230), Vector2(260, -100),
    Vector2(30, 320), Vector2(260, 330), Vector2(-120, 420), Vector2(520, 60), Vector2(530, 300),
    Vector2(-60, -10), Vector2(306, 110),
]
const TRAVELLER_STAY := 600.0
const TRAVELLER_GAP := [2400.0, 4800.0]
