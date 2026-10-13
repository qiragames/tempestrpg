extends Area2D
## Gear lying on the ground (17g). The first character to walk over it takes it, if their bag has
## room; otherwise it stays. Host only; saved as world loot.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")

var entity_id: String = ""
var item: Dictionary = {}
var _full_notified: Dictionary = {}

func _ready() -> void:
    if entity_id.is_empty():
        entity_id = "loot_" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_to_group("gear_pickups")
    if not GEAR.valid_item(item):
        queue_free()

func _physics_process(_delta: float) -> void:
    if not AUTHORITY.can_mutate(self):
        return
    for body in get_overlapping_bodies():
        if not body.is_in_group("player") or not body.has_method("add_item") or body.get_node("Health").current <= 0:
            continue
        var ray := PhysicsRayQueryParameters2D.create(global_position, body.global_position, 1)
        if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
            continue
        var session := get_node("/root/GameSession")
        if body.add_item(item):
            session.notify_character(body.character_id, "Picked up %s." % GEAR.display_name(item))
            set_physics_process(false)
            queue_free()
            session.queue_save()
            return
        if not _full_notified.has(body.character_id):
            _full_notified[body.character_id] = true
            session.notify_character(body.character_id, "Gear bag full (%d items)." % GEAR.MAX_ITEMS)

func _draw() -> void:
    var color := Color(GEAR.RARITY_COLORS[int(item.get("rarity", 0))])
    draw_circle(Vector2.ZERO, 9.0, Color(color, 0.22))
    draw_rect(Rect2(-5, -4, 10, 8), Color("6b4e2e"))
    draw_rect(Rect2(-5, -4, 10, 2), color)
    draw_rect(Rect2(-1, -2, 2, 3), color.lightened(0.4))
