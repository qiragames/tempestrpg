extends RefCounted
## Nation building (M5a, user decisions in docs/M4_PLAN.md M5): the camp grows into a village and
## a town, buildings are placed freely around the camp flag (on the tile grid, inside the
## settlement's radius), and the nation gets a name and a banner. Pure data and rules; FirstCamp
## keeps the state (`state.nation`) and applies it on the host.
const MAP := preload("res://scripts/world/world_map.gd")

## Tiers: [name, settlement radius (px from the camp flag), upgrade cost, required placed
## buildings, required kinds, required citizens (M5b)]. Tier 0 is the founded camp.
const TIERS := [
    ["Camp", 150.0, {}, 0, [], 0],
    ["Village", 230.0, {"wood": 30, "stone": 20}, 4, ["house", "house", "well"], 0],
    ["Town", 320.0, {"wood": 60, "stone": 50, "essence": 5}, 10, ["town_hall", "watchtower"], 6],
]

## Buildings: kind → [name, art (WorldTerrain prop, "" = drawn), collision size, cost, tier,
## unique, description].
const BUILDINGS := {
    "house": ["House", "house_wood", Vector2(40, 20), {"wood": 10, "stone": 4}, 0, false, "A home for citizens (housing grows with M5b)."],
    "well": ["Well", "well", Vector2(24, 12), {"wood": 2, "stone": 8}, 0, false, "Fresh water for the settlement."],
    "banner": ["Banner", "", Vector2(6, 6), {"wood": 4}, 0, false, "Flies your nation's banner."],
    "hut": ["Straw Hut", "hut_straw", Vector2(40, 18), {"wood": 8}, 0, false, "A simple home."],
    "big_house": ["Large House", "house_b", Vector2(56, 20), {"wood": 18, "stone": 10}, 1, false, "A large home for a family of citizens."],
    "watchtower": ["Watchtower", "tower", Vector2(26, 18), {"wood": 10, "stone": 20}, 1, false, "Looks out over the land (guards in M5c)."],
    "town_hall": ["Town Hall", "hall", Vector2(56, 24), {"wood": 40, "stone": 30, "essence": 2}, 1, true, "The seat of your nation; needed to become a town."],
    "lodge": ["Lodge", "lodge", Vector2(56, 22), {"wood": 30, "stone": 16}, 2, false, "A great timber hall (homes for six)."],
    "field": ["Field", "", Vector2(32, 32), {"wood": 4}, 0, false, "Farmland: plant and harvest crops for food (F)."],
}
## Buildings you can walk over (no collision).
const WALKABLE := ["field"]

## --- M5b: citizens, housing and food
## Homes per building kind (the camp's own Goblin Hut also houses CAMP_HUT_HOMES).
const HOUSING := {"hut": 1, "house": 2, "town_hall": 2, "big_house": 4, "lodge": 6}
const CAMP_HUT_HOMES := 2
const CAMP_HUT := "camp_hut"
## A newcomer arrives every ARRIVAL_SECONDS while a home is free and the store holds a day's food
## for everyone including them; each citizen eats FOOD_PER_DAY every DAY_SECONDS; after
## HUNGRY_DAYS days without enough food, one citizen leaves (and another every hungry day after).
const ARRIVAL_SECONDS := 90.0
const DAY_SECONDS := 300.0
const FOOD_PER_DAY := 1
const HUNGRY_DAYS := 2
const MAX_CITIZENS := 120
const MAX_FOOD := 100000
## Crops: id -> [name, growing seconds, food at harvest, colour of the ripe crop].
const CROPS := {
    "wheat": ["Wheat", 120.0, 4, Color("e8c45a")],
    "carrot": ["Carrots", 240.0, 9, Color("ef8a2c")],
    "pumpkin": ["Pumpkins", 480.0, 20, Color("e3762b")],
}
const FIELD_REACH := 30.0
const NAMES := ["Rigur", "Gobta", "Ranga", "Kaijin", "Rigurd", "Haruna", "Goblo", "Mira", "Tobi", "Noko", "Pell", "Wren", "Bram", "Sela", "Doro", "Kit", "Moss", "Fenn", "Lira", "Tamm", "Ivo", "Runa", "Ostra", "Pim"]
const LOOKS := 6
const RESOURCES := ["wood", "stone", "essence"]
const MAX_BUILDINGS := 60
const NAME_LENGTH := 24
## Banner colours and emblems.
const COLORS := [Color("c0392b"), Color("2e86de"), Color("27ae60"), Color("f1c40f"), Color("8e44ad"), Color("e67e22"), Color("ecf0f1"), Color("2c3e50")]
const EMBLEMS := ["Star", "Moon", "Fang", "Flame", "Leaf", "Crown"]
## Gaps kept around placed buildings and from deposits.
const GAP := 4.0
const DEPOSIT_CLEARANCE := 20.0

static func initial_state() -> Dictionary:
    return {"name": "", "color": 0, "emblem": 0, "tier": 0, "buildings": [], "next": 1, "spent": {"wood": 0, "stone": 0, "essence": 0},
        "citizens": [], "next_citizen": 1, "fields": {}, "food": 0, "grown": 0, "eaten": 0, "day": 0.0, "arrival": 0.0, "hunger": 0}

## Homes per building ID (and the camp hut's), for the camp state `camp`.
static func homes(nation: Dictionary, camp: Dictionary) -> Dictionary:
    var result := {}
    if camp.get("hut", false):
        result[CAMP_HUT] = CAMP_HUT_HOMES
    for entry in nation.buildings:
        if HOUSING.has(entry.kind):
            result[entry.id] = HOUSING[entry.kind]
    return result

static func housing(nation: Dictionary, camp: Dictionary) -> int:
    var total := 0
    for value in homes(nation, camp).values():
        total += int(value)
    return total

## A home with room ("" if every home is full).
static func free_home(nation: Dictionary, camp: Dictionary) -> String:
    var used := {}
    for citizen in nation.citizens:
        used[citizen.home] = int(used.get(citizen.home, 0)) + 1
    var available := homes(nation, camp)
    for home in available:
        if int(used.get(home, 0)) < int(available[home]):
            return home
    return ""

static func building(nation: Dictionary, id: String) -> Dictionary:
    for entry in nation.buildings:
        if entry.id == id:
            return entry
    return {}

static func tier_name(tier: int) -> String:
    return TIERS[clampi(tier, 0, TIERS.size() - 1)][0]

static func radius(tier: int) -> float:
    return TIERS[clampi(tier, 0, TIERS.size() - 1)][1]

## The foot (bottom centre) of a building on a tile.
static func foot(tile: Vector2i) -> Vector2:
    return MAP.to_world(Vector2(tile)) + Vector2(MAP.TILE / 2.0, MAP.TILE)

## The ground a building takes (its collision box, standing on the foot).
static func footprint(kind: String, tile: Vector2i) -> Rect2:
    var size: Vector2 = BUILDINGS[kind][2]
    return Rect2(foot(tile) - Vector2(size.x / 2.0, size.y), size)

static func cost_text(cost: Dictionary) -> String:
    var parts: Array = []
    for resource in RESOURCES:
        if cost.has(resource):
            parts.append("%d %s" % [cost[resource], resource])
    return " + ".join(parts) if not parts.is_empty() else "free"

static func count(nation: Dictionary, kind: String) -> int:
    return nation.buildings.filter(func(entry): return entry.kind == kind).size()

## What still stands between a nation and its next tier ("" when it may rank up).
static func tier_problem(nation: Dictionary, camp: Dictionary) -> String:
    var next: int = int(nation.tier) + 1
    if next >= TIERS.size():
        return "Your settlement is already a town."
    if next == 1 and not (camp.get("hut", false) and camp.get("storehouse", false)):
        return "A village needs the Goblin Hut and the Storehouse."
    if nation.buildings.size() < int(TIERS[next][3]):
        return "A %s needs %d placed buildings (%d now)." % [TIERS[next][0].to_lower(), TIERS[next][3], nation.buildings.size()]
    var wanted := {}
    for kind in TIERS[next][4]:
        wanted[kind] = int(wanted.get(kind, 0)) + 1
    for kind in wanted:
        if count(nation, kind) < wanted[kind]:
            return "A %s needs %s%s." % [TIERS[next][0].to_lower(), "%d× " % wanted[kind] if wanted[kind] > 1 else "a ", BUILDINGS[kind][0]]
    if nation.citizens.size() < int(TIERS[next][5]):
        return "A %s needs %d citizens (%d now)." % [TIERS[next][0].to_lower(), TIERS[next][5], nation.citizens.size()]
    for resource in TIERS[next][2]:
        if int(camp.get(resource, 0)) < int(TIERS[next][2][resource]):
            return "Ranking up costs %s." % cost_text(TIERS[next][2])
    return ""

static func _whole(value: Variant, high: float = 1000000) -> bool:
    return (value is float or value is int) and value >= 0 and value <= high and value == floor(value)

## Saved nation state: name, banner, tier, buildings on distinct tiles of known kinds that the
## tier allows, and the total spent (at least what stands plus the tiers reached).
static func valid(nation: Variant, founded: bool, camp: Dictionary = {}) -> bool:
    if not nation is Dictionary or nation.size() != 16 or not nation.get("name") is String or nation.name.length() > NAME_LENGTH:
        return false
    if not _whole(nation.get("color"), COLORS.size() - 1) or not _whole(nation.get("emblem"), EMBLEMS.size() - 1) or not _whole(nation.get("tier"), TIERS.size() - 1):
        return false
    if not _whole(nation.get("next"), 1000000) or not nation.get("buildings") is Array or nation.buildings.size() > MAX_BUILDINGS:
        return false
    var spent: Variant = nation.get("spent")
    if not spent is Dictionary or spent.size() != RESOURCES.size():
        return false
    for resource in RESOURCES:
        if not _whole(spent.get(resource)):
            return false
    if not founded and (nation.tier != 0 or not nation.buildings.is_empty() or not nation.name.is_empty() or RESOURCES.any(func(resource): return spent[resource] != 0)):
        return false
    var needed := {"wood": 0, "stone": 0, "essence": 0}
    for tier in range(1, int(nation.tier) + 1):
        for resource in TIERS[tier][2]:
            needed[resource] += int(TIERS[tier][2][resource])
    var ids := {}
    var tiles := {}
    for entry in nation.buildings:
        if not entry is Dictionary or entry.size() != 3 or not entry.get("id") is String or not entry.get("kind") is String or not BUILDINGS.has(entry.kind):
            return false
        if not entry.id.begins_with("b_") or not entry.id.trim_prefix("b_").is_valid_int() or int(entry.id.trim_prefix("b_")) >= int(nation.next) or ids.has(entry.id):
            return false
        var tile: Variant = entry.get("tile")
        if not tile is Array or tile.size() != 2 or not tile.all(func(value): return (value is int or value is float) and value == floor(value) and absf(value) < 2000) or tiles.has(str(tile)):
            return false
        if int(BUILDINGS[entry.kind][4]) > int(nation.tier) or (BUILDINGS[entry.kind][5] and count(nation, entry.kind) > 1):
            return false
        ids[entry.id] = true
        tiles[str(tile)] = true
        for resource in BUILDINGS[entry.kind][3]:
            needed[resource] += int(BUILDINGS[entry.kind][3][resource])
    for resource in RESOURCES:
        if int(spent[resource]) < int(needed[resource]):
            return false
    return valid_people(nation, founded, camp)

## M5b: citizens in homes that exist (never more than a home holds), crops on fields, food books
## (stored = grown - eaten), timers in range.
static func valid_people(nation: Dictionary, founded: bool, camp: Dictionary) -> bool:
    if not _whole(nation.get("food"), MAX_FOOD) or not _whole(nation.get("grown"), 100000000) or not _whole(nation.get("eaten"), 100000000) or int(nation.food) != int(nation.grown) - int(nation.eaten):
        return false
    for key in ["day", "arrival"]:
        var value: Variant = nation.get(key)
        if not (value is float or value is int) or value < 0 or value > (DAY_SECONDS if key == "day" else ARRIVAL_SECONDS):
            return false
    if not _whole(nation.get("hunger"), HUNGRY_DAYS) or not _whole(nation.get("next_citizen"), 1000000):
        return false
    var citizens: Variant = nation.get("citizens")
    if not citizens is Array or citizens.size() > MAX_CITIZENS or (not founded and not citizens.is_empty()):
        return false
    var available := homes(nation, camp)
    var used := {}
    var ids := {}
    for citizen in citizens:
        if not citizen is Dictionary or citizen.size() != 4 or not citizen.get("id") is String or not citizen.get("name") is String or citizen.name.length() > NAME_LENGTH or not citizen.get("home") is String or not _whole(citizen.get("look"), LOOKS - 1):
            return false
        if not citizen.id.begins_with("c_") or not citizen.id.trim_prefix("c_").is_valid_int() or int(citizen.id.trim_prefix("c_")) >= int(nation.next_citizen) or ids.has(citizen.id):
            return false
        ids[citizen.id] = true
        used[citizen.home] = int(used.get(citizen.home, 0)) + 1
        if not available.has(citizen.home) or used[citizen.home] > int(available[citizen.home]):
            return false
    var fields: Variant = nation.get("fields")
    if not fields is Dictionary or fields.size() > MAX_BUILDINGS:
        return false
    for id in fields:
        var plot: Variant = fields[id]
        if building(nation, String(id)).get("kind", "") != "field" or not plot is Dictionary or plot.size() != 2 or not plot.get("crop") is String or not CROPS.has(plot.crop):
            return false
        if not (plot.get("age") is float or plot.get("age") is int) or plot.age < 0 or plot.age > CROPS[plot.crop][1]:
            return false
    return true
