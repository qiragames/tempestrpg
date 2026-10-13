extends RefCounted
## Experience and levels (step 17). Host-only awards to the character who earned them; each level,
## level 1 included, grants one skill point (spent in the skill tree, step 17c). Starting numbers, tuned in step 24.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const LEVEL_CAP := 20
## XP by creature tier [Easy, Standard, Elite]: the defeating blow, and a completed absorption.
const DEFEAT_XP := [10, 20, 40]
const ABSORB_XP := [5, 10, 20]
const TRIAL_XP := 60

## Total experience needed to reach a level: 50, 150, 300, 500, ... (25 · L · (L − 1)).
static func xp_for_level(level: int) -> int:
    return 25 * level * (level - 1)

static func max_experience() -> int:
    return xp_for_level(LEVEL_CAP)

static func level_for(experience: int) -> int:
    var level := 1
    while level < LEVEL_CAP and experience >= xp_for_level(level + 1):
        level += 1
    return level

## Level, experience and skill points must agree with the curve; unspent points never exceed the
## level (one per level). The skill tree checks the exact total with its spent points.
static func valid(progression: Dictionary) -> bool:
    var experience = progression.get("experience")
    var points = progression.get("skill_points")
    if not (experience is int or experience is float) or experience != floor(experience) or experience < 0 or experience > max_experience():
        return false
    if not (points is int or points is float) or points != floor(points) or points < 0:
        return false
    return progression.get("level") == level_for(int(experience)) and points <= progression.level

## Award experience on the host. Returns the number of levels gained.
static func grant(actor: Node, amount: int) -> int:
    if amount <= 0 or not AUTHORITY.can_mutate(actor):
        return 0
    var progression: Dictionary = actor.progression
    var before: int = int(progression.level)
    progression["experience"] = mini(max_experience(), int(progression.experience) + amount)
    progression["level"] = level_for(progression.experience)
    var gained: int = int(progression.level) - before
    progression["skill_points"] = int(progression.get("skill_points", 0)) + gained
    return gained
