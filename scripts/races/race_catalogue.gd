extends RefCounted
## Playable races (step 17b). Chosen once when a character is created, stored in
## `progression.race`. Base stats apply at creation; the modifiers below apply live on the host.
## Starting numbers, tuned in step 24.
const DEFAULT := "Slime"
const ORDER := ["Slime", "Human", "Demon"]
const RACES := {
    "Slime": {
        "hp": 100, "magicules": 100.0, "move_speed": 95.0,
        "absorb_time": 1.0, "absorb_heal": 1.0, "strike_bonus": 0, "recovery": 1.0, "skill_bonus": 0.0, "drain": 0.0, "mimic_level": 1,
        "ability": "Predator body: fastest absorption, full absorbed vitality, mimic forms",
    },
    "Human": {
        "hp": 120, "magicules": 70.0, "move_speed": 95.0,
        "absorb_time": 1.5, "absorb_heal": 0.5, "strike_bonus": 4, "recovery": 0.75, "skill_bonus": 0.0, "drain": 0.0, "mimic_level": 20,
        "ability": "Weapon mastery: +4 strike damage, attacks recover 25% faster",
    },
    "Demon": {
        "hp": 90, "magicules": 130.0, "move_speed": 100.0,
        "absorb_time": 1.5, "absorb_heal": 0.5, "strike_bonus": 0, "recovery": 1.0, "skill_bonus": 0.25, "drain": 0.2, "mimic_level": 5,
        "ability": "Dark affinity: skills deal 25% more and drain 20% of their damage as HP",
    },
}

static func valid(race: Variant) -> bool:
    return race is String and RACES.has(race)

## Mimicry (user decision 2026-10-13): Slimes from the start, Demons after a few levels,
## Humans only at the endgame (the current level cap).
static func can_mimic(race: String, level: int) -> bool:
    return level >= int(stats(race).mimic_level)

static func stats(race: String) -> Dictionary:
    return RACES.get(race, RACES[DEFAULT])
