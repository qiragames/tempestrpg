extends RefCounted
## Skill damage and utility (step 24b, user decisions). Damage grows with the Magicule cost but less
## than linearly: damage = UNIT_DAMAGE * (cost / UNIT_COST)^EXPONENT, measured against the Slime's
## basic strike (12 damage for 2 Magicules) — a skill costing 10x a basic strike does about 5.6x
## its damage. Every damaging skill adds a utility effect of one of the four kinds the user chose:
## slow/root, knockback/stun, area/damage over time, self buffs/drain.
const UNIT_DAMAGE := 12.0
const UNIT_COST := 2.0
const EXPONENT := 0.75

## Keys: slow [factor, seconds] · root seconds · stun seconds · knockback px · dot [per second,
## seconds] · area radius (hits everything around the strike point) · drain share of damage
## dealt healed · dash px (the caster lunges forward first).
const EFFECTS := {
    "thorn_lash": {"slow": [0.5, 2.0]},
    "acid_splash": {"area": 28.0, "dot": [4.0, 3.0]},
    "shadow_claw": {"drain": 0.3},
    "rending_bite": {"dot": [5.0, 3.0]},
    "power_slash": {"knockback": 36.0, "stun": 0.6},
    "engulf": {"root": 1.5, "dot": [3.0, 2.0]},
    "lunge": {"dash": 48.0, "knockback": 20.0},
    "piercing_fang": {"stun": 0.5, "dot": [4.0, 3.0]},
    "dark_lance": {"slow": [0.4, 2.5]},
    # M4.5c region creatures' skills.
    "frost_maul": {"stun": 0.5, "slow": [0.6, 2.0]},
    "chill_touch": {"slow": [0.4, 3.0]},
    "venom_fang": {"dot": [6.0, 3.0]},
    "sand_burst": {"area": 30.0, "slow": [0.6, 1.5]},
    "mire_grasp": {"root": 2.0},
    "spore_cloud": {"area": 28.0, "dot": [4.0, 3.0]},
    "bamboo_thrust": {"knockback": 30.0},
    "lantern_flare": {"area": 26.0, "dot": [5.0, 2.0]},
    "gale_wing": {"dash": 32.0, "knockback": 40.0},
    "burrow_strike": {"dash": 40.0, "stun": 0.4},
    "ember_burst": {"area": 32.0, "dot": [6.0, 3.0]},
    "magma_bite": {"dot": [8.0, 3.0], "drain": 0.2},
    # M4.5c scroll-only skills.
    "tempest_edge": {"area": 34.0, "knockback": 40.0},
    "glacial_nova": {"area": 40.0, "root": 1.0, "slow": [0.4, 3.0]},
    "meteor_fall": {"area": 36.0, "stun": 0.8, "dot": [8.0, 3.0]},
    "phantom_step": {"dash": 64.0, "stun": 0.6, "drain": 0.2},
    # M4.7 ki attacks: "reach"/"width" shape a beam, "color" tints it.
    "ki_blast": {"reach": 130.0, "width": 8.0, "color": "8fe3ff"},
    "turtle_wave": {"reach": 220.0, "width": 16.0, "knockback": 40.0, "color": "7fd8ff"},
    "ki_disc": {"reach": 150.0, "width": 6.0, "dot": [6.0, 3.0], "color": "f8f39a"},
    "spirit_orb": {"area": 72.0, "stun": 0.8, "color": "a8e6ff"},
}
## Short words for tooltips and the skill tree.
const SUMMARY := {
    "slow": "slows", "root": "roots", "stun": "stuns", "knockback": "knocks back", "dot": "burns/bleeds",
    "area": "hits an area", "drain": "drains HP", "dash": "dashes forward",
    "reach": "long beam", "width": "", "color": "",
}

static func damage_for(cost: float) -> int:
    return int(round(UNIT_DAMAGE * pow(maxf(cost, 0.0) / UNIT_COST, EXPONENT)))

static func effects(id: String) -> Dictionary:
    return EFFECTS.get(id, {})

## e.g. "slows · burns/bleeds"
static func describe(id: String) -> String:
    var words: Array = []
    for key in effects(id):
        if not String(SUMMARY.get(key, "")).is_empty():
            words.append(SUMMARY[key])
    return " · ".join(words)
