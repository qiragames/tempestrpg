extends RefCounted
## Gear sources (step 17g): creature drops, seeded chests, the trial reward and camp forge recipes.
## All rolls happen on the host. Merchants follow with currency in M4.5/M5.
## Starting numbers, tuned in step 24.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")

## Chance a defeated creature drops gear, by tier [Easy, Standard, Elite].
const DROP_CHANCE := [0.1, 0.2, 0.45]
## Rarity weights [Common, Uncommon, Rare, Epic, Legendary].
const DROP_RARITY := [[70, 25, 5, 0, 0], [50, 32, 14, 4, 0], [20, 35, 28, 13, 4]]
const CHEST_RARITY := [0, 50, 35, 13, 2]
const TRIAL_RARITY := [0, 0, 70, 30, 0]
const FORGE_RARITY := [60, 30, 10, 0, 0]
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

static func _base(rng: RandomNumberGenerator, slots: Array = []) -> String:
    var pool: Array = GEAR.BASES.keys().filter(func(id): return slots.is_empty() or GEAR.BASES[id].slot in slots)
    return pool[rng.randi_range(0, pool.size() - 1)]

## The gear a creature of this tier drops, or {} (no drop).
static func roll_drop(difficulty: int, rng: RandomNumberGenerator) -> Dictionary:
    if rng.randf() >= DROP_CHANCE[difficulty]:
        return {}
    return GEAR.roll(_base(rng), _weighted(rng, DROP_RARITY[difficulty]), rng)

static func roll_chest(rng: RandomNumberGenerator) -> Dictionary:
    return GEAR.roll(_base(rng), _weighted(rng, CHEST_RARITY), rng)

static func roll_trial(rng: RandomNumberGenerator) -> Dictionary:
    return GEAR.roll(_base(rng), _weighted(rng, TRIAL_RARITY), rng)

static func roll_forge(recipe: String, rng: RandomNumberGenerator) -> Dictionary:
    return GEAR.roll(_base(rng, RECIPES[recipe].slots), _weighted(rng, FORGE_RARITY), rng)

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
    if not entry is Dictionary or entry.size() != 3 or not entry.get("id") is String or not entry.id.begins_with("loot_") or entry.id.length() > 64:
        return false
    return entry.get("position") is Array and entry.position.size() == 2 and GEAR.valid_item(entry.get("item"))
