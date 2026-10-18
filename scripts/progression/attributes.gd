extends RefCounted
## Attributes (M12a, user decision): Strength, Dexterity, Intelligence and Vitality. Every level
## after the first gives POINTS_PER_LEVEL points to spend (so characters from older saves have
## theirs at once); the class master resets them. Kept per character in progression.attributes
## {"str", "dex", "int", "vit": spent points}; the unspent points follow from the level.
##   STR  more weapon and unarmed damage
##   DEX  faster attacks, faster movement and a chance to strike critically
##   INT  more Magicules and stronger skills (and Mage staff bolts, M12c)
##   VIT  more health and defence
## Legendary and Mythic weapons ask for attributes (M12b).
const KEYS := ["str", "dex", "int", "vit"]
const NAMES := {"str": "Strength", "dex": "Dexterity", "int": "Intelligence", "vit": "Vitality"}
const SHORT := {"str": "STR", "dex": "DEX", "int": "INT", "vit": "VIT"}
const POINTS_PER_LEVEL := 4
## Effects per point.
const STR_DAMAGE := 0.008
const DEX_RECOVERY := 0.002
const DEX_RECOVERY_CAP := 0.3
const DEX_SPEED := 0.15
const DEX_CRIT := 0.002
const CRIT_CAP := 0.35
const CRIT_FACTOR := 1.75
const INT_MAGICULES := 2.0
const INT_SKILL := 0.008
const VIT_HP := 4
const VIT_DEFENSE := 0.06

static func spent(progression: Dictionary) -> Dictionary:
    var stored: Variant = progression.get("attributes")
    var result := {}
    for key in KEYS:
        result[key] = int(stored.get(key, 0)) if stored is Dictionary else 0
    return result

static func value(progression: Dictionary, key: String) -> int:
    return int(spent(progression).get(key, 0))

static func total_points(progression: Dictionary) -> int:
    return POINTS_PER_LEVEL * maxi(0, int(progression.get("level", 1)) - 1)

static func unspent(progression: Dictionary) -> int:
    var used := 0
    var all := spent(progression)
    for key in KEYS:
        used += int(all[key])
    return maxi(0, total_points(progression) - used)

## Multipliers and bonuses.
static func damage_factor(progression: Dictionary) -> float:
    return 1.0 + value(progression, "str") * STR_DAMAGE

static func skill_factor(progression: Dictionary) -> float:
    return 1.0 + value(progression, "int") * INT_SKILL

static func recovery_factor(progression: Dictionary) -> float:
    return 1.0 - minf(DEX_RECOVERY_CAP, value(progression, "dex") * DEX_RECOVERY)

static func crit_chance(progression: Dictionary) -> float:
    return minf(CRIT_CAP, value(progression, "dex") * DEX_CRIT)

## Live stat bonuses (read through the character's gear bonus): speed and defence.
static func bonus(progression: Dictionary, stat: String) -> float:
    match stat:
        "speed":
            return value(progression, "dex") * DEX_SPEED
        "defense":
            return floorf(value(progression, "vit") * VIT_DEFENSE)
    return 0.0

## Capacity a point of an attribute adds: [HP, Magicules].
static func capacity(key: String) -> Array:
    match key:
        "vit":
            return [VIT_HP, 0.0]
        "int":
            return [0, INT_MAGICULES]
    return [0, 0.0]

static func valid(progression: Dictionary) -> bool:
    if not progression.has("attributes"):
        return true
    var stored: Variant = progression.attributes
    if not stored is Dictionary or stored.size() > KEYS.size():
        return false
    var used := 0
    for key in stored:
        var points: Variant = stored[key]
        if not key in KEYS or not (points is int or points is float) or int(points) < 0 or int(points) != float(points):
            return false
        used += int(points)
    return used <= total_points(progression)
