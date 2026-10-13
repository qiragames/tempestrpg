extends Node
const AUTHORITY := preload("res://scripts/network/authority.gd")
const CATALOGUE := preload("res://scripts/skills/skill_catalogue.gd")
const TREE := preload("res://scripts/skills/skill_tree.gd")
## One character's learned skills, hotbar loadout and unlock evidence. Skills are granted only
## when the catalogue rules are met by this character's own evidence; repeats never stack.

signal learned(skill: Resource)
var _known: Dictionary = {}
const SLOT_COUNT := 4
var _slots: Array[StringName] = [&"", &"", &"", &""]
var evidence: Dictionary = CATALOGUE.empty_evidence()

## Host-side: record a completed analysis and grant whatever it unlocks. Returns new skills.
func record_analysis(specimen_id: StringName) -> Array:
    if not AUTHORITY.can_mutate(self) or not CATALOGUE.SPECIMENS.has(String(specimen_id)):
        return []
    if not String(specimen_id) in evidence.analyzed:
        evidence.analyzed.append(String(specimen_id))
    return _grant_unlocked()

## Host-side: record a personally completed trial and grant whatever it unlocks.
func record_trial(trial_id: String) -> Array:
    if not AUTHORITY.can_mutate(self) or not CATALOGUE.TRIALS.has(trial_id):
        return []
    if not trial_id in evidence.trials:
        evidence.trials.append(trial_id)
    return _grant_unlocked()

func _grant_unlocked() -> Array:
    var gained: Array = []
    for id in CATALOGUE.unlockable(known_ids(), evidence):
        var skill: Resource = load(CATALOGUE.SKILLS[id])
        # Learned, but usable only after activation in the skill tree (17c).
        _known[skill.id] = skill
        gained.append(skill)
        learned.emit(skill)
    return gained

## Tree nodes grant their skill already active, placed in the first free hotbar slot.
func grant_tree_skill(id: StringName) -> void:
    if not AUTHORITY.can_mutate(self) or not TREE.SKILLS.has(String(id)) or _known.has(id):
        return
    var skill: Resource = load(TREE.SKILLS[String(id)])
    _known[id] = skill
    auto_slot(id)
    learned.emit(skill)

func auto_slot(id: StringName) -> void:
    var empty := _slots.find(&"")
    if empty >= 0 and not _slots.has(id):
        _slots[empty] = id

## Usable (and slottable): tree skills once granted, evidence skills once activated.
func is_active(id: StringName) -> bool:
    if not _known.has(id):
        return false
    if TREE.SKILLS.has(String(id)):
        return true
    var progression: Variant = get_parent().get("progression")
    return progression is Dictionary and String(id) in progression.get("tree", {}).get("active", [])

## Skills learned from evidence (absorbing, trials); tree skills are derived from bought nodes.
func evidence_ids() -> Array:
    return known_ids().filter(func(id): return CATALOGUE.SKILLS.has(id))

## Host-side loadout change. An empty ID clears the slot; a skill already equipped elsewhere moves.
func assign_slot(index: int, id: StringName) -> bool:
    if not AUTHORITY.can_mutate(self) or index < 0 or index >= _slots.size():
        return false
    if id != &"" and not is_active(id):
        return false
    if _slots[index] == id:
        return false
    var previous := _slots.find(id) if id != &"" else -1
    if previous >= 0:
        _slots[previous] = &""
    _slots[index] = id
    return true

func knows(id: StringName) -> bool:
    return _known.has(id)

func known_ids() -> Array:
    var ids: Array = []
    for id in _known:
        ids.append(String(id))
    return ids

func get_skill(id: StringName) -> Resource:
    return _known.get(id)

func all_skills() -> Array:
    return _known.values()

func skill_at_slot(index: int) -> Resource:
    if index < 0 or index >= _slots.size():
        return null
    return get_skill(_slots[index])

## Read-only catalogue view with this character's known skills and unmet requirements.
func describe() -> Array:
    return CATALOGUE.overview(known_ids(), evidence)
