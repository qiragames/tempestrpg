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
static func unlockable(known: Array, evidence: Dictionary, rules: Dictionary = RULES) -> Array:
    var have: Array = known.duplicate()
    var gained: Array = []
    for tier in TIERS:
        for id in rules:
            if rules[id].tier == tier and not id in have and requirements_met(id, have, evidence, rules):
                have.append(id)
                gained.append(id)
    return gained

## Every known skill needs valid evidence and its prerequisites in the actual known set.
static func justified(known: Array, evidence: Dictionary, rules: Dictionary = RULES) -> bool:
    var derivable: Array = unlockable([], evidence, rules)
    for id in known:
        if not id in derivable or not requirements_met(id, known, evidence, rules):
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
