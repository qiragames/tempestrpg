extends Node2D
## A directional strike checks both range and world obstruction.

@export var damage: int = 10
@export var cooldown: float = 0.4
@export var magicule_cost: float = 8.0
var cooldown_left: float = 0.0
var flash_left: float = 0.0
var direction := Vector2.DOWN

func _process(delta: float) -> void:
    cooldown_left = maxf(0.0, cooldown_left - delta)
    flash_left = maxf(0.0, flash_left - delta)
    queue_redraw()

func attack(facing: Vector2) -> bool:
    if cooldown_left > 0.0 or get_parent().get_node("Health").current <= 0:
        return false
    if not get_parent().get_node("Magicules").try_spend(magicule_cost):
        return false
    direction = facing.normalized()
    cooldown_left = cooldown
    flash_left = 0.12
    var circle := CircleShape2D.new()
    circle.radius = 16.0
    var query := PhysicsShapeQueryParameters2D.new()
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
            target.get_node("Health").take_damage(damage)
    return true

func _draw() -> void:
    if flash_left > 0.0:
        draw_arc(direction * 18.0, 16.0, direction.angle() - 1.0, direction.angle() + 1.0, 10, Color("c9f6df"), 3.0)
