extends CharacterBody2D
@onready var session: Node = get_node("/root/GameSession")
## Movement delegates health and attacks to reusable combat components.

@export var move_speed: float = 95.0
var facing := Vector2.DOWN
var character_id: String = "host"
var local_controlled: bool = true
var network_controlled: bool = false
var input_blocked: bool = false
var exhaustion_active: bool = false
var exhaustion_left: float = 0.0
var remote_direction := Vector2.ZERO
var last_input_msec: int = 0
var progression: Dictionary = {"level": 1, "experience": 0, "race": "Slime", "quests": {}, "equipment": {}}

func _ready() -> void:
    $Camera2D.enabled = local_controlled
    $Health.defeated.connect(func(): $Magicules.enabled = false)

func _physics_process(_delta: float) -> void:
    var direction := Vector2.ZERO
    if local_controlled and not input_blocked:
        direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    elif network_controlled and not input_blocked and Time.get_ticks_msec() - last_input_msec < 350:
        direction = remote_direction
    if is_exhausted():
        direction = Vector2.ZERO
    if session.replica_world:
        if local_controlled:
            session.send_move(direction)
        return
    if $Health.current <= 0 or is_exhausted():
        velocity = Vector2.ZERO
        return
    velocity = direction * move_speed
    if not direction.is_zero_approx():
        facing = direction
    move_and_slide()
    queue_redraw()

func is_exhausted() -> bool:
    return exhaustion_active

func begin_exhaustion(seconds: float) -> void:
    if session.replica_world:
        return
    if $Absorption.active:
        $Absorption._cancel("Analysis interrupted by exhaustion.")
    exhaustion_active = true
    exhaustion_left = maxf(exhaustion_left, seconds)
    velocity = Vector2.ZERO
    remote_direction = Vector2.ZERO
    queue_redraw()

func _process(delta: float) -> void:
    if session.replica_world or not exhaustion_active or $Health.current <= 0:
        return
    exhaustion_left = maxf(0.0, exhaustion_left - delta)
    if exhaustion_left <= 0.0 and $Magicules.current >= $Magicules.maximum * 0.25:
        exhaustion_active = false
        session.notify_character(character_id, "Aura stabilized. Recovery complete.")
        session.queue_save()
        queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if not local_controlled or input_blocked:
        return
    if session.active:
        if event.is_action_pressed("restart") and not event.is_echo():
            session.request_action("respawn")
        for action in ["attack", "absorb", "skill_1", "skill_2", "skill_3"]:
            if event.is_action_pressed(action) and not event.is_echo():
                session.request_action(action)
        return
    if event.is_action_pressed("attack") and not event.is_echo():
        $MeleeAttack.attack(facing)
    elif event.is_action_pressed("absorb") and not event.is_echo():
        $Absorption.attempt_absorb()
    elif not event.is_echo():
        for index in range(3):
            if event.is_action_pressed("skill_%d" % (index + 1)):
                var skill: Resource = $SkillBook.skill_at_slot(index)
                if skill != null:
                    $MeleeAttack.attack_skill(facing, skill.id)

func configure_replica() -> void:
    for component in [$Health, $Magicules, $MeleeAttack, $Absorption]:
        component.set_process(false)

func _draw() -> void:
    if has_node("Health") and $Health.current <= 0:
        draw_rect(Rect2(-8, 2, 16, 4), Color("447c88"))
        return
    if exhaustion_active:
        draw_rect(Rect2(-9, 0, 18, 6), Color("477f91"))
        draw_rect(Rect2(-5, -2, 10, 3), Color("78a6b4"))
        draw_rect(Rect2(-4, 2, 3, 1), Color("142c42"))
        draw_rect(Rect2(1, 2, 3, 1), Color("142c42"))
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
