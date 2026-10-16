extends RefCounted
## Pets (M11f, user request): small animal companions that follow their owner and give a small
## bonus. Mysterious Eggs drop now and then from creatures (more often from elites and bosses; a
## treasure goblin always carries one); using an egg hatches a pet you do not have yet. Each
## character keeps progression.pets (the ones they own) and progression.pet (the one following,
## "" for none). Art: Ninja Adventure Actor/Animal (CC0), two side-view frames of 16 × 16.

## id → [name, bonus text, bonuses {stat: value}]. Stats: defense, speed, strike (like gear),
## xp and zeni (percent more from everything).
const PETS := {
    "cat": ["Whiskers the Cat", "+5% XP", {"xp": 5.0}],
    "ginger_cat": ["Marmalade", "+5% Zeni", {"zeni": 5.0}],
    "dog": ["Rufus the Dog", "+3 defence", {"defense": 3.0}],
    "golden_pup": ["Goldie", "+8 move speed", {"speed": 8.0}],
    "hamster": ["Nibbles", "+3% XP and +3% Zeni", {"xp": 3.0, "zeni": 3.0}],
    "parrot": ["Captain Squawk", "+10% Zeni", {"zeni": 10.0}],
    "lion_cub": ["Little Roar", "+2 strike damage", {"strike": 2.0}],
    "frog": ["Sir Ribbit", "+2 defence, +4 move speed", {"defense": 2.0, "speed": 4.0}],
    "chick": ["Pip", "+4% XP", {"xp": 4.0}],
    "racoon": ["Bandit", "+8% XP and +8% Zeni (rare)", {"xp": 8.0, "zeni": 8.0}],
}
const ORDER := ["cat", "ginger_cat", "dog", "golden_pup", "hamster", "parrot", "lion_cub", "frog", "chick", "racoon"]
const EGG := "pet_egg"
## Chance a defeated creature drops an egg for its top damage dealer, by difficulty (easy,
## standard, elite) and for bosses.
const EGG_CHANCE := [0.004, 0.008, 0.03]
const BOSS_EGG_CHANCE := 0.25
## The racoon hatches rarely (one egg in ten while others remain).
const RARE := ["racoon"]

static func texture(id: String) -> Texture2D:
    var path := "res://assets/game/sprites/pets/pet_%s.png" % id
    return load(path) if ResourceLoader.exists(path) else null

static func face(id: String) -> Texture2D:
    var path := "res://assets/game/sprites/pets/pet_%s_face.png" % id
    return load(path) if ResourceLoader.exists(path) else null

static func owned(progression: Dictionary) -> Array:
    return progression.get("pets", []) if progression.get("pets") is Array else []

static func active(progression: Dictionary) -> String:
    var id := String(progression.get("pet", ""))
    return id if PETS.has(id) and id in owned(progression) else ""

## The following pet's bonus to a stat (0 without one).
static func bonus(progression: Dictionary, stat: String) -> float:
    var id := active(progression)
    return float(PETS[id][2].get(stat, 0.0)) if not id.is_empty() else 0.0

## Which pet an egg hatches: one not owned yet (the rare ones less often), or "" when all are.
static func hatch(progression: Dictionary, rng: RandomNumberGenerator) -> String:
    var missing: Array = ORDER.filter(func(id): return not id in owned(progression))
    if missing.is_empty():
        return ""
    var common: Array = missing.filter(func(id): return not id in RARE)
    if not common.is_empty() and (rng.randf() >= 0.1 or common.size() == missing.size()):
        return common[rng.randi_range(0, common.size() - 1)]
    var rare: Array = missing.filter(func(id): return id in RARE)
    return rare[rng.randi_range(0, rare.size() - 1)] if not rare.is_empty() else common[rng.randi_range(0, common.size() - 1)]

static func valid(progression: Dictionary) -> bool:
    if progression.has("pets"):
        var pets: Variant = progression.pets
        if not pets is Array or pets.size() > ORDER.size():
            return false
        var seen := {}
        for id in pets:
            if not id is String or not PETS.has(id) or seen.has(id):
                return false
            seen[id] = true
    if progression.has("pet"):
        if not progression.pet is String or (not String(progression.pet).is_empty() and not progression.pet in owned(progression)):
            return false
    return true
