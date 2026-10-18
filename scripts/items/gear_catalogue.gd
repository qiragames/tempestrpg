extends RefCounted
## Gear foundation (step 17e): armor and accessories. Items are instances with a stable ID, a base
## type (slot, look, stat ranges), a rarity, rolled stats, passives (Rare and up) and one active
## (Epic and Legendary). Weapons follow in 17f, sources (drops, chests, crafting) in 17g.
## Starting numbers, tuned in step 24.
const SLOTS := ["weapon", "head", "body", "hands", "feet", "accessory_1", "accessory_2"]
## Item expansion (user request): a sixth rarity, Mythic, above Legendary.
const RARITIES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]
const RARITY_COLORS := ["9aa3a8", "6fcf7a", "5aa2ee", "b47cf0", "f0a34a", "ff4d6d"]
## Positive stat ranges grow with rarity; penalties (negative ranges) do not.
const RARITY_SCALE := [1.0, 1.25, 1.5, 1.8, 2.2, 2.7]
const PASSIVE_COUNT := [0, 0, 1, 1, 2, 3]
const STATS := ["damage", "hp", "magicules", "regen", "speed", "strike", "defense"]
const STAT_TEXT := {"damage": "%s weapon damage", "hp": "+%s max HP", "magicules": "+%s max Magicules", "regen": "+%s Magicules/s", "speed": "%s move speed", "strike": "+%s strike damage", "defense": "-%s damage taken per hit"}
## The first twelve bases (17e/17f); every saved item made before the item expansion uses them.
const CLASSIC := {
    "cloth_hood": {"slot": "head", "name": "Cloth Hood", "look": "hood", "stats": {"hp": [3, 6]}},
    "iron_helm": {"slot": "head", "name": "Iron Helm", "look": "helm", "stats": {"hp": [6, 10], "defense": [1, 2]}},
    "padded_vest": {"slot": "body", "name": "Padded Vest", "look": "vest", "stats": {"hp": [6, 12]}},
    "scale_mail": {"slot": "body", "name": "Scale Mail", "look": "mail", "stats": {"hp": [10, 16], "defense": [1, 3], "speed": [-6, -3]}},
    "leather_gloves": {"slot": "hands", "name": "Leather Gloves", "look": "gloves", "stats": {"strike": [1, 2]}},
    "travel_boots": {"slot": "feet", "name": "Travel Boots", "look": "boots", "stats": {"speed": [3, 6]}},
    "copper_ring": {"slot": "accessory", "name": "Copper Ring", "look": "ring", "stats": {"magicules": [5, 10]}},
    "spirit_amulet": {"slot": "accessory", "name": "Spirit Amulet", "look": "amulet", "stats": {"regen": [0.2, 0.5]}},
    # Weapons (17f): `damage` replaces the unarmed strike's 10; the type sets shape and timing.
    "iron_sword": {"slot": "weapon", "weapon": "sword", "name": "Iron Sword", "look": "sword", "stats": {"damage": [12, 15]}},
    "ash_spear": {"slot": "weapon", "weapon": "spear", "name": "Ash Spear", "look": "spear", "stats": {"damage": [13, 17]}},
    "field_scythe": {"slot": "weapon", "weapon": "scythe", "name": "Field Scythe", "look": "scythe", "stats": {"damage": [15, 20]}},
    "hunting_bow": {"slot": "weapon", "weapon": "bow", "name": "Hunting Bow", "look": "bow", "stats": {"damage": [9, 12]}},
}
## Every base: the classic twelve plus the generated catalogue (tools/generate_items.py, about
## 800 weapons and armour pieces with elements, levels and a minimum rarity).
const GENERATED := preload("res://scripts/items/item_bases.gd")
static var BASES: Dictionary = _all_bases()

static func _all_bases() -> Dictionary:
    var all: Dictionary = {}
    for id in CLASSIC:
        all[id] = CLASSIC[id].merged({"level": 1, "min_rarity": 0, "element": ""})
    all.merge(GENERATED.BASES)
    # M7b: stronger tiers of the level 16-20 bases for item levels 24-48.
    all.merge(preload("res://scripts/items/high_items.gd").BASES)
    # M7a: raid bosses' own uniques (only bosses drop them).
    all.merge(preload("res://scripts/bosses/boss_items.gd").BASES)
    return all

## The icon of an item (generated bases: a cell of their group's atlas; classic: per rarity).
static func icon_texture(base: String, rarity: int) -> Texture2D:
    if not BASES.has(base):
        return null
    var spec: Dictionary = BASES[base]
    if spec.get("look", "") == "icon":
        var texture := AtlasTexture.new()
        texture.atlas = load("res://assets/game/ui/items/%s.png" % spec.icon)
        var cell: int = int(spec.cell)
        texture.region = Rect2((cell % GENERATED.ATLAS_COLUMNS) * GENERATED.CELL, int(cell / GENERATED.ATLAS_COLUMNS) * GENERATED.CELL, GENERATED.CELL, GENERATED.CELL)
        # M11: the high tiers (21-48) wear their own palette and, at the top, a glow.
        if spec.has("tier"):
            return preload("res://scripts/items/tier_looks.gd").texture(base, String(spec.tier), texture)
        return texture
    var path := "res://assets/game/ui/icons/gear/%s_%d.png" % [base, clampi(rarity, 0, 4)]
    return load(path) if ResourceLoader.exists(path) else null

## Basic-attack behaviour per weapon type (unarmed: radius 16, 18 px ahead, 0.4 s).
##   sword  balanced arc          spear  long thrust hitting everything in a narrow line
##   scythe wide slow sweep       bow    ranged shot at the first creature in line of sight
const WEAPONS := {
    "dagger": {"name": "Dagger", "recovery": 0.3, "text": "quick short stab in front"},
    "sword": {"name": "Sword", "recovery": 0.45, "text": "balanced arc in front"},
    "spear": {"name": "Spear", "recovery": 0.55, "text": "long thrust through a line"},
    "scythe": {"name": "Scythe", "recovery": 0.75, "text": "wide sweep around the front"},
    "bow": {"name": "Bow", "recovery": 0.6, "text": "shot at the first creature up to 200 px"},
    # M12c: the Mage's and the Monk's weapons.
    "staff": {"name": "Staff", "recovery": 0.65, "text": "free magic bolt up to 170 px, grows with Intelligence"},
    "fist": {"name": "Fist weapon", "recovery": 0.22, "text": "very fast jabs; every third in a row hits harder"},
}
const PASSIVES := {
    "keen": "Skills deal 10% more damage",
    "swift": "+5 move speed",
    "wellspring": "+0.5 Magicules/s",
    "lifesteal": "Basic strikes heal 1 HP per creature hit",
    "thorns": "Creatures that hit you take 3 damage",
}
const ACTIVES := {
    "barrier": {"name": "Barrier", "cooldown": 30.0, "text": "2 s of invulnerability"},
    "surge": {"name": "Mana Surge", "cooldown": 45.0, "text": "Restore 30 Magicules"},
}
const MAX_ITEMS := 30

## Item stat values are whole numbers except regeneration (one decimal).
static func _round(stat: String, value: float) -> float:
    return snappedf(value, 0.1) if stat == "regen" else roundf(value)

## Allowed [low, high] for a stat on a base at a rarity.
static func stat_range(base: String, stat: String, rarity: int) -> Array:
    var span: Array = BASES[base].stats[stat]
    var scale: float = RARITY_SCALE[rarity] if span[0] >= 0 else 1.0
    return [_round(stat, span[0] * scale), _round(stat, span[1] * scale)]

static func slot_fits(base: String, slot: String) -> bool:
    var kind: String = BASES[base].slot
    return slot == kind or (kind == "accessory" and slot in ["accessory_1", "accessory_2"])

## Create an item (host side; used by gear sources in 17g, tests and the showcase).
static func roll(base: String, rarity: int, rng: RandomNumberGenerator) -> Dictionary:
    var stats := {}
    for stat in BASES[base].stats:
        var span: Array = stat_range(base, stat, rarity)
        stats[stat] = _round(stat, rng.randf_range(span[0], span[1]))
    var passives: Array = []
    var pool: Array = PASSIVES.keys()
    for index in range(PASSIVE_COUNT[rarity]):
        var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
        pool.erase(pick)
        passives.append(pick)
    var active: String = ACTIVES.keys()[rng.randi_range(0, ACTIVES.size() - 1)] if rarity >= 3 else ""
    return {"id": "item_" + Crypto.new().generate_random_bytes(8).hex_encode(), "base": base, "rarity": rarity, "stats": stats, "passives": passives, "active": active}

static func display_name(item: Dictionary) -> String:
    return "%s %s" % [RARITIES[item.rarity], BASES[item.base].name]

static func describe(item: Dictionary) -> String:
    var lines: Array = []
    for stat in item.stats:
        var value = item.stats[stat]
        lines.append(STAT_TEXT[stat] % (("+" if value > 0 else "") + str(value) if stat == "speed" else str(value)))
    for passive in item.passives:
        lines.append("Passive: " + PASSIVES[passive])
    if not item.active.is_empty():
        lines.append("Active (G): %s — %s, %d s cooldown" % [ACTIVES[item.active].name, ACTIVES[item.active].text, int(ACTIVES[item.active].cooldown)])
    return "\n".join(lines)

static func _whole_or_tenth(stat: String, value: Variant) -> bool:
    if not (value is int or value is float):
        return false
    return is_equal_approx(value, _round(stat, value))

## One saved item: known base and rarity, exactly the base's stats inside the rarity's range,
## the right number of distinct known passives, and an active only on Epic/Legendary.
static func valid_item(item: Variant) -> bool:
    # "runes" (M4.5d) is optional: socketed runes, at most the rarity's sockets.
    if not item is Dictionary or item.size() != (7 if item.has("runes") else 6) or not item.get("id") is String or not item.id.begins_with("item_") or item.id.length() > 64:
        return false
    if not BASES.has(item.get("base")) or not (item.get("rarity") is int or item.get("rarity") is float) or item.rarity != floor(item.rarity) or item.rarity < 0 or item.rarity >= RARITIES.size():
        return false
    var rarity: int = int(item.rarity)
    if rarity < int(BASES[item.base].get("min_rarity", 0)):
        return false
    if not item.get("stats") is Dictionary or item.stats.size() != BASES[item.base].stats.size():
        return false
    for stat in BASES[item.base].stats:
        var value: Variant = item.stats.get(stat)
        var span: Array = stat_range(item.base, stat, rarity)
        if not _whole_or_tenth(stat, value) or value < span[0] - 0.001 or value > span[1] + 0.001:
            return false
    if not item.get("passives") is Array or item.passives.size() != PASSIVE_COUNT[rarity]:
        return false
    var seen := {}
    for passive in item.passives:
        if not PASSIVES.has(passive) or seen.has(passive):
            return false
        seen[passive] = true
    if not item.get("active") is String:
        return false
    if item.has("runes"):
        var upgrades := preload("res://scripts/items/upgrade_catalogue.gd")
        if not item.runes is Array or item.runes.size() > upgrades.sockets(rarity) or item.runes.any(func(rune): return not rune is String or not upgrades.is_rune(rune)):
            return false
    return ACTIVES.has(item.active) if rarity >= 3 else item.active.is_empty()

## A character's gear: items (bag), equipment slots and active cooldowns.
static func valid_gear(gear: Variant, equipment: Variant) -> bool:
    if not gear is Dictionary or gear.size() != 2 or not gear.get("items") is Array or gear.items.size() > MAX_ITEMS or not gear.get("cooldowns") is Dictionary:
        return false
    var items := {}
    for item in gear.items:
        if not valid_item(item) or items.has(item.id):
            return false
        items[item.id] = item
    for id in gear.cooldowns:
        var remaining: Variant = gear.cooldowns[id]
        if not items.has(id) or items[id].active.is_empty() or not (remaining is int or remaining is float) or remaining < 0 or remaining > ACTIVES[items[id].active].cooldown:
            return false
    if not equipment is Dictionary:
        return false
    var worn := {}
    for slot in equipment:
        var id: Variant = equipment[slot]
        if not slot in SLOTS or not id is String or not items.has(id) or worn.has(id) or not slot_fits(items[id].base, slot):
            return false
        worn[id] = true
    return true
