extends SceneTree
## Real-scene checks for the combat contract and its failure cases.

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)

func _frames(count: int) -> void:
    for _i in range(count):
        await physics_frame
        await process_frame

func _attack_input() -> void:
    var event := InputEventAction.new()
    event.action = "attack"
    event.pressed = true
    Input.parse_input_event(event)
    var release := InputEventAction.new()
    release.action = "attack"
    release.pressed = false
    Input.parse_input_event(release)

func _run() -> void:
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var player = world.get_node("Player")
    var enemy = world.get_node("ForestGnasher")
    var health = player.get_node("Health")
    var enemy_health = enemy.get_node("Health")
    var melee = player.get_node("MeleeAttack")
    _check(InputMap.has_action("attack") and InputMap.action_get_events("attack").size() == 2, "Strike must have Space and J bindings")
    _check(health.current == 100 and enemy_health.current == 30, "Actors must initialize with their configured health")
    _check(not health.take_damage(-10) and not health.take_damage(0) and health.current == 100, "Invalid damage must not heal or injure actors")

    enemy.position = Vector2(850, 340)
    enemy.home = enemy.position
    await _frames(10)
    _check(enemy.state == enemy.State.IDLE, "Enemy outside detection range must remain idle")
    enemy.position = player.position + Vector2(80, 0)
    enemy.home = enemy.position
    await _frames(15)
    _check(enemy.position.x < player.position.x + 75 and enemy.state == enemy.State.CHASE, "Detected enemy must chase the player")
    enemy.position = player.position + Vector2(20, 0)
    await _frames(3)
    _check(enemy.state == enemy.State.WINDUP and health.current == 100, "A bite must telegraph before dealing damage")
    player.position += Vector2(-70, 0)
    await _frames(24)
    _check(health.current == 100, "Dodging outside bite range must avoid damage")
    await _frames(60)
    player.position = enemy.position - Vector2(20, 0)
    await _frames(30)
    _check(health.current == 88, "An in-range bite must deal exactly 12 damage")
    _check(world.get_node("HUD/Health").text == "HP 88 / 100", "HUD must follow actual player health")
    _check(not health.take_damage(12) and health.current == 88, "Damage immunity must prevent rapid repeated hits")
    enemy.set_physics_process(false)
    await _frames(42)
    _check(health.take_damage(1) and health.current == 87, "Damage must resume after immunity expires")

    player.position = Vector2(500, 340)
    enemy.position = Vector2(524, 340)
    player.facing = Vector2.RIGHT
    await _frames(3)
    _attack_input()
    await _frames(1)
    _check(enemy_health.current == 20, "Attack input must damage an enemy in the facing strike area")
    _check(not melee.attack(Vector2.RIGHT) and enemy_health.current == 20, "Cooldown must reject repeated immediate strikes")
    await _frames(26)
    melee.attack(Vector2.LEFT)
    _check(enemy_health.current == 20, "A strike facing away must miss")
    await _frames(26)
    enemy.position = Vector2(580, 340)
    await _frames(3)
    melee.attack(Vector2.RIGHT)
    _check(enemy_health.current == 20, "An out-of-range enemy must not take damage")
    await _frames(26)
    player.position = Vector2(434, 262)
    enemy.position = Vector2(474, 262)
    await _frames(3)
    melee.attack(Vector2.RIGHT)
    _check(enemy_health.current == 20, "A rock between actors must block a strike")
    await _frames(26)

    player.position = Vector2(500, 340)
    enemy.position = Vector2(524, 340)
    await _frames(3)
    melee.attack(Vector2.RIGHT)
    await _frames(26)
    melee.attack(Vector2.RIGHT)
    await _frames(3)
    _check(enemy_health.current == 0 and enemy.state == enemy.State.DEFEATED, "Lethal strikes must defeat the enemy")
    _check(enemy.get_node("CollisionShape2D").disabled, "A defeated enemy must release its collision")
    _check(is_instance_valid(enemy) and world.get_node("HUD/SystemVoice").text.contains("Specimen retained"), "Defeated creature must remain for future absorption")
    var post_defeat_hp: int = health.current
    enemy.set_physics_process(true)
    await _frames(60)
    _check(health.current == post_defeat_hp, "Defeated enemies must not attack")
    _check(not enemy_health.take_damage(10), "Already defeated actors must reject further damage")

    health.take_damage(999)
    await _frames(2)
    _check(health.current == 0 and world.get_node("HUD/SystemVoice").text.contains("Press R"), "Player defeat must show retry feedback")
    var defeated_position: Vector2 = player.position
    Input.action_press("move_right")
    await _frames(10)
    Input.action_release("move_right")
    _check(player.position.is_equal_approx(defeated_position) and not melee.attack(Vector2.RIGHT), "Defeated player cannot move or attack")

    var restart := InputEventAction.new()
    restart.action = "restart"
    restart.pressed = true
    Input.parse_input_event(restart)
    await _frames(3)
    _check(current_scene.get_node("Player/Health").current == 100 and current_scene.get_node("ForestGnasher/Health").current == 30, "Restart must restore both actors")
    print("Combat checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
