extends SceneTree
const CODEC := preload("res://scripts/persistence/state_codec.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var actor = world.get_local_player()
    var health = actor.get_node("Health")
    health.current = 10
    health.start_regen(25)
    health._process(0.3)
    var state: Dictionary = CODEC.capture_player(actor)
    var restored = load("res://scenes/player/player.tscn").instantiate()
    restored.local_controlled = false
    world.add_child(restored)
    CODEC.apply_player(restored, state, world, false)
    health._process(health.regen_left)
    var restored_health = restored.get_node("Health")
    restored_health._process(restored_health.regen_left)
    print("Uninterrupted heal HP: ", health.current, "; reloaded heal HP: ", restored_health.current)
    health.current = 10
    health.clear_regen()
    health.start_regen(25)
    for _i in range(601): health._process(1.0/60.0)
    print("25-HP heal after fixed frames, start HP10: ", health.current)
    quit(0 if health.current == 35 else 1)
