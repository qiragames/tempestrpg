extends SceneTree
## Integration checks exercise the actual main scene and physics-driven input.

var failures: int = 0
var checks: int = 0

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

func _run() -> void:
    var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
    if scene == null:
        push_error("Main scene failed to load")
        quit(1)
        return
    var world := scene.instantiate()
    root.add_child(world)
    current_scene = world
    # Foundation checks isolate movement from the separately tested enemy AI.
    world.get_node("ForestGnasher").set_physics_process(false)
    await _frames(3)
    var player := world.get_node("Player") as CharacterBody2D
    _check(player != null, "Player must be a CharacterBody2D")
    _check(player.get_node("Camera2D").is_current(), "Player camera must be active")
    _check(world.get_node("HUD/Controls").text.contains("WASD"), "Controls must be visible")
    for action in ["move_left", "move_right", "move_up", "move_down", "restart"]:
        _check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "Missing binding: " + action)

    var start := player.position
    Input.action_press("move_right")
    await _frames(30)
    _check(player.position.x > start.x + 20, "Right input must move the player")
    _check(absf(player.position.y - start.y) < 1, "Horizontal input must not change Y")
    Input.action_press("move_up")
    await _frames(10)
    _check(absf(player.velocity.length() - player.move_speed) < 0.1, "Diagonal speed must be normalized")
    Input.action_release("move_right")
    Input.action_release("move_up")
    await _frames(3)
    _check(player.velocity.is_zero_approx(), "Released input must stop movement")

    player.position = Vector2(416, 262)
    Input.action_press("move_right")
    await _frames(60)
    _check(player.position.x <= 434.1 and player.position.x > 420, "Rock collision must block movement")
    Input.action_release("move_right")

    player.position = Vector2(946, 340)
    Input.action_press("move_right")
    await _frames(30)
    _check(player.position.x <= 954.1, "World boundary must contain the player")
    Input.action_release("move_right")
    player.position = Vector2(610, 160)
    Input.action_press("move_right")
    await _frames(30)
    _check(player.position.x <= 618.1, "Water must block movement")
    Input.action_release("move_right")

    var restart_event := InputEventAction.new()
    restart_event.action = "restart"
    restart_event.pressed = true
    Input.parse_input_event(restart_event)
    await _frames(5)
    _check(current_scene != world, "Restart must reload the scene")
    _check(current_scene.get_node("Player").position.is_equal_approx(Vector2(480, 340)), "Restart must restore spawn")
    print("Smoke checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
