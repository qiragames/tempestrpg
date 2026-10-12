extends RefCounted
## Mimic forms: stable IDs, the analysis that unlocks each one, its cost and its bounded
## differences. The base form is the smallest, so reverting to it always fits.

const BASE := "slime"
const CHANGE_COOLDOWN := 2.0
const FORMS := {
    "slime": {"name": "Slime", "analysis": "", "cost": 0.0, "speed": 1.0, "strike_bonus": 0, "radius": 6.0},
    "gnasher": {"name": "Gnasher Form", "analysis": "forest_gnasher", "cost": 20.0, "speed": 1.3, "strike_bonus": 4, "radius": 8.0},
}

static func unlocked(id: String, evidence: Dictionary) -> bool:
    if not FORMS.has(id):
        return false
    return id == BASE or FORMS[id].analysis in evidence.get("analyzed", [])

## Forms this evidence unlocks, base first.
static func available(evidence: Dictionary) -> Array:
    var result: Array = []
    for id in FORMS:
        if unlocked(id, evidence):
            result.append(id)
    return result
