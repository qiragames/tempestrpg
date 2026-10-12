extends Node
const AUTHORITY := preload("res://scripts/network/authority.gd")
## Learned skills are keyed by stable IDs; absorbing duplicates cannot stack power.

signal learned(skill: Resource)
var _known: Dictionary = {}
var _slots: Array[StringName] = [&"", &"", &""]

func learn(skill: Resource) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    if skill == null or skill.id == &"" or _known.has(skill.id):
        return false
    _known[skill.id] = skill
    var empty := _slots.find(&"")
    if empty >= 0:
        _slots[empty] = skill.id
    learned.emit(skill)
    return true

func knows(id: StringName) -> bool:
    return _known.has(id)

func get_skill(id: StringName) -> Resource:
    return _known.get(id)

func all_skills() -> Array:
    return _known.values()

func skill_at_slot(index: int) -> Resource:
    if index < 0 or index >= _slots.size():
        return null
    return get_skill(_slots[index])
