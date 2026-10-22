extends Node
const AUTHORITY := preload("res://scripts/network/authority.gd")
const CATALOGUE := preload("res://scripts/skills/skill_catalogue.gd")
const TREE := preload("res://scripts/skills/skill_tree.gd")
const CLASS_SKILLS := preload("res://scripts/skills/class_skills.gd")
## One character's learned skills, hotbar loadout and unlock evidence. Skills are granted only
## when the catalogue rules are met by this character's own evidence; repeats never stack.

signal learned(skill: Resource)
var _known: Dictionary = {}
## M13b: eight hotbar slots (keys 1-8; four before v39).
const SLOT_COUNT := 8
var _slots: Array[StringName] = [&"", &"", &"", &"", &"", &"", &"", &""]
var evidence: Dictionary = CATALOGUE.empty_evidence()

## Host-side: record a completed analysis and grant whatever it unlocks. Returns new skills.
func record_analysis(specimen_id: StringName) -> Array:
    if not AUTHORITY.can_mutate(self) or not CATALOGUE.SPECIMENS.has(String(specimen_id)):
        return []
    if not String(specimen_id) in evidence.analyzed:
        evidence.analyzed.append(String(specimen_id))
    return _grant_unlocked()

## Host-side: a read skill scroll (M4.5c) teaches its skill.
func learn_from_scroll(skill_id: String) -> Array:
    if not AUTHORITY.can_mutate(self) or not CATALOGUE.scrollable(skill_id):
        return []
    if not skill_id in evidence.scrolls:
        evidence.scrolls.append(skill_id)
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
    for id in CATALOGUE.unlockable(known_ids(), evidence, CATALOGUE.RULES, true):
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

## M12c, host-side: learn the main class's skills (the second from level 25) and forget those of
## a class left behind (also from the hotbar). True when something changed.
func sync_class_skills() -> bool:
    var progression: Variant = get_parent().get("progression")
    if not AUTHORITY.can_mutate(self) or not progression is Dictionary:
        return false
    var granted: Array = CLASS_SKILLS.granted(progression)
    var changed := false
    for id in _known.keys():
        if CLASS_SKILLS.SKILLS.has(String(id)) and not String(id) in granted:
            _known.erase(id)
            var slot := _slots.find(id)
            if slot >= 0:
                _slots[slot] = &""
            changed = true
    for id in granted:
        if not _known.has(StringName(id)):
            var skill: Resource = load(CLASS_SKILLS.SKILLS[id])
            _known[StringName(id)] = skill
            auto_slot(StringName(id))
            learned.emit(skill)
            changed = true
    return changed

func auto_slot(id: StringName) -> void:
    var empty := _slots.find(&"")
    if empty >= 0 and not _slots.has(id):
        _slots[empty] = id

## Usable (and slottable): tree skills once granted, evidence skills once activated; a fused
## skill once both of its skills were activated (activations stay on the base skills).
func is_active(id: StringName) -> bool:
    if not _known.has(id):
        return false
    if TREE.SKILLS.has(String(id)) or CLASS_SKILLS.SKILLS.has(String(id)):
        return true
    var progression: Variant = get_parent().get("progression")
    if not progression is Dictionary:
        return false
    return TREE.activated(String(id), progression.get("tree", {}).get("active", []))

## Host-side fusion: both active skills are replaced by the fused skill, which takes the first's slot.
func fuse(a: StringName, b: StringName) -> String:
    if not AUTHORITY.can_mutate(self):
        return "Only the host can fuse skills."
    if not _known.has(a) or not _known.has(b) or a == b:
        return "Drag two different skills you know onto each other."
    if not is_active(a) or not is_active(b):
        return "Activate both skills in the skill tree (K) first."
    var result: String = CATALOGUE.fusion_for(String(a), String(b))
    if result.is_empty():
        return "These skills do not fuse."
    if not CATALOGUE.RULES[result].analysis in evidence.analyzed:
        return "Fusing these needs a %s analysis first." % load(CATALOGUE.SPECIMENS[CATALOGUE.RULES[result].analysis]).species
    var slot := _slots.find(a)
    if slot < 0:
        slot = _slots.find(b)
    for part in [a, b]:
        _known.erase(part)
        var index := _slots.find(part)
        if index >= 0:
            _slots[index] = &""
    var skill: Resource = load(CATALOGUE.SKILLS[result])
    _known[skill.id] = skill
    if slot >= 0:
        _slots[slot] = skill.id
    else:
        auto_slot(skill.id)
    learned.emit(skill)
    return ""

## Host-side split: a fused skill turns back into its two skills (first takes its slot).
func split(id: StringName) -> String:
    if not AUTHORITY.can_mutate(self):
        return "Only the host can split skills."
    if not _known.has(id) or not CATALOGUE.is_fused(String(id)):
        return "Only a fused skill can be split."
    var slot := _slots.find(id)
    _known.erase(id)
    if slot >= 0:
        _slots[slot] = &""
    var parts: Array = CATALOGUE.components(String(id))
    for part in parts:
        _known[StringName(part)] = load(CATALOGUE.SKILLS[part])
    if slot >= 0:
        _slots[slot] = StringName(parts[0])
    for part in parts:
        if is_active(StringName(part)):
            auto_slot(StringName(part))
    return ""

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
    # User request (sort the hotbar): moving a skill onto a taken slot swaps the two.
    if previous >= 0:
        _slots[previous] = _slots[index]
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
