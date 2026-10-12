extends Node
const AUTHORITY := preload("res://scripts/network/authority.gd")
## Channel beside a defeated creature, analyze its traits, and learn its skill.

signal status_changed(message: String)
signal analyzed(specimen: Resource, new_skill: bool)
@export var range_pixels: float = 36.0
@export var magicule_cost: float = 12.0
@export var analysis_seconds: float = 1.2
var _target: Node2D
var time_left: float = 0.0
var active: bool:
    get:
        return is_instance_valid(_target)

func attempt_absorb() -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    var player := get_parent() as Node2D
    if player.get_node("Health").current <= 0 or player.is_exhausted() or active:
        return false
    var nearest: Node2D
    var distance: float = range_pixels + 1.0
    for candidate in get_tree().get_nodes_in_group("absorbable_creatures"):
        var candidate_distance: float = player.global_position.distance_to(candidate.global_position)
        if candidate_distance <= range_pixels and candidate_distance < distance and _reachable(candidate):
            nearest = candidate
            distance = candidate_distance
    if nearest == null:
        status_changed.emit("No reachable defeated creature nearby.")
        return false
    if nearest.specimen == null or nearest.specimen.skill == null:
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
    time_left = analysis_seconds
    status_changed.emit("Analyzing %s. Remain nearby." % _target.specimen.species)
    return true

func _reachable(target: Node2D) -> bool:
    var ray := PhysicsRayQueryParameters2D.create(get_parent().global_position, target.global_position, 1)
    return target.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _process(delta: float) -> void:
    if not AUTHORITY.can_mutate(self):
        return
    if time_left <= 0.0:
        return
    if not active or get_parent().get_node("Health").current <= 0:
        _cancel("Analysis interrupted.")
        return
    if get_parent().global_position.distance_to(_target.global_position) > range_pixels or not _reachable(_target):
        _cancel("Analysis interrupted. Remain beside the specimen.")
        return
    time_left = maxf(0.0, time_left - delta)
    if time_left <= 0.0:
        var specimen: Resource = _target.specimen
        if not get_parent().get_node("Inventory").add_specimen(specimen):
            _cancel("Dimensional storage full. Specimen retained.")
            return
        var new_skill: bool = get_parent().get_node("SkillBook").learn(specimen.skill)
        _target.queue_free()
        _target = null
        analyzed.emit(specimen, new_skill)
        status_changed.emit("Analysis complete. %s: %s %s." % [specimen.skill.tier, specimen.skill.display_name, "acquired" if new_skill else "already known"])

func _cancel(message: String) -> void:
    if active:
        _target.add_to_group("absorbable_creatures")
        _target.being_analyzed = false
        _target.queue_redraw()
    _target = null
    time_left = 0.0
    # Channel cost is spent even on interruption; the corpse stays available.
    status_changed.emit(message)
