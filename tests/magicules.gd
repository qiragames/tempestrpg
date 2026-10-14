extends SceneTree
## Pool edge cases and real-scene spending, HUD, recovery, defeat, and restart.

var checks: int = 0
var failures: int = 0
var depletion_events: int = 0

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
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var player = world.get_node("Player")
    var enemy = world.get_node("ForestGnasher")
    enemy.set_physics_process(false)
    var pool = player.get_node("Magicules")
    var melee = player.get_node("MeleeAttack")
    pool.depleted.connect(func(): depletion_events += 1)
    await _frames(3)
    _check(pool.current == 100.0 and pool.maximum == 100.0, "Pool must initialize full")
    _check(not pool.try_spend(-1) and not pool.try_spend(0) and not pool.try_spend(NAN) and not pool.try_spend(INF), "Invalid costs must not change resources")
    _check(pool.current == 100.0, "Invalid costs must leave balance intact")
    _check(not pool.restore(-1) and not pool.restore(NAN) and not pool.restore(INF), "Invalid restoration must be rejected")

    enemy.position = player.position + Vector2(24, 0)
    await _frames(3)
    # 24b: a Slime's basic strike costs 2 Magicules and deals 12.
    _check(melee.attack(Vector2.RIGHT) and pool.current == 98.0, "A successful Slime strike must cost exactly 2 Magicules")
    _check(enemy.get_node("Health").current == 18, "Paid strike must still deal normal damage (12)")
    _check(not melee.attack(Vector2.RIGHT) and pool.current == 98.0, "Cooldown rejection must not charge Magicules")
    _check(world.get_node("HUD/Magicules").text == "Magicules 98.0 / 100" and world.get_node("HUD/MagiculeBar").value == 98.0, "HUD must reflect spending")
    pool.try_spend(6.0)
    await _frames(60)
    _check(is_equal_approx(pool.current, 92.0), "Regeneration must wait for its delay")
    await _frames(90)
    _check(absf(pool.current - 98.0) < 0.4, "Recovery must regenerate 6 Magicules per second after the delay")
    await _frames(60)
    _check(pool.current == 100.0, "Regeneration must cap at maximum")

    _check(pool.try_spend(99.0) and pool.current == 1.0, "Spending must support partial remaining reserves")
    await _frames(3)
    var before_hp: int = enemy.get_node("Health").current
    _check(not melee.attack(Vector2.RIGHT) and pool.current == 1.0, "Insufficient reserves must reject the whole strike without partial spending")
    _check(melee.cooldown_left == 0.0 and melee.flash_left == 0.0 and enemy.get_node("Health").current == before_hp, "Rejected strike must not start effects, cooldown, or damage")
    _check(world.get_node("HUD/SystemVoice").text.contains("Insufficient Magicules"), "Rejected spending must explain why the action failed")
    _check(pool.try_spend(1.0) and pool.current == 0.0 and depletion_events == 1, "Exact spending must deplete once without going negative")
    _check(not pool.try_spend(1.0) and pool.current == 0.0 and depletion_events == 1, "Empty reserves must reject further costs without duplicate depletion")
    var position_before: Vector2 = player.position
    Input.action_press("move_down")
    await _frames(15)
    Input.action_release("move_down")
    _check(player.position.y > position_before.y + 10, "Depleted player must still be able to retreat")
    await _frames(180)
    _check(pool.current >= 8.0, "Depleted pool must recover enough to act again")
    _check(melee.attack(Vector2.DOWN), "Strike must become usable again after recovery")
    _check(pool.restore(999.0) and pool.current == 100.0, "Restoration must clamp to the maximum")

    # A failed unaffordable spend must not keep postponing natural recovery.
    pool.try_spend(100.0)
    for _i in range(120):
        pool.try_spend(1000.0)
        await _frames(1)
    _check(pool.current > 2.0, "Rejected costs must not reset the regeneration delay")
    var before_defeat: float = pool.current
    player.get_node("Health").take_damage(999)
    await _frames(120)
    _check(not pool.enabled and is_equal_approx(pool.current, before_defeat), "Defeated actors must not regenerate")
    _check(not pool.try_spend(1.0) and not pool.restore(1.0), "Inactive pool must reject spending and restoration")
    _check(world.get_node("HUD/SystemVoice").text.contains("Press R"), "Resource events must not overwrite defeat feedback")
    var restart := InputEventAction.new()
    restart.action = "restart"
    restart.pressed = true
    Input.parse_input_event(restart)
    await _frames(3)
    _check(current_scene.get_node("Player/Magicules").current == 100.0 and current_scene.get_node("Player/Magicules").enabled, "Restart must restore an active full pool")
    _check(current_scene.get_node("HUD/Magicules").text == "Magicules 100.0 / 100", "Restart must restore HUD state")
    print("Magicule checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
