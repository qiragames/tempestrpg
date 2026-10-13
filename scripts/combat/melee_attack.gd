extends Node2D
const AUTHORITY := preload("res://scripts/network/authority.gd")
## A directional strike checks both range and world obstruction.

@export var damage: int = 10
@export var cooldown: float = 0.4
@export var magicule_cost: float = 8.0
var cooldown_left: float = 0.0
var flash_left: float = 0.0
var direction := Vector2.DOWN
var flash_effect: StringName = &"strike"
## Piercing thrust: a narrow line in front of the attacker that hits every creature inside it.
const PIERCE_LENGTH := 64.0
const PIERCE_WIDTH := 14.0

func _process(delta: float) -> void:
    if not AUTHORITY.can_mutate(self):
        return
    cooldown_left = maxf(0.0, cooldown_left - delta)
    flash_left = maxf(0.0, flash_left - delta)
    queue_redraw()

func attack(facing: Vector2) -> bool:
    # Mimic forms may strengthen the basic strike; skills keep their own damage.
    var bonus: int = get_parent().form_strike_bonus() if get_parent().has_method("form_strike_bonus") else 0
    return _strike(facing, damage + bonus, magicule_cost, cooldown)

func attack_skill(facing: Vector2, skill_id: StringName) -> bool:
    var skill: Resource = get_parent().get_node("SkillBook").get_skill(skill_id)
    if skill == null:
        return false
    # Effects are dispatched by stable ID; new effect types are added here deliberately.
    match skill.effect:
        &"strike":
            return _strike(facing, skill.damage, skill.magicule_cost, skill.cooldown)
        &"pierce":
            return _strike(facing, skill.damage, skill.magicule_cost, skill.cooldown, &"pierce")
        &"focus":
            return _focus(skill)
    return false

## Predator Focus arms the next analysis; it cannot stack while already armed.
func _focus(skill: Resource) -> bool:
    var absorption = get_parent().get_node("Absorption")
    if not AUTHORITY.can_mutate(self) or cooldown_left > 0.0 or absorption.focus_left > 0.0:
        return false
    if get_parent().get_node("Health").current <= 0 or get_parent().is_exhausted():
        return false
    if not get_parent().get_node("Magicules").try_spend(skill.magicule_cost):
        return false
    cooldown_left = skill.cooldown
    absorption.focus_left = absorption.FOCUS_SECONDS
    absorption.status_changed.emit("Predator Focus: your next analysis within 20s reaches twice as far and completes almost instantly.")
    return true

func _strike(facing: Vector2, strike_damage: int, cost: float, recovery: float, effect: StringName = &"strike") -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    if cooldown_left > 0.0 or get_parent().get_node("Health").current <= 0 or get_parent().is_exhausted():
        return false
    if not get_parent().get_node("Magicules").try_spend(cost):
        return false
    direction = facing.normalized()
    cooldown_left = recovery
    flash_left = 0.12
    flash_effect = effect
    var query := PhysicsShapeQueryParameters2D.new()
    if effect == &"pierce":
        var line := RectangleShape2D.new()
        line.size = Vector2(PIERCE_LENGTH, PIERCE_WIDTH)
        query.shape = line
        query.transform = Transform2D(direction.angle(), global_position + direction * (PIERCE_LENGTH / 2.0 + 4.0))
    else:
        var circle := CircleShape2D.new()
        circle.radius = 16.0
        query.shape = circle
        query.transform = Transform2D(0.0, global_position + direction * 18.0)
    query.collision_mask = 4
    var space := get_world_2d().direct_space_state
    for hit in space.intersect_shape(query):
        var target: Node2D = hit.collider
        var offset := target.global_position - global_position
        if offset.normalized().dot(direction) < 0.25:
            continue
        var sight := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
        if space.intersect_ray(sight).is_empty() and target.has_node("Health"):
            target.get_node("Health").take_damage(strike_damage, get_parent())
    return true

func _draw() -> void:
    if flash_left > 0.0 and flash_effect == &"pierce":
        draw_line(direction * 6.0, direction * (PIERCE_LENGTH + 4.0), Color("e8dcc0"), 3.0)
        draw_line(direction * 6.0, direction * (PIERCE_LENGTH + 4.0), Color("c9f6df"), 1.0)
    elif flash_left > 0.0:
        draw_arc(direction * 18.0, 16.0, direction.angle() - 1.0, direction.angle() + 1.0, 10, Color("c9f6df"), 3.0)
