extends RefCounted
## Nation building (M5a, user decisions in docs/M4_PLAN.md M5): the camp grows into a village and
## a town, buildings are placed freely around the camp flag (on the tile grid, inside the
## settlement's radius), and the nation gets a name and a banner. Pure data and rules; FirstCamp
## keeps the state (`state.nation`) and applies it on the host.
const MAP := preload("res://scripts/world/world_map.gd")

## Tiers: [name, settlement radius (px from the camp flag), upgrade cost, required placed
## buildings, required kinds]. Tier 0 is the founded camp.
const TIERS := [
    ["Camp", 150.0, {}, 0, []],
    ["Village", 230.0, {"wood": 30, "stone": 20}, 4, ["house", "house", "well"]],
    ["Town", 320.0, {"wood": 60, "stone": 50, "essence": 5}, 10, ["town_hall", "watchtower"]],
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
    "lodge": ["Lodge", "lodge", Vector2(56, 22), {"wood": 30, "stone": 16}, 2, false, "A great timber hall."],
}
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
    return {"name": "", "color": 0, "emblem": 0, "tier": 0, "buildings": [], "next": 1, "spent": {"wood": 0, "stone": 0, "essence": 0}}

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
    for resource in TIERS[next][2]:
        if int(camp.get(resource, 0)) < int(TIERS[next][2][resource]):
            return "Ranking up costs %s." % cost_text(TIERS[next][2])
    return ""

static func _whole(value: Variant, high: float = 1000000) -> bool:
    return (value is float or value is int) and value >= 0 and value <= high and value == floor(value)

## Saved nation state: name, banner, tier, buildings on distinct tiles of known kinds that the
## tier allows, and the total spent (at least what stands plus the tiers reached).
static func valid(nation: Variant, founded: bool) -> bool:
    if not nation is Dictionary or nation.size() != 7 or not nation.get("name") is String or nation.name.length() > NAME_LENGTH:
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
    return true
