extends RefCounted
## Class skills (M12c, user design): the main class teaches two skills — the first when it is
## chosen, the second at level 25. Like the skill tree's skills they follow from the character's
## state (progression.classes and level), so they are rebuilt on load and never saved as learned
## skills; changing the main class swaps them. IDs never overlap the other skill catalogues.
const CLASSES := preload("res://scripts/progression/class_catalogue.gd")
const SECOND_LEVEL := 25
## class id → [first skill, second skill (level 25)]
const BY_CLASS := {
    "warrior": ["cleave", "earthsplitter"],
    "assassin": ["shadowstep", "venom_flurry"],
    "lancer": ["piercing_charge", "skewer_line"],
    "reaper": ["soul_harvest", "deaths_whirl"],
    "archer": ["volley", "pinning_shot"],
    "mage": ["fireball", "frost_nova"],
    "monk": ["palm_strike", "hundred_fists"],
}
const SKILLS := {
    "cleave": "res://data/skills/cleave.tres",
    "earthsplitter": "res://data/skills/earthsplitter.tres",
    "shadowstep": "res://data/skills/shadowstep.tres",
    "venom_flurry": "res://data/skills/venom_flurry.tres",
    "piercing_charge": "res://data/skills/piercing_charge.tres",
    "skewer_line": "res://data/skills/skewer_line.tres",
    "soul_harvest": "res://data/skills/soul_harvest.tres",
    "deaths_whirl": "res://data/skills/deaths_whirl.tres",
    "volley": "res://data/skills/volley.tres",
    "pinning_shot": "res://data/skills/pinning_shot.tres",
    "fireball": "res://data/skills/fireball.tres",
    "frost_nova": "res://data/skills/frost_nova.tres",
    "palm_strike": "res://data/skills/palm_strike.tres",
    "hundred_fists": "res://data/skills/hundred_fists.tres",
}

## The class skills this character has (main class only; the second from level 25).
static func granted(progression: Dictionary) -> Array:
    var main: String = CLASSES.chosen(progression).main
    if not BY_CLASS.has(main):
        return []
    var skills: Array = [BY_CLASS[main][0]]
    if int(progression.get("level", 1)) >= SECOND_LEVEL:
        skills.append(BY_CLASS[main][1])
    return skills

## "Cleave, Earthsplitter (Lv 25)" for the class window.
static func skill_text(class_id: String) -> String:
    if not BY_CLASS.has(class_id):
        return ""
    var names: Array = []
    for index in range(2):
        var skill: Resource = load(SKILLS[BY_CLASS[class_id][index]])
        names.append(skill.display_name + (" (Lv %d)" % SECOND_LEVEL if index == 1 else ""))
    return ", ".join(names)
