extends CharacterBody2D
## Simple local encounter AI. Navigation around complex terrain comes later.

enum State { IDLE, CHASE, WINDUP, RECOVER, DEFEATED }
@export var speed: float = 55.0
@export var detection_radius: float = 180.0
@export var leash_radius: float = 220.0
@export var attack_range: float = 24.0
@export var damage: int = 12
var state: State = State.IDLE
var state_time: float = 0.0
var home: Vector2
@onready var health = $Health
@onready var target: CharacterBody2D = get_tree().get_first_node_in_group("player")

func _ready() -> void:
    home = global_position
    health.changed.connect(func(_current: int, _maximum: int): queue_redraw())
    health.defeated.connect(_defeat)

func _physics_process(delta: float) -> void:
    velocity = Vector2.ZERO
    state_time = maxf(0.0, state_time - delta)
    if state == State.DEFEATED or not is_instance_valid(target):
        return
    var distance := global_position.distance_to(target.global_position)
    var target_alive: bool = target.get_node("Health").current > 0
    var nearby: bool = distance <= detection_radius and target.global_position.distance_to(home) <= leash_radius
    match state:
        State.IDLE:
            if nearby and target_alive:
                state = State.CHASE
            elif global_position.distance_to(home) > 3.0:
                velocity = global_position.direction_to(home) * speed
        State.CHASE:
            if not nearby or not target_alive:
                state = State.IDLE
            elif distance <= attack_range:
                state = State.WINDUP
                state_time = 0.35
            else:
                velocity = global_position.direction_to(target.global_position) * speed
        State.WINDUP:
            if state_time <= 0.0:
                var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
                if target_alive and distance <= attack_range and get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
                    target.get_node("Health").take_damage(damage)
                state = State.RECOVER
                state_time = 0.9
        State.RECOVER:
            if state_time <= 0.0:
                state = State.IDLE
    move_and_slide()
    queue_redraw()

func _defeat() -> void:
    state = State.DEFEATED
    velocity = Vector2.ZERO
    $CollisionShape2D.set_deferred("disabled", true)
    # Retain the defeated creature for the next absorption milestone.
    queue_redraw()

func _draw() -> void:
    if state == State.DEFEATED:
        draw_rect(Rect2(-10, 0, 20, 5), Color("656653"))
        return
    var color := Color("d7b16d") if state != State.WINDUP else Color("f08065")
    draw_rect(Rect2(-9, -8, 18, 14), color)
    draw_rect(Rect2(-11, -12, 5, 8), color)
    draw_rect(Rect2(6, -12, 5, 8), color)
    draw_rect(Rect2(-6, -4, 3, 3), Color("352d36"))
    draw_rect(Rect2(3, -4, 3, 3), Color("352d36"))
    draw_rect(Rect2(-4, 2, 8, 3), Color("f4edca"))
    if is_instance_valid(health):
        draw_rect(Rect2(-12, -19, 24, 3), Color("352d36"))
        draw_rect(Rect2(-12, -19, 24.0 * health.current / health.maximum, 3), Color("c6d58a"))
