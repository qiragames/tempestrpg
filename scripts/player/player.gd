extends CharacterBody2D
## Movement delegates health and attacks to reusable combat components.

@export var move_speed: float = 95.0
var facing := Vector2.DOWN

func _ready() -> void:
    $Health.defeated.connect(func(): $Magicules.enabled = false)

func _physics_process(_delta: float) -> void:
    if $Health.current <= 0:
        velocity = Vector2.ZERO
        return
    var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = direction * move_speed
    if not direction.is_zero_approx():
        facing = direction
    move_and_slide()
    queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("attack") and not event.is_echo():
        $MeleeAttack.attack(facing)
    elif event.is_action_pressed("absorb") and not event.is_echo():
        $Absorption.attempt_absorb()

func _draw() -> void:
    if has_node("Health") and $Health.current <= 0:
        draw_rect(Rect2(-8, 2, 16, 4), Color("447c88"))
        return
    # Deliberately simple pixel placeholder, ready to replace with animated sprites.
    draw_rect(Rect2(-9, 3, 18, 5), Color(0.03, 0.12, 0.14, 0.5))
    draw_rect(Rect2(-7, -5, 14, 11), Color("359caf"))
    draw_rect(Rect2(-5, -8, 10, 3), Color("73d7d5"))
    draw_rect(Rect2(-9, -2, 2, 6), Color("359caf"))
    draw_rect(Rect2(7, -2, 2, 6), Color("359caf"))
    draw_rect(Rect2(-5, -4, 3, 2), Color("baf3e4"))
    var eye_offset := facing * 1.5
    draw_rect(Rect2(Vector2(-4, -1) + eye_offset, Vector2(2, 3)), Color("142c42"))
    draw_rect(Rect2(Vector2(2, -1) + eye_offset, Vector2(2, 3)), Color("142c42"))
