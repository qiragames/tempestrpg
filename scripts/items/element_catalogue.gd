extends RefCounted
## Elements (item expansion, user request): weapons of Rare and up can carry an element that acts
## on every hit, stronger with rarity; armour elements add a themed stat (generator). Colours drive
## the names' palette and the VFX (glow, particles, hit bursts).
## [name, colour, what a hit does]
const ELEMENTS := {
    "fire": ["Fire", "ff7a2a", "burns: %s damage per second for 3 s"],
    "frost": ["Frost", "8fdcff", "chills: slows the target to %s%% speed for 1.5 s"],
    "storm": ["Storm", "ffe14a", "arcs to one more creature nearby for %s damage"],
    "shadow": ["Shadow", "b06cff", "%s%% chance to strike twice as hard"],
    "holy": ["Holy", "fff2a8", "heals you for %s%% of the damage"],
    "nature": ["Nature", "8fe05a", "poisons: %s damage per second for 6 s"],
    "blood": ["Blood", "ff3a55", "bleeds: %s damage per second for 3 s, heals you a little"],
    "arcane": ["Arcane", "ff70f0", "restores %s Magicules"],
}
## Strength by rarity (elements start at Rare).
const POWER := [0.0, 0.0, 1.0, 1.3, 1.6, 2.0]
const CHAIN_REACH := 56.0

static func power(rarity: int) -> float:
    return POWER[clampi(rarity, 0, POWER.size() - 1)]

static func color(element: String) -> Color:
    return Color(ELEMENTS[element][1]) if ELEMENTS.has(element) else Color.WHITE

## What one hit with `damage` does: status effects for the creature ("dot", "slow") plus the
## wielder's side ("heal" share, "magicules", "chain" damage, "crit" chance).
static func on_hit(element: String, rarity: int, damage: int, boost: float = 1.0) -> Dictionary:
    var p := power(rarity) * boost
    if p <= 0.0 or not ELEMENTS.has(element):
        return {}
    match element:
        "fire":
            return {"dot": [maxf(1.0, roundf(damage * 0.15 * p)), 3.0]}
        "frost":
            return {"slow": [clampf(0.75 - 0.08 * p, 0.4, 0.8), 1.5]}
        "storm":
            return {"chain": maxi(1, int(round(damage * 0.35 * p)))}
        "shadow":
            return {"crit": clampf(0.1 * p, 0.0, 0.3)}
        "holy":
            return {"heal": 0.06 * p}
        "nature":
            return {"dot": [maxf(1.0, roundf(damage * 0.07 * p)), 6.0]}
        "blood":
            return {"dot": [maxf(1.0, roundf(damage * 0.1 * p)), 3.0], "heal": 0.03 * p}
        "arcane":
            return {"magicules": roundf(1.5 * p * 10.0) / 10.0}
    return {}

## The line on an item card.
static func describe(element: String, rarity: int, damage: int) -> String:
    var effect := on_hit(element, rarity, damage)
    if effect.is_empty():
        return ""
    var value: String
    match element:
        "fire", "nature", "blood":
            value = str(int(effect.dot[0]))
        "frost":
            value = str(int(round(effect.slow[0] * 100.0)))
        "storm":
            value = str(effect.chain)
        "shadow":
            value = str(int(round(effect.crit * 100.0)))
        "holy":
            value = str(int(round(effect.heal * 100.0)))
        "arcane":
            value = str(effect.magicules)
    return "%s: %s" % [ELEMENTS[element][0], ELEMENTS[element][2] % value]
