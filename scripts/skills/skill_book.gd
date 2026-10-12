extends Node
## Learned skills are keyed by stable IDs; absorbing duplicates cannot stack power.

signal learned(skill: Resource)
var _known: Dictionary = {}

func learn(skill: Resource) -> bool:
    if skill == null or skill.id == &"" or _known.has(skill.id):
        return false
    _known[skill.id] = skill
    learned.emit(skill)
    return true

func knows(id: StringName) -> bool:
    return _known.has(id)

func get_skill(id: StringName) -> Resource:
    return _known.get(id)

func all_skills() -> Array:
    return _known.values()
