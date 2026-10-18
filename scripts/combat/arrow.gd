extends Node2D
## A flying arrow (step 24a, user decision; replaces the instant bow line of 17f). It travels at
## SPEED along its direction for at most RANGE and stops at the first creature or wall it meets
## (rays against terrain and bodies, excluding the shooter). On the host the hit deals the shot's
## damage when the arrow arrives; `cosmetic` arrows (other characters' shots seen on a client)
## only fly and vanish.
const SPEED := 320.0
const RANGE := 200.0
## M12c: a staff's magic bolt (a glowing orb, a little shorter reach).
const MAGIC_RANGE := 170.0

var direction := Vector2.RIGHT
var damage: int = 0
var shooter: Node2D
var attack: Node
var cosmetic := false
var magic := false
var _travelled := 0.0
var _start := Vector2.ZERO

func _ready() -> void:
    _start = global_position
    rotation = direction.angle()
    z_index = 4

func _physics_process(delta: float) -> void:
    var reach: float = MAGIC_RANGE if magic else RANGE
    var step: float = minf(SPEED * delta, reach - _travelled)
    var from := global_position
    var to := from + direction * step
    var duels: Node = shooter.get_parent().get("duels") if is_instance_valid(shooter) and shooter.get_parent() != null else null
    var dueling: bool = duels != null and shooter.get("character_id") is String and duels.in_match(shooter.character_id)
    # M15: in a duel, arrows and bolts also fly at the opponent (players are on layer 2).
    var ray := PhysicsRayQueryParameters2D.create(from, to, 1 | 4 | (2 if dueling else 0))
    if is_instance_valid(shooter):
        ray.exclude = [shooter.get_rid()]
    var hit := get_world_2d().direct_space_state.intersect_ray(ray)
    if not hit.is_empty():
        global_position = hit.position
        if not cosmetic and dueling and hit.collider.is_in_group("player"):
            if duels.can_hit(shooter, hit.collider):
                hit.collider.get_node("Health").take_damage(damage, shooter)
        elif not cosmetic and hit.collider.has_node("Health") and hit.collider.is_in_group("enemies"):
            var before: int = hit.collider.get_node("Health").current
            var landed: bool = hit.collider.get_node("Health").take_damage(damage, shooter)
            if landed and is_instance_valid(shooter) and shooter.has_method("gear_passive") and shooter.gear_passive("lifesteal"):
                shooter.get_node("Health").heal(1)
            # Item expansion: the bow's element acts on the arrow's hit.
            if landed and is_instance_valid(attack) and attack.has_method("element_hit"):
                attack.element_hit(hit.collider, before - hit.collider.get_node("Health").current)
        _stop()
        return
    global_position = to
    _travelled += step
    if _travelled >= reach - 0.01:
        _stop()

func _stop() -> void:
    if is_instance_valid(attack) and not cosmetic:
        attack.shot_end = global_position - _start
    set_physics_process(false)
    queue_free()

func _draw() -> void:
    if magic:
        draw_circle(Vector2(-4, 0), 2.0, Color(0.55, 0.75, 1.0, 0.45))
        draw_circle(Vector2.ZERO, 3.5, Color(0.45, 0.65, 1.0, 0.55))
        draw_circle(Vector2.ZERO, 2.0, Color("e8f4ff"))
        return
    draw_line(Vector2(-7, 0), Vector2(4, 0), Color("c8a46a"), 1.0)
    draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(2, -2), Vector2(2, 2)]), Color("e8e2d0"))
    draw_line(Vector2(-7, -2), Vector2(-5, 0), Color("f4e2b8"), 1.0)
    draw_line(Vector2(-7, 2), Vector2(-5, 0), Color("f4e2b8"), 1.0)
