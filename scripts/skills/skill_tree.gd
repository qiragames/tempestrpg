extends RefCounted
## Per-race skill tree (step 17c). Every level gives one skill point (level 1 included). Points buy
## tree nodes — stat upgrades, and every third node a new skill — and activate skills learned by
## absorbing or trials: a learned skill cannot be used or slotted until it is activated.
##
## Saved per character as progression.tree = {nodes, active, free}:
##   nodes   bought node IDs (this race's, prerequisites first)
##   active  activated evidence skills (absorbed / trial skills)
##   free    activated without a point by the v15 migration (characters keep what they could use)
## Invariant: skill_points + spent == level, spent = nodes × COST + (active − free) × ACTIVATE_COST.
const CATALOGUE := preload("res://scripts/skills/skill_catalogue.gd")
const RACES := preload("res://scripts/races/race_catalogue.gd")
const COST := 1
const ACTIVATE_COST := 1
const STATS := ["hp", "magicules", "regen", "speed", "strike"]
## Skills granted by tree nodes (not by evidence); IDs never overlap CATALOGUE.SKILLS.
const SKILLS := {
    "acid_splash": "res://data/skills/acid_splash.tres", "engulf": "res://data/skills/engulf.tres",
    "power_slash": "res://data/skills/power_slash.tres", "lunge": "res://data/skills/lunge.tres",
    "shadow_claw": "res://data/skills/shadow_claw.tres", "dark_lance": "res://data/skills/dark_lance.tres",
}
## Three rows per race: two stat nodes, then (rows 1–2) a skill node that needs both.
## Row 2's stat nodes need row 1's skill; row 3's need row 2's skill. Order = display order.
const NODES := {
    "slime_vitality": {"race": "Slime", "row": 0, "name": "Gel Vitality", "requires": [], "stat": "hp", "amount": 10},
    "slime_reserve": {"race": "Slime", "row": 0, "name": "Aura Reserve", "requires": [], "stat": "magicules", "amount": 10},
    "slime_acid_splash": {"race": "Slime", "row": 0, "name": "Acid Splash", "requires": ["slime_vitality", "slime_reserve"], "skill": "acid_splash"},
    "slime_digest": {"race": "Slime", "row": 1, "name": "Quick Digestion", "requires": ["slime_acid_splash"], "stat": "regen", "amount": 0.5},
    "slime_bounce": {"race": "Slime", "row": 1, "name": "Bounce", "requires": ["slime_acid_splash"], "stat": "speed", "amount": 5},
    "slime_engulf": {"race": "Slime", "row": 1, "name": "Engulf", "requires": ["slime_digest", "slime_bounce"], "skill": "engulf"},
    "slime_mass": {"race": "Slime", "row": 2, "name": "Dense Mass", "requires": ["slime_engulf"], "stat": "hp", "amount": 15},
    "slime_core": {"race": "Slime", "row": 2, "name": "Magic Core", "requires": ["slime_engulf"], "stat": "magicules", "amount": 15},
    "human_endurance": {"race": "Human", "row": 0, "name": "Endurance", "requires": [], "stat": "hp", "amount": 10},
    "human_drill": {"race": "Human", "row": 0, "name": "Weapon Drill", "requires": [], "stat": "strike", "amount": 1},
    "human_power_slash": {"race": "Human", "row": 0, "name": "Power Slash", "requires": ["human_endurance", "human_drill"], "skill": "power_slash"},
    "human_focus": {"race": "Human", "row": 1, "name": "Focus", "requires": ["human_power_slash"], "stat": "magicules", "amount": 10},
    "human_footwork": {"race": "Human", "row": 1, "name": "Footwork", "requires": ["human_power_slash"], "stat": "speed", "amount": 5},
    "human_lunge": {"race": "Human", "row": 1, "name": "Lunge", "requires": ["human_focus", "human_footwork"], "skill": "lunge"},
    "human_toughness": {"race": "Human", "row": 2, "name": "Toughness", "requires": ["human_lunge"], "stat": "hp", "amount": 15},
    "human_veteran": {"race": "Human", "row": 2, "name": "Veteran", "requires": ["human_lunge"], "stat": "strike", "amount": 2},
    "demon_hunger": {"race": "Demon", "row": 0, "name": "Hunger", "requires": [], "stat": "magicules", "amount": 10},
    "demon_hide": {"race": "Demon", "row": 0, "name": "Thick Hide", "requires": [], "stat": "hp", "amount": 10},
    "demon_shadow_claw": {"race": "Demon", "row": 0, "name": "Shadow Claw", "requires": ["demon_hunger", "demon_hide"], "skill": "shadow_claw"},
    "demon_well": {"race": "Demon", "row": 1, "name": "Dark Well", "requires": ["demon_shadow_claw"], "stat": "regen", "amount": 0.5},
    "demon_stride": {"race": "Demon", "row": 1, "name": "Stride", "requires": ["demon_shadow_claw"], "stat": "speed", "amount": 5},
    "demon_dark_lance": {"race": "Demon", "row": 1, "name": "Dark Lance", "requires": ["demon_well", "demon_stride"], "skill": "dark_lance"},
    "demon_abyss": {"race": "Demon", "row": 2, "name": "Abyssal Pool", "requires": ["demon_dark_lance"], "stat": "magicules", "amount": 15},
    "demon_fury": {"race": "Demon", "row": 2, "name": "Fury", "requires": ["demon_dark_lance"], "stat": "strike", "amount": 1},
}
const STAT_TEXT := {"hp": "+%s max HP", "magicules": "+%s max Magicules", "regen": "+%s Magicules/s", "speed": "+%s move speed", "strike": "+%s strike damage"}

static func empty() -> Dictionary:
    return {"nodes": [], "active": [], "free": []}

static func nodes_for(race: String) -> Array:
    return NODES.keys().filter(func(id): return NODES[id].race == race)

static func describe_node(id: String) -> String:
    var node: Dictionary = NODES[id]
    if node.has("skill"):
        var skill: Resource = load(SKILLS[node.skill])
        return "New skill: %s — %d dmg, %d Magicules. %s" % [skill.display_name, skill.damage, int(skill.magicule_cost), skill.description]
    return STAT_TEXT[node.stat] % str(node.amount)

static func spent(tree: Dictionary) -> int:
    var paid: int = 0
    for id in tree.active:
        if not id in tree.free:
            paid += ACTIVATE_COST
    return tree.nodes.size() * COST + paid

static func granted_skills(nodes: Array) -> Array:
    var result: Array = []
    for id in nodes:
        if NODES.has(id) and NODES[id].has("skill"):
            result.append(NODES[id].skill)
    return result

static func stat_bonus(nodes: Array, stat: String) -> float:
    var total := 0.0
    for id in nodes:
        if NODES.has(id) and NODES[id].get("stat") == stat:
            total += NODES[id].amount
    return total

## Why a node cannot be bought right now ("" when it can).
static func buy_problem(progression: Dictionary, id: String) -> String:
    if not NODES.has(id):
        return "Unknown node."
    var tree: Dictionary = progression.tree
    if NODES[id].race != progression.race:
        return "That node belongs to another race's tree."
    if id in tree.nodes:
        return "Already learned."
    for requirement in NODES[id].requires:
        if not requirement in tree.nodes:
            return "Learn %s first." % NODES[requirement].name
    if int(progression.skill_points) < COST:
        return "No skill points left. Level up to earn more."
    return ""

## Why a learned skill cannot be activated right now ("" when it can).
static func activate_problem(progression: Dictionary, known: Array, id: String) -> String:
    if not CATALOGUE.SKILLS.has(id) or not id in known:
        return "That skill has not been learned."
    if id in progression.tree.active:
        return "Already active."
    if int(progression.skill_points) < ACTIVATE_COST:
        return "No skill points left. Level up to earn more."
    return ""

## Saved-tree validation against the character's race, level and evidence-learned skills.
static func valid(progression: Dictionary, known: Array) -> bool:
    var tree: Variant = progression.get("tree")
    if not tree is Dictionary or tree.size() != 3:
        return false
    for key in ["nodes", "active", "free"]:
        if not tree.get(key) is Array or tree[key].size() > 64:
            return false
    var seen: Dictionary = {}
    for id in tree.nodes:
        if not id is String or seen.has(id) or not NODES.has(id) or NODES[id].race != progression.get("race"):
            return false
        for requirement in NODES[id].requires:
            if not seen.has(requirement):
                return false
        seen[id] = true
    var active: Dictionary = {}
    for id in tree.active:
        if not id is String or active.has(id) or not id in known:
            return false
        active[id] = true
    var free: Dictionary = {}
    for id in tree.free:
        if not id is String or free.has(id) or not active.has(id):
            return false
        free[id] = true
    var points: Variant = progression.get("skill_points")
    return (points is int or points is float) and int(points) + spent(tree) == int(progression.get("level", 0))

## Tree-skill resources must exist, match their IDs and use a known effect.
static func resource_errors() -> Array:
    var errors: Array = []
    for id in SKILLS:
        var skill: Resource = load(SKILLS[id])
        if CATALOGUE.SKILLS.has(id):
            errors.append("%s: tree skill ID collides with an evidence skill" % id)
        if skill == null or String(skill.id) != id or not String(skill.effect) in CATALOGUE.EFFECTS:
            errors.append("%s: tree skill resource does not match" % id)
    for id in NODES:
        var node: Dictionary = NODES[id]
        if not RACES.valid(node.race) or (node.has("skill") and not SKILLS.has(node.skill)) or (node.has("stat") and not node.stat in STATS):
            errors.append("%s: invalid node" % id)
        for requirement in node.requires:
            if not NODES.has(requirement) or NODES[requirement].race != node.race:
                errors.append("%s: invalid prerequisite %s" % [id, requirement])
    return errors
