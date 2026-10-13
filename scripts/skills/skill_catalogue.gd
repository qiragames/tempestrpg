extends RefCounted
## Stable skill/specimen IDs and tier unlock rules. The host evaluates these rules against one
## character's own evidence; clients never send unlocks, and saves keep only justified skills.
##
## Rule shapes by tier:
##   Common   {"analysis": specimen}                         analyze that specimen
##   Extra    {"requires": [Common...], "analysis": specimen} know every Common, then analyze
##   Unique   {"requires": [Extra], "trial": trial}          know the Extra, complete the trial
##   Ultimate {"requires": [Unique], "ascension": milestone}  know + master the Unique, ascend
## No trial or ascension can be earned yet, so Unique/Ultimate stay locked until later steps add them.
##
## Fusion (step 17d): Extra skills are never granted automatically. An Extra rule is a fusion
## recipe — its two `requires` skills are fused in the fusion window (both are replaced by the Extra)
## once its `analysis` evidence exists. A fused skill can always be split back into the two.

const TIERS := ["Common", "Extra", "Unique", "Ultimate"]
const EVIDENCE_KINDS := ["analyzed", "trials", "mastery", "ascensions"]
const EFFECTS := ["strike", "pierce", "focus"]
const SPECIMENS := {"forest_gnasher": "res://data/specimens/forest_gnasher.tres", "thornback_gnasher": "res://data/specimens/thornback_gnasher.tres"}
## Dimensional-storage material retained by each specimen.
const MATERIALS := {"gnasher_essence": "forest_gnasher", "thornback_quill": "thornback_gnasher"}
const SKILLS := {"rending_bite": "res://data/skills/rending_bite.tres", "thorn_lash": "res://data/skills/thorn_lash.tres", "piercing_fang": "res://data/skills/piercing_fang.tres", "predator_focus": "res://data/skills/predator_focus.tres"}
const RULES := {
    "rending_bite": {"tier": "Common", "analysis": "forest_gnasher"},
    "thorn_lash": {"tier": "Common", "analysis": "thornback_gnasher"},
    "piercing_fang": {"tier": "Extra", "requires": ["rending_bite", "thorn_lash"], "analysis": "thornback_gnasher"},
    "predator_focus": {"tier": "Unique", "requires": ["piercing_fang"], "trial": "proving_trial"},
}
## Trials and ascension milestones that can actually be completed. No ascension exists before M6,
## so Ultimate skills stay locked.
const TRIALS := {"proving_trial": "Proving Trial"}
const ASCENSIONS := {}

const FUSED_TIERS := ["Extra"]

static func is_fused(id: String, rules: Dictionary = RULES) -> bool:
    return rules.has(id) and rules[id].tier in FUSED_TIERS

## The two skills a fused skill is made of (empty for other skills).
static func components(id: String, rules: Dictionary = RULES) -> Array:
    return rules[id].requires.duplicate() if is_fused(id, rules) else []

## The fused skill two skills make together (either order), or "" if they do not fuse.
static func fusion_for(a: String, b: String, rules: Dictionary = RULES) -> String:
    for id in rules:
        if is_fused(id, rules) and rules[id].requires.size() == 2 and a != b and a in rules[id].requires and b in rules[id].requires:
            return id
    return ""

## Held skills plus what fusing/splitting them could give: components of held fused skills, and
## fused skills whose components are all present and whose analysis is met. Prerequisites of
## higher tiers are checked against this, so splitting a fused skill never invalidates a Unique.
static func closure(known: Array, evidence: Dictionary, rules: Dictionary = RULES) -> Array:
    var have: Array = known.duplicate()
    var changed := true
    while changed:
        changed = false
        for id in rules:
            if not is_fused(id, rules):
                continue
            if id in have:
                for part in rules[id].requires:
                    if not part in have:
                        have.append(part)
                        changed = true
            elif rules[id].requires.all(func(part): return part in have) and rules[id].analysis in evidence.analyzed:
                have.append(id)
                changed = true
    return have

static func empty_evidence() -> Dictionary:
    return {"analyzed": [], "trials": [], "mastery": [], "ascensions": []}

## Every problem in a rule set; an empty result means the catalogue is consistent.
static func catalogue_errors(rules: Dictionary = RULES, specimens: Dictionary = SPECIMENS, trials: Dictionary = TRIALS, ascensions: Dictionary = ASCENSIONS) -> Array:
    var errors: Array = []
    var expected_keys := {"Common": ["analysis", "tier"], "Extra": ["analysis", "requires", "tier"], "Unique": ["requires", "tier", "trial"], "Ultimate": ["ascension", "requires", "tier"]}
    for id in rules:
        var rule: Dictionary = rules[id]
        var tier: Variant = rule.get("tier")
        if not tier in TIERS:
            errors.append("%s: unknown tier %s" % [id, tier])
            continue
        var keys: Array = rule.keys()
        keys.sort()
        if keys != expected_keys[tier]:
            errors.append("%s: %s rule needs exactly %s" % [id, tier, expected_keys[tier]])
            continue
        if rule.has("analysis") and not specimens.has(rule.analysis):
            errors.append("%s: unknown specimen %s" % [id, rule.analysis])
        if rule.has("trial") and not trials.has(rule.trial):
            errors.append("%s: unknown trial %s" % [id, rule.trial])
        if rule.has("ascension") and not ascensions.has(rule.ascension):
            errors.append("%s: unknown ascension %s" % [id, rule.ascension])
        if rule.has("requires"):
            var needed: String = TIERS[TIERS.find(tier) - 1]
            var count: int = rule.requires.size()
            if count == 0 or (tier != "Extra" and count != 1):
                errors.append("%s: %s needs %s prerequisite" % [id, tier, "one" if tier != "Extra" else "at least one"])
            for prerequisite in rule.requires:
                if not rules.has(prerequisite):
                    errors.append("%s: missing prerequisite %s" % [id, prerequisite])
                elif rules[prerequisite].get("tier") != needed:
                    errors.append("%s: prerequisite %s must be %s" % [id, prerequisite, needed])
    return errors

## Skill resources must match their rule: same ID, same tier label and a known effect.
static func resource_errors() -> Array:
    var errors: Array = catalogue_errors()
    for id in RULES:
        if not SKILLS.has(id):
            errors.append("%s: no skill resource" % id)
            continue
        var skill: Resource = load(SKILLS[id])
        if skill == null or String(skill.id) != id or skill.tier != RULES[id].tier or not String(skill.effect) in EFFECTS:
            errors.append("%s: resource does not match its rule" % id)
    for id in SKILLS:
        if not RULES.has(id):
            errors.append("%s: skill resource without unlock rule" % id)
    for id in SPECIMENS:
        var specimen: Resource = load(SPECIMENS[id])
        if specimen == null or String(specimen.id) != id or MATERIALS.get(String(specimen.material_id)) != id or specimen.skill == null or not RULES.has(String(specimen.skill.id)):
            errors.append("%s: specimen resource does not match the catalogue" % id)
    return errors

static func requirements(id: String, known: Array, evidence: Dictionary, rules: Dictionary = RULES) -> Array:
    var rule: Dictionary = rules[id]
    var result: Array = []
    for prerequisite in rule.get("requires", []):
        result.append({"kind": "skill", "id": prerequisite, "met": prerequisite in known})
    if rule.has("analysis"):
        result.append({"kind": "analysis", "id": rule.analysis, "met": rule.analysis in evidence.analyzed})
    if rule.has("trial"):
        result.append({"kind": "trial", "id": rule.trial, "met": rule.trial in evidence.trials})
    if rule.tier == "Ultimate":
        var unique: String = rule.requires[0]
        result.append({"kind": "mastery", "id": unique, "met": unique in evidence.mastery})
        result.append({"kind": "ascension", "id": rule.ascension, "met": rule.ascension in evidence.ascensions})
    return result

static func requirements_met(id: String, known: Array, evidence: Dictionary, rules: Dictionary = RULES) -> bool:
    for requirement in requirements(id, known, evidence, rules):
        if not requirement.met:
            return false
    return true

## Skills the evidence now unlocks, lower tiers first so one analysis can satisfy a chain.
## `automatic` (granting in play) skips fused tiers — those come only from the fusion window — and
## checks prerequisites against the closure, so a Unique sees a fused skill that was split again.
static func unlockable(known: Array, evidence: Dictionary, rules: Dictionary = RULES, automatic: bool = false) -> Array:
    var have: Array = known.duplicate()
    var gained: Array = []
    for tier in TIERS:
        for id in rules:
            if rules[id].tier != tier or id in have or (automatic and tier in FUSED_TIERS):
                continue
            # A part consumed by a held fused skill is not granted again (Split gives it back).
            if automatic and id in closure(have, evidence, rules):
                continue
            if requirements_met(id, closure(have, evidence, rules) if automatic else have, evidence, rules):
                have.append(id)
                gained.append(id)
    return gained

## Every held skill needs valid evidence and its prerequisites in the closure; a fused skill's
## components are consumed, so they can never be held at the same time as it.
static func justified(known: Array, evidence: Dictionary, rules: Dictionary = RULES) -> bool:
    var derivable: Array = unlockable([], evidence, rules)
    var reachable: Array = closure(known, evidence, rules)
    for id in known:
        if not id in derivable or not requirements_met(id, reachable, evidence, rules):
            return false
        for part in components(id, rules):
            if part in known:
                return false
    return true

static func evidence_valid(evidence: Variant, known: Array = []) -> bool:
    if not evidence is Dictionary or evidence.size() != EVIDENCE_KINDS.size():
        return false
    var sources := {"analyzed": SPECIMENS, "trials": TRIALS, "ascensions": ASCENSIONS}
    for kind in EVIDENCE_KINDS:
        var entries: Variant = evidence.get(kind)
        if not entries is Array or entries.size() > 64:
            return false
        var seen := {}
        for entry in entries:
            if not entry is String or seen.has(entry):
                return false
            seen[entry] = true
            if kind == "mastery":
                # Mastery is recorded only for a known Unique skill.
                if not RULES.has(entry) or RULES[entry].tier != "Unique" or not entry in known:
                    return false
            elif not sources[kind].has(entry):
                return false
    return true

## Read-only view for the hotbar, assistant and future skill panels.
static func overview(known: Array, evidence: Dictionary) -> Array:
    var result: Array = []
    for tier in TIERS:
        for id in RULES:
            if RULES[id].tier != tier:
                continue
            var skill: Resource = load(SKILLS[id])
            result.append({"id": id, "name": skill.display_name, "tier": tier, "known": id in known, "requirements": requirements(id, known, evidence)})
    return result
