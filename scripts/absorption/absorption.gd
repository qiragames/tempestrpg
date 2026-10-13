extends Node
const LEVELING := preload("res://scripts/progression/leveling.gd")
const AUTHORITY := preload("res://scripts/network/authority.gd")
const CATALOGUE := preload("res://scripts/skills/skill_catalogue.gd")
## Channel beside a defeated creature, analyze its traits, and learn its skill.

signal status_changed(message: String)
signal analyzed(specimen: Resource, new_skill: bool)
@export var range_pixels: float = 36.0
@export var magicule_cost: float = 12.0
@export var analysis_seconds: float = 1.2
## Predator Focus: the next analysis reaches twice as far and completes in FOCUS_ANALYSIS_SECONDS.
## It is consumed when that analysis starts, so interruption or reload never refunds it.
const FOCUS_SECONDS := 20.0
const FOCUS_ANALYSIS_SECONDS := 0.3
var focus_left: float = 0.0
## Reach of the running channel (doubled only for a focused analysis).
var _channel_reach: float = 36.0
var _target: Node2D
var time_left: float = 0.0
## Length of the running channel (race speed or focus), for progress display.
var channel_seconds: float = 1.2
var active: bool:
    get:
        return is_instance_valid(_target)

func attempt_absorb() -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    var player := get_parent() as Node2D
    if player.get_node("Health").current <= 0 or player.is_exhausted() or active:
        return false
    var focused: bool = focus_left > 0.0
    var reach: float = range_pixels * (2.0 if focused else 1.0)
    var nearest: Node2D
    var distance: float = reach + 1.0
    for candidate in get_tree().get_nodes_in_group("absorbable_creatures"):
        var candidate_distance: float = player.global_position.distance_to(candidate.global_position)
        if candidate_distance <= reach and candidate_distance < distance and _reachable(candidate):
            nearest = candidate
            distance = candidate_distance
    if nearest == null:
        status_changed.emit("No reachable defeated creature nearby.")
        return false
    if nearest.specimen == null or nearest.specimen.skill == null or not CATALOGUE.SPECIMENS.has(String(nearest.specimen.id)):
        status_changed.emit("No analyzable traits detected.")
        return false
    if not player.get_node("Inventory").can_store():
        status_changed.emit("Dimensional storage full. Discard a material first.")
        return false
    if not player.get_node("Magicules").try_spend(magicule_cost):
        status_changed.emit("Absorption requires 12 Magicules.")
        return false
    _target = nearest
    _target.remove_from_group("absorbable_creatures")
    _target.being_analyzed = true
    _target.queue_redraw()
    # Every race can absorb; Slimes are fastest (race absorb_time multiplier).
    var race: Dictionary = player.race_stats() if player.has_method("race_stats") else {"absorb_time": 1.0}
    time_left = FOCUS_ANALYSIS_SECONDS if focused else analysis_seconds * race.absorb_time
    channel_seconds = time_left
    _channel_reach = reach
    focus_left = 0.0
    status_changed.emit("%s %s. Remain nearby." % ["Focused analysis:" if focused else "Analyzing", _target.specimen.species])
    return true

func _reachable(target: Node2D) -> bool:
    var ray := PhysicsRayQueryParameters2D.create(get_parent().global_position, target.global_position, 1)
    return target.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _process(delta: float) -> void:
    if not AUTHORITY.can_mutate(self):
        return
    focus_left = maxf(0.0, focus_left - delta)
    if time_left <= 0.0:
        return
    if not active or get_parent().get_node("Health").current <= 0:
        _cancel("Analysis interrupted.")
        return
    if get_parent().global_position.distance_to(_target.global_position) > _channel_reach or not _reachable(_target):
        _cancel("Analysis interrupted. Remain beside the specimen.")
        return
    time_left = maxf(0.0, time_left - delta)
    if time_left <= 0.0:
        var specimen: Resource = _target.specimen
        if not get_parent().get_node("Inventory").add_specimen(specimen):
            _cancel("Dimensional storage full. Specimen retained.")
            return
        # Absorbed vitality: the creature's tier sets the gradual heal (replaces a weaker running heal).
        var heal: float = _target.TIER_STATS[_target.difficulty].get("absorb_heal", 0.0) if "TIER_STATS" in _target else 0.0
        if get_parent().has_method("race_stats"):
            heal *= get_parent().race_stats().absorb_heal
        if get_parent().get_node("Health").start_regen(heal):
            status_changed.emit("Absorbed vitality: +%d HP over %ds." % [int(heal), int(get_parent().get_node("Health").REGEN_SECONDS)])
        # The skill book applies the catalogue's unlock rules to this character's evidence.
        var gained: Array = get_parent().get_node("SkillBook").record_analysis(specimen.id)
        if "difficulty" in _target:
            get_parent().gain_experience(LEVELING.ABSORB_XP[_target.difficulty], "absorption")
        _target.queue_free()
        _target = null
        analyzed.emit(specimen, not gained.is_empty())
        if gained.is_empty():
            status_changed.emit("Analysis complete. %s: %s already known." % [specimen.skill.tier, specimen.skill.display_name])
        else:
            var names: Array = gained.map(func(skill): return "%s: %s" % [skill.tier, skill.display_name])
            status_changed.emit("Analysis complete. %s acquired. Activate %s in the skill tree (K)." % [", ".join(names), "it" if names.size() == 1 else "them"])

func _cancel(message: String) -> void:
    if active:
        _target.add_to_group("absorbable_creatures")
        _target.being_analyzed = false
        _target.queue_redraw()
    _target = null
    time_left = 0.0
    # Channel cost is spent even on interruption; the corpse stays available.
    status_changed.emit(message)
