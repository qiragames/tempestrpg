extends Node2D
## A flying arrow (step 24a, user decision; replaces the instant bow line of 17f). It travels at
## SPEED along its direction for at most RANGE and stops at the first creature or wall it meets
## (rays against terrain and bodies, excluding the shooter). On the host the hit deals the shot's
## damage when the arrow arrives; `cosmetic` arrows (other characters' shots seen on a client)
## only fly and vanish.
const SPEED := 320.0
const RANGE := 200.0

var direction := Vector2.RIGHT
var damage: int = 0
var shooter: Node2D
var attack: Node
var cosmetic := false
var _travelled := 0.0
var _start := Vector2.ZERO

func _ready() -> void:
    _start = global_position
    rotation = direction.angle()
    z_index = 4

func _physics_process(delta: float) -> void:
    var step: float = minf(SPEED * delta, RANGE - _travelled)
    var from := global_position
    var to := from + direction * step
    var ray := PhysicsRayQueryParameters2D.create(from, to, 1 | 4)
    if is_instance_valid(shooter):
        ray.exclude = [shooter.get_rid()]
    var hit := get_world_2d().direct_space_state.intersect_ray(ray)
    if not hit.is_empty():
        global_position = hit.position
        if not cosmetic and hit.collider.has_node("Health") and hit.collider.is_in_group("enemies"):
            if hit.collider.get_node("Health").take_damage(damage, shooter) and is_instance_valid(shooter) and shooter.has_method("gear_passive") and shooter.gear_passive("lifesteal"):
                shooter.get_node("Health").heal(1)
        _stop()
        return
    global_position = to
    _travelled += step
    if _travelled >= RANGE - 0.01:
        _stop()

func _stop() -> void:
    if is_instance_valid(attack) and not cosmetic:
        attack.shot_end = global_position - _start
    set_physics_process(false)
    queue_free()

func _draw() -> void:
    draw_line(Vector2(-7, 0), Vector2(4, 0), Color("c8a46a"), 1.0)
    draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(2, -2), Vector2(2, 2)]), Color("e8e2d0"))
    draw_line(Vector2(-7, -2), Vector2(-5, 0), Color("f4e2b8"), 1.0)
    draw_line(Vector2(-7, 2), Vector2(-5, 0), Color("f4e2b8"), 1.0)
