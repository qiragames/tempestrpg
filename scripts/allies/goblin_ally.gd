extends CharacterBody2D
## Citizens belong to stable character IDs; disconnecting never transfers ownership.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const INTERACTION_RANGE := 40.0
@export var entity_id: String = "ally_goblin_1"
var owner_id: String = ""
var display_name: String = ""
var race: String = "Goblin"
var maximum_hp: int = 30
var power: int = 4
var follow_speed: float = 45.0

func _ready() -> void:
    add_to_group("allies")

func can_reach(actor: Node2D) -> bool:
    if actor.global_position.distance_to(global_position) > INTERACTION_RANGE:
        return false
    var ray := PhysicsRayQueryParameters2D.create(actor.global_position, global_position, 1)
    return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func threat_cleared() -> bool:
    var threat = get_parent().entity_by_id("gnasher_1")
    return threat == null or threat.get_node("Health").current <= 0

func try_recruit(actor: Node2D) -> bool:
    if not AUTHORITY.can_mutate(self) or not owner_id.is_empty() or actor.get_node("Health").current <= 0 or not can_reach(actor):
        return false
    var session := get_node("/root/GameSession")
    if not threat_cleared():
        session.notify_character(actor.character_id, "The goblin fears the clearing's Gnasher. Defeat it first.")
        return false
    owner_id = actor.character_id
    queue_redraw()
    session.notify_character(owner_id, "A nameless goblin has joined you.")
    session.queue_save()
    return true

func _physics_process(_delta: float) -> void:
    if not AUTHORITY.can_mutate(self):
        return
    velocity = Vector2.ZERO
    var owner = get_parent().player_by_id(owner_id)
    if owner != null and owner.get_node("Health").current > 0 and global_position.distance_to(owner.global_position) > 28.0:
        velocity = global_position.direction_to(owner.global_position) * follow_speed
        move_and_slide()

func _draw() -> void:
    draw_rect(Rect2(-5, -12, 10, 9), Color("759954"))
    draw_rect(Rect2(-8, -10, 3, 4), Color("759954"))
    draw_rect(Rect2(5, -10, 3, 4), Color("759954"))
    draw_rect(Rect2(-5, -3, 10, 9), Color("7d6850"))
    draw_rect(Rect2(-4, 6, 3, 4), Color("3d4538"))
    draw_rect(Rect2(1, 6, 3, 4), Color("3d4538"))
    draw_rect(Rect2(-3, -8, 2, 2), Color("172f32"))
    draw_rect(Rect2(1, -8, 2, 2), Color("172f32"))
    draw_circle(Vector2(0, 13), 2, Color("71e4d4") if not owner_id.is_empty() else Color("d7b16d"))
