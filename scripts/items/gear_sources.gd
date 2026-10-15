extends RefCounted
## Gear sources (step 17g): creature drops, seeded chests, the trial reward and camp forge recipes.
## All rolls happen on the host. Merchants follow with currency in M4.5/M5.
## Starting numbers, tuned in step 24.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")

## Chance a defeated creature drops gear, by tier [Easy, Standard, Elite].
const DROP_CHANCE := [0.1, 0.2, 0.45]
## Rarity weights [Common, Uncommon, Rare, Epic, Legendary, Mythic].
const DROP_RARITY := [[70, 25, 5, 0, 0, 0], [50, 32, 14, 4, 0, 0], [200, 350, 280, 130, 37, 3]]
const CHEST_RARITY := [0, 500, 350, 128, 20, 2]
const TRIAL_RARITY := [0, 0, 70, 30, 0, 0]
const FORGE_RARITY := [60, 30, 10, 0, 0, 0]
const CHEST_REACH := 30.0
const MAX_LOOT := 64
## Forge recipes: absorbed materials from the bag → a random item of a kind.
const RECIPES := {
    "armor": {"name": "Armor", "materials": {"gnasher_essence": 2}, "slots": ["head", "body", "hands", "feet"]},
    "weapon": {"name": "Weapon", "materials": {"thornback_quill": 2}, "slots": ["weapon"]},
    "accessory": {"name": "Accessory", "materials": {"gnasher_essence": 1, "thornback_quill": 1}, "slots": ["accessory"]},
}

static func _weighted(rng: RandomNumberGenerator, weights: Array) -> int:
    var total := 0
    for weight in weights:
        total += weight
    var roll := rng.randi_range(1, total)
    for index in range(weights.size()):
        roll -= weights[index]
        if roll <= 0:
            return index
    return 0

## A base that fits: the slots asked for, a minimum rarity at or below the roll and an item level
## near the source's level (up to LEVEL_REACH above; nothing far below once there is better).
const LEVEL_REACH := 2
const LEVEL_FLOOR := 8

static func _base(rng: RandomNumberGenerator, slots: Array = [], rarity: int = 0, level: int = 1) -> String:
    var fits := func(id: String, low: int) -> bool:
        var spec: Dictionary = GEAR.BASES[id]
        return not spec.get("boss", false) and (slots.is_empty() or spec.slot in slots) and int(spec.get("min_rarity", 0)) <= rarity and int(spec.get("level", 1)) <= level + LEVEL_REACH and int(spec.get("level", 1)) >= low
    var pool: Array = GEAR.BASES.keys().filter(fits.bind(level - LEVEL_FLOOR))
    if pool.is_empty():
        pool = GEAR.BASES.keys().filter(fits.bind(0))
    return pool[rng.randi_range(0, pool.size() - 1)]

## A rolled item at a rarity from a base fitting that rarity and level.
static func _item(rng: RandomNumberGenerator, weights: Array, level: int, slots: Array = []) -> Dictionary:
    var rarity := _weighted(rng, weights)
    return GEAR.roll(_base(rng, slots, rarity, level), rarity, rng)

## The gear a creature of this tier (and level) drops, or {} (no drop).
static func roll_drop(difficulty: int, rng: RandomNumberGenerator, level: int = 1) -> Dictionary:
    var dev := preload("res://scripts/dev/dev_tools.gd")
    if dev.loot and dev.available():
        # The owner's mod menu (dev build): every creature drops, mostly Epic and better.
        return _item(rng, dev.LOOT_RARITY, maxi(level, 6))
    if rng.randf() >= DROP_CHANCE[difficulty]:
        return {}
    return _item(rng, DROP_RARITY[difficulty], level)

static func roll_chest(rng: RandomNumberGenerator, level: int = 6) -> Dictionary:
    return _item(rng, CHEST_RARITY, level)

static func roll_trial(rng: RandomNumberGenerator, level: int = 6) -> Dictionary:
    return _item(rng, TRIAL_RARITY, level)

static func roll_forge(recipe: String, rng: RandomNumberGenerator, level: int = 4) -> Dictionary:
    return _item(rng, FORGE_RARITY, level, RECIPES[recipe].slots)

static func recipe_text(recipe: String) -> String:
    var parts: Array = []
    var names := {"gnasher_essence": "Gnasher Essence", "thornback_quill": "Thornback Quill"}
    for material in RECIPES[recipe].materials:
        parts.append("%d %s" % [RECIPES[recipe].materials[material], names[material]])
    return " + ".join(parts)

## Each character opens each chest of the world once (IDs chest_1..chest_3, same in every seed).
static func valid_opened(opened: Variant, chest_ids: Array) -> bool:
    if not opened is Array or opened.size() > chest_ids.size():
        return false
    var seen := {}
    for id in opened:
        if not id is String or not id in chest_ids or seen.has(id):
            return false
        seen[id] = true
    return true

## Saved ground loot: [{id: loot_<hex>, position, item}].
static func valid_loot(entry: Variant) -> bool:
    if not entry is Dictionary or entry.size() != 5 or not entry.get("id") is String or not entry.id.begins_with("loot_") or entry.id.length() > 64:
        return false
    # 24a: loot handed out by damage rank has an owner and a claim window ("" / 0 = anyone).
    if not entry.get("owner") is String or not (entry.get("claim_until") is float or entry.get("claim_until") is int) or not is_finite(float(entry.claim_until)) or float(entry.claim_until) < 0.0:
        return false
    return entry.get("position") is Array and entry.position.size() == 2 and GEAR.valid_item(entry.get("item"))
