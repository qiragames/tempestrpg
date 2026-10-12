extends SceneTree
## Exercise acquisition through the real corpse/channel flow, not direct skill injection.

var checks: int = 0
var failures: int = 0
const ENEMY_SCENE := preload("res://scenes/enemies/forest_gnasher.tscn")

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

func _input(action: StringName) -> void:
    var event := InputEventAction.new()
    event.action = action
    event.pressed = true
    Input.parse_input_event(event)
    event = InputEventAction.new()
    event.action = action
    event.pressed = false
    Input.parse_input_event(event)

func _run() -> void:
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var player = world.get_node("Player")
    var enemy = world.get_node("ForestGnasher")
    enemy.set_physics_process(false)
    var pool = player.get_node("Magicules")
    pool.regeneration_per_second = 0.0
    var book = player.get_node("SkillBook")
    var absorption = player.get_node("Absorption")
    enemy.position = Vector2(520, 340)
    player.position = Vector2(490, 340)
    await _frames(3)
    _check(InputMap.has_action("absorb") and not InputMap.action_get_events("absorb").is_empty(), "Absorption must have an input binding")
    _check(book.all_skills().is_empty() and not book.knows(&"rending_bite"), "Player must start without acquired skills")
    _check(not absorption.attempt_absorb() and pool.current == 100.0, "Living creatures must not be absorbed or charge resources")
    enemy.get_node("Health").take_damage(999)
    await _frames(3)
    _check(enemy.is_in_group("absorbable_creatures"), "Defeat must make a creature available for absorption")
    player.position = Vector2(440, 340)
    _check(not absorption.attempt_absorb() and pool.current == 100.0, "Distant corpses must not be absorbed")
    player.position = Vector2(490, 340)
    world._add_obstacle(Rect2(503, 320, 2, 40))
    var wall := world.get_child(world.get_child_count() - 1)
    await _frames(3)
    _check(not absorption.attempt_absorb(), "Absorption must not pass through terrain")
    wall.queue_free()
    await _frames(3)
    pool.try_spend(95.0)
    _check(not absorption.attempt_absorb() and pool.current == 5.0 and is_instance_valid(enemy), "Unaffordable absorption must preserve the corpse and reserves")
    pool.restore(999)
    _input(&"absorb")
    await _frames(2)
    _check(absorption.active and pool.current == 88.0, "Absorb input must begin analysis and spend exactly 12 Magicules")
    _check(not enemy.is_in_group("absorbable_creatures") and enemy.being_analyzed, "Channel must reserve its specimen")
    _check(not absorption.attempt_absorb() and pool.current == 88.0, "Repeated activation must not charge twice")
    await _frames(30)
    _check(not book.knows(&"rending_bite") and world.get_node("HUD/AnalysisProgress").visible, "Skill must wait for completed analysis; progress must be visible")
    player.position = Vector2(440, 340)
    await _frames(3)
    _check(not absorption.active and enemy.is_in_group("absorbable_creatures") and not enemy.being_analyzed, "Leaving the corpse must cancel and release the specimen")
    _check(pool.current == 88.0 and not book.knows(&"rending_bite"), "Interrupted analysis spends its cost but grants no skill")

    player.position = Vector2(490, 340)
    _check(absorption.attempt_absorb(), "An interrupted corpse must remain usable")
    await _frames(75)
    _check(not is_instance_valid(enemy) and not absorption.active, "Completed absorption must consume the corpse once")
    _check(book.knows(&"rending_bite") and book.all_skills().size() == 1, "Analysis must acquire exactly one skill")
    var skill: Resource = book.get_skill(&"rending_bite")
    _check(skill.tier == "Common" and skill.display_name == "Rending Bite", "Acquired trait must match the creature's Common Skill data")
    _check(world.get_node("HUD/Analysis").text.contains("Common") and world.get_node("HUD/Analysis").text.contains("acquired"), "HUD must announce actual acquisition")
    _check(not absorption.attempt_absorb(), "Consumed corpses must not be reused")
    _check(book.get_skill(&"missing") == null, "Unknown skill lookup must return nothing")

    enemy = ENEMY_SCENE.instantiate()
    enemy.position = Vector2(520, 340)
    world.add_child(enemy)
    enemy.set_physics_process(false)
    enemy.get_node("Health").take_damage(999)
    await _frames(3)
    _check(absorption.attempt_absorb(), "A second defeated specimen must still be analyzable")
    await _frames(75)
    _check(book.all_skills().size() == 1 and not is_instance_valid(enemy), "Duplicate analysis must consume a new specimen without stacking skills")
    _check(world.get_node("HUD/Analysis").text.contains("already known"), "Duplicate traits must be reported clearly")

    enemy = ENEMY_SCENE.instantiate()
    enemy.position = Vector2(520, 340)
    world.add_child(enemy)
    enemy.set_physics_process(false)
    enemy.get_node("Health").take_damage(999)
    await _frames(3)
    absorption.attempt_absorb()
    player.get_node("Health").take_damage(999)
    await _frames(3)
    _check(not absorption.active and is_instance_valid(enemy) and enemy.is_in_group("absorbable_creatures"), "Player defeat must interrupt analysis and preserve the corpse")
    _check(not absorption.attempt_absorb() and world.get_node("HUD/SystemVoice").text.contains("Press R"), "Defeated player cannot absorb or overwrite defeat feedback")
    _input(&"restart")
    await _frames(3)
    _check(current_scene.get_node("Player/SkillBook").all_skills().is_empty() and get_nodes_in_group("absorbable_creatures").is_empty(), "Restart must reset acquired traits and old corpses")
    print("Absorption checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
