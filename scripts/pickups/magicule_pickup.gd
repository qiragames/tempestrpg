extends Area2D
const AUTHORITY := preload("res://scripts/network/authority.gd")
## Collect nearby drops without losing overflow when the player's reserves are full.

signal collected(amount: float)
signal collected_by(amount: float, character_id: String)
var entity_id: String = ""
@export var amount: float = 16.0

func _ready() -> void:
    if entity_id.is_empty():
        entity_id = "drop_" + Crypto.new().generate_random_bytes(16).hex_encode()
    add_to_group("magicule_pickups")
    if not is_finite(amount) or amount <= 0.0:
        queue_free()

func _physics_process(_delta: float) -> void:
    if not AUTHORITY.can_mutate(self):
        return
    for body in get_overlapping_bodies():
        if not body.is_in_group("player") or not body.has_node("Magicules"):
            continue
        # Pickups cannot pass through walls merely because their area overlaps.
        var ray := PhysicsRayQueryParameters2D.create(global_position, body.global_position, 1)
        if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
            continue
        var pool = body.get_node("Magicules")
        var before: float = pool.current
        if pool.restore(amount):
            var gained: float = pool.current - before
            amount = maxf(0.0, amount - gained)
            collected.emit(gained)
            collected_by.emit(gained, body.character_id)
            queue_redraw()
            if amount <= 0.00001:
                # Stop immediately so another callback/frame cannot collect it twice.
                set_physics_process(false)
                queue_free()
                return

func _draw() -> void:
    draw_circle(Vector2.ZERO, 10.0, Color(0.3, 0.85, 0.8, 0.18))
    draw_rect(Rect2(-3, -6, 6, 12), Color("71e4d4"))
    draw_rect(Rect2(-6, -3, 12, 6), Color("71e4d4"))
    draw_rect(Rect2(-2, -3, 4, 6), Color("e4fff2"))
