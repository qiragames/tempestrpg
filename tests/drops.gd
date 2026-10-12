extends SceneTree
## Enemy-tier reward scaling and actual proximity collection in the game world.

var checks: int = 0
var failures: int = 0
const ENEMY_SCENE := preload("res://scenes/enemies/forest_gnasher.tscn")
const PICKUP_SCENE := preload("res://scenes/pickups/magicule_pickup.tscn")

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
    world.get_node("ForestGnasher").set_physics_process(false)
    var pool = player.get_node("Magicules")
    pool.regeneration_per_second = 0.0
    player.position = Vector2(480, 340)
    await _frames(3)
    _check(get_nodes_in_group("magicule_pickups").is_empty(), "Living enemies must not spawn rewards")

    # Test independent real enemy instances across all difficulty tiers.
    for tier in range(3):
        var enemy = ENEMY_SCENE.instantiate()
        enemy.difficulty = tier
        enemy.position = Vector2(800, 340)
        world.add_child(enemy)
        enemy.set_physics_process(false)
        var health = enemy.get_node("Health")
        _check(health.maximum == [20, 30, 60][tier] and enemy.damage == [8, 12, 20][tier], "Difficulty must reflect actual combat strength")
        health.take_damage(999)
        await _frames(3)
        var pickups := get_nodes_in_group("magicule_pickups")
        _check(pickups.size() == 1, "Each defeat must create exactly one pickup")
        var drop = pickups[0]
        _check(drop.amount == [8.0, 16.0, 32.0][tier], "Harder enemies must drop more Magicules")
        _check(drop.global_position.is_equal_approx(enemy.global_position), "Drop must appear at the defeated creature")
        _check(is_instance_valid(enemy) and enemy.state == enemy.State.DEFEATED, "Dropping rewards must retain the corpse for absorption")
        enemy._defeat()
        health.take_damage(999)
        await _frames(3)
        _check(get_nodes_in_group("magicule_pickups").size() == 1, "Repeated defeat callbacks must not duplicate loot")
        drop.queue_free()
        enemy.queue_free()
        await _frames(3)

    var pickup = PICKUP_SCENE.instantiate()
    pickup.amount = 16.0
    pickup.position = Vector2(520, 340)
    pickup.collected.connect(world.announce_magicule_pickup)
    world.add_child(pickup)
    pool.try_spend(50.0)
    await _frames(5)
    _check(pool.current == 50.0 and is_instance_valid(pickup), "Distant drops must not auto-collect")
    player.position = pickup.position
    await _frames(5)
    _check(pool.current == 66.0 and not is_instance_valid(pickup), "Walking onto a drop must collect it once")
    _check(world.get_node("HUD/Magicules").text == "Magicules 66.0 / 100", "Collected loot must update the HUD")
    _check(world.get_node("HUD/SystemVoice").text.contains("Recovered 16.0"), "Collection feedback must show the actual amount")
    await _frames(10)
    _check(pool.current == 66.0, "A consumed pickup must never award a second time")

    pool.restore(999)
    pickup = PICKUP_SCENE.instantiate()
    pickup.amount = 32.0
    pickup.position = player.position
    world.add_child(pickup)
    await _frames(5)
    _check(pool.current == 100.0 and pickup.amount == 32.0, "Full reserves must leave the drop intact")
    pool.try_spend(5.0)
    await _frames(5)
    _check(pool.current == 100.0 and pickup.amount == 27.0, "Partial collection must preserve overflow")
    pool.try_spend(30.0)
    await _frames(5)
    _check(pool.current == 97.0 and not is_instance_valid(pickup), "Spending while on the drop must collect the remaining amount")

    pickup = PICKUP_SCENE.instantiate()
    pickup.amount = 8.0
    # A thin obstacle lets the pickup area overlap a player on the other side.
    world._add_obstacle(Rect2(503, 320, 2, 40))
    var thin_wall := world.get_child(world.get_child_count() - 1)
    pickup.position = Vector2(496, 340)
    world.add_child(pickup)
    player.position = Vector2(512, 340)
    await _frames(5)
    _check(is_instance_valid(pickup) and pool.current == 97.0, "Terrain must block collection even when pickup area overlaps")
    pickup.queue_free()
    thin_wall.queue_free()
    await _frames(3)

    player.position = Vector2(500, 340)
    pickup = PICKUP_SCENE.instantiate()
    pickup.amount = 8.0
    pickup.position = player.position
    world.add_child(pickup)
    player.get_node("Health").take_damage(999)
    await _frames(5)
    _check(pool.current == 97.0 and pickup.amount == 8.0, "Defeated players must not collect rewards")
    _check(world.get_node("HUD/SystemVoice").text.contains("Press R"), "Pickup feedback must not replace defeat feedback")
    var restart := InputEventAction.new()
    restart.action = "restart"
    restart.pressed = true
    Input.parse_input_event(restart)
    await _frames(5)
    _check(get_nodes_in_group("magicule_pickups").is_empty(), "Restart must clear old loot")
    _check(current_scene.get_node("Player/Magicules").current == 100.0, "Restart must restore reserves without replaying old loot")
    print("Drop checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
