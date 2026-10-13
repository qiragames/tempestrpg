extends SceneTree
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
var checks := 0
var failures := 0
var world: Node2D
func _initialize() -> void:
    call_deferred("_run")
func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func _frames(count: int = 3) -> void:
    for _i in range(count):
        await physics_frame
        await process_frame
func _absorb(actor: Node2D, difficulty: int, id: String) -> bool:
    var enemy = GNASHER.instantiate()
    enemy.entity_id = id
    enemy.difficulty = difficulty
    enemy.position = Vector2(600, 600)
    world.add_child(enemy)
    enemy.set_physics_process(false)
    enemy.get_node("Health").take_damage(999)
    actor.position = enemy.position + Vector2(-14, 0)
    await _frames()
    var absorption = actor.get_node("Absorption")
    if not absorption.attempt_absorb():
        return false
    absorption._process(2.0)
    return not absorption.active
func _run() -> void:
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var session = root.get_node("GameSession")
    var actor = world.get_local_player()
    var health = actor.get_node("Health")
    var messages: Array = []
    actor.get_node("Absorption").status_changed.connect(func(message: String): messages.append(message))
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    await _frames()
    var tiers: Dictionary = preload("res://scripts/enemies/forest_gnasher.gd").TIER_STATS
    _check(tiers[0].absorb_heal == 15.0 and tiers[1].absorb_heal == 25.0 and tiers[2].absorb_heal == 40.0, "Easy/Standard/Elite heal 15/25/40")
    health.current = 40
    _check(await _absorb(actor, 1, "standard_a"), "Standard absorption completes")
    _check(health.current == 40 and is_equal_approx(health.regen_rate, 2.5) and is_equal_approx(health.regen_left, 10.0), "Healing starts gradually: 25 HP over 10 s, nothing instant")
    _check(messages.has("Absorbed vitality: +25 HP over 10s."), "System Voice announces the heal")
    health._process(4.0)
    _check(health.current == 50, "After 4 s, 10 HP restored")
    health._process(10.0)
    _check(health.current == 65 and health.regen_left == 0.0 and health.regen_rate == 0.0, "Exactly 25 HP over the full 10 s, then it stops")
    health.current = 92
    health.start_regen(40.0)
    health._process(10.0)
    _check(health.current == 100, "Healing never exceeds max HP")
    health.current = 20
    _check(await _absorb(actor, 2, "elite_a") and is_equal_approx(health.regen_rate, 4.0), "Elite absorption heals 40 over 10 s")
    health._process(5.0)
    _check(health.current == 40, "Half of the Elite heal after 5 s")
    _check(await _absorb(actor, 0, "easy_a") and is_equal_approx(health.regen_rate, 4.0) and health.regen_left > 4.0, "A weaker heal does not replace a stronger running one")
    health._process(5.0)
    _check(health.current == 60 and health.regen_left == 0.0, "Original Elite heal finishes unchanged")
    health.current = 90
    _check(await _absorb(actor, 0, "easy_b") and is_equal_approx(health.regen_rate, 1.5), "Easy absorption heals 15 over 10 s")
    health._process(1.0)
    _check(await _absorb(actor, 1, "standard_b") and is_equal_approx(health.regen_rate, 2.5) and health.regen_left == 10.0, "A stronger heal replaces a weaker one")
    health.take_damage(999)
    await _frames()
    health._process(1.0)
    _check(health.current == 0 and health.regen_left == 0.0, "Defeat ends healing")
    health.current = 50
    _check(not health.start_regen(0.0) and not health.start_regen(-5.0), "Zero or negative heals are ignored")
    session.replica_world = true
    _check(not health.start_regen(25.0), "Client replicas cannot start healing")
    health.regen_rate = 2.5
    health.regen_left = 10.0
    health._process(4.0)
    _check(health.current == 50, "Client replicas do not tick healing")
    session.replica_world = false
    # Save and reload keep the running heal.
    var data: Dictionary = CODEC.capture_entities(world)
    data.merge({"version": STORE.VERSION, "world_id": "heal_world", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    data.erase("trial")
    _check(STORE.VERSION >= 11 and STORE.validate(data) and data.players.host.health.regen_left == 10.0, "v11 save stores the running heal")
    var restored = load("res://scenes/player/player.tscn").instantiate()
    restored.local_controlled = false
    world.add_child(restored)
    await _frames(1)
    CODEC.apply_player(restored, JSON.parse_string(JSON.stringify(data.players.host)), world, false)
    restored.get_node("Health")._process(4.0)
    _check(restored.get_node("Health").current == 60, "Reloaded heal continues where it stopped")
    var bad := data.duplicate(true)
    bad.players.host.health.regen_rate = 50
    _check(not STORE.validate(bad), "Implausible heal rate rejected")
    var legacy := data.duplicate(true)
    legacy.version = 10
    legacy.erase("meta")
    legacy.players.host.health.erase("regen_rate")
    legacy.players.host.health.erase("regen_left")
    legacy.players.host.health.erase("regen_carry")
    var migrated: Dictionary = STORE.migrate(legacy)
    _check(STORE.validate(migrated) and migrated.players.host.health.regen_left == 0.0, "v10 characters migrate without healing")
    # Codex review of 16b: frame rounding and fractional progress across save/reload.
    health.current = 10
    health.clear_regen()
    health.start_regen(25.0)
    for _i in range(601):
        health._process(1.0 / 60.0)
    _check(health.current == 35, "A 25 HP heal ticked at 60 fps restores all 25 HP (no rounding loss)")
    health.current = 10
    health.clear_regen()
    health.start_regen(25.0)
    health._process(0.3)
    var mid: Dictionary = CODEC.capture_player(actor)
    _check(mid.health.regen_carry > 0.0 and mid.health.regen_carry < 1.0, "Fractional healing progress is captured")
    var fresh = load("res://scenes/player/player.tscn").instantiate()
    fresh.local_controlled = false
    world.add_child(fresh)
    await _frames(1)
    restored.get_node("Health")._regen_carry = 0.9
    CODEC.apply_player(fresh, JSON.parse_string(JSON.stringify(mid)), world, false)
    CODEC.apply_player(restored, JSON.parse_string(JSON.stringify(mid)), world, false)
    for target in [health, fresh.get_node("Health"), restored.get_node("Health")]:
        target._process(target.regen_left)
    _check(health.current == 35 and fresh.get_node("Health").current == 35 and restored.get_node("Health").current == 35, "Uninterrupted, reloaded and overwritten heals all end at 35 HP")
    var carry_doc := data.duplicate(true)
    for value in [1.0, -0.1]:
        carry_doc.players.host.health.regen_carry = value
        _check(not STORE.validate(carry_doc), "Invalid healing remainder %s rejected" % value)
    print("Absorb healing checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
