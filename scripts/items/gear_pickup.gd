extends Area2D
## Gear lying on the ground (17g). The first character to walk over it takes it, if their bag has
## room; otherwise it stays. Host only; saved as world loot.
## SVE feedback: fresh loot pops out of the creature or chest in a little arc and then lies there
## bobbing with its icon; walking over it or pressing F within REACH takes it.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
## F picks loot up from this far (walking over it takes it anyway).
const REACH := 48.0
const POP_SECONDS := 0.55
## Loot made this soon after the world appeared was loaded, not dropped: it does not pop.
const QUIET_MSEC := 3000

var entity_id: String = ""
var item: Dictionary = {}
## 24a: loot handed out by damage rank belongs to its character for a while (see Claim).
var owner_id: String = ""
var claim_until: float = 0.0
const CLAIM := preload("res://scripts/pickups/claim.gd")
var _full_notified: Dictionary = {}
## Visual only: where the pop starts relative to the resting spot, and its progress (1 = landed).
var pop_from: Vector2 = Vector2.ZERO
var _pop: float = 1.0
var _age: float = 0.0
var _icon: Texture2D

func _ready() -> void:
    if entity_id.is_empty():
        entity_id = "loot_" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_to_group("gear_pickups")
    if not GEAR.valid_item(item):
        queue_free()
        return
    _icon = UI.gear_icon(item)
    var parent := get_parent()
    var born: int = int(parent.get_meta("born_msec", 0)) if parent != null else 0
    if Time.get_ticks_msec() - born > QUIET_MSEC:
        if pop_from == Vector2.ZERO:
            pop_from = Vector2.from_angle(randf() * TAU) * 12.0
        _pop = 0.0
    _age = randf() * 3.0

func _process(delta: float) -> void:
    _age += delta
    if _pop < 1.0:
        _pop = minf(1.0, _pop + delta / POP_SECONDS)
    queue_redraw()

func _physics_process(_delta: float) -> void:
    if not AUTHORITY.can_mutate(self) or _pop < 1.0:
        return
    for body in get_overlapping_bodies():
        if try_give(body, false):
            return

## Host: give the item to `body` if it may take it (claim, line of sight, alive); true when taken.
func try_give(body: Node, from_reach: bool) -> bool:
    if not body.is_in_group("player") or not body.has_method("add_item") or body.get_node("Health").current <= 0:
        return false
    if from_reach and body.global_position.distance_to(global_position) > REACH:
        return false
    if not CLAIM.can_take(get_parent(), owner_id, claim_until, body.character_id):
        if from_reach:
            get_node("/root/GameSession").notify_character(body.character_id, "That loot belongs to someone else for now.")
        return false
    var ray := PhysicsRayQueryParameters2D.create(global_position, body.global_position, 1)
    if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
        return false
    var session := get_node("/root/GameSession")
    if body.add_item(item):
        session.notify_character(body.character_id, "Picked up %s." % GEAR.display_name(item))
        set_physics_process(false)
        queue_free()
        session.queue_save()
        return true
    if from_reach or not _full_notified.has(body.character_id):
        _full_notified[body.character_id] = true
        session.notify_character(body.character_id, "Gear bag full (%d items)." % GEAR.MAX_ITEMS)
    return false

func _draw() -> void:
    var color := Color(GEAR.RARITY_COLORS[int(item.get("rarity", 0))])
    # The arc: from pop_from up and over to the resting spot, with a small bounce at the end.
    var t := _pop
    var offset := pop_from * (1.0 - t) + Vector2(0, -sin(t * PI) * 18.0)
    if t >= 1.0:
        offset = Vector2(0, -2.0 - sin(_age * 3.0) * 1.5)
    var shadow := 0.6 + 0.4 * (1.0 - absf(offset.y) / 20.0)
    draw_set_transform(Vector2(0, 3))
    draw_circle(Vector2.ZERO, 6.0 * shadow, Color(0, 0, 0, 0.28))
    draw_set_transform(Vector2.ZERO)
    draw_circle(offset, 9.0, Color(color, 0.22 + 0.08 * sin(_age * 4.0)))
    if _icon != null:
        draw_texture_rect(_icon, Rect2(offset - Vector2(8, 8), Vector2(16, 16)), false)
        return
    draw_rect(Rect2(offset + Vector2(-5, -4), Vector2(10, 8)), Color("6b4e2e"))
    draw_rect(Rect2(offset + Vector2(-5, -4), Vector2(10, 2)), color)
    draw_rect(Rect2(offset + Vector2(-1, -2), Vector2(2, 3)), color.lightened(0.4))
