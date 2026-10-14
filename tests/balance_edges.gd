extends SceneTree
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("_run")
func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func _run() -> void:
    var world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    var target = world.entity_by_id("gnasher_1")
    target.get_node("Health").maximum = 100
    target.get_node("Health").current = 100
    var friend = load("res://scenes/player/player.tscn").instantiate()
    friend.character_id = "friend"
    friend.local_controlled = false
    world.add_child(friend)
    target.apply_status({"dot": [5.0, 3.0]}, actor)
    target.apply_status({"dot": [3.0, 2.0]}, friend)
    target._tick_status(1.0)
    _check(target.credit.get("host", 0) == 5 and not target.credit.has("friend"), "A weaker DoT cannot take credit for the stronger caster's effect")
    target.dot_left = 0
    target.credit = {}
    target.apply_status({"dot": [4.0, 3.0]}, friend)
    world.remove_child(friend)
    friend.free()
    target._tick_status(1.0)
    _check(target.credit.get("friend", 0) == 4, "A disconnected DoT caster retains stable damage credit")
    var document: Dictionary = CODEC.capture_entities(world)
    document.merge({"version": 21, "world_id": "balance_edges", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    var entry: Dictionary = document.enemies.filter(func(enemy): return enemy.id == "crater_thornback_1")[0]
    entry.maximum_hp = 90 # old Elite 60 HP, three players => 1.5x
    entry.hp = 45
    entry.group_scaled = true
    entry.credit = {"host": 45}
    var migrated: Dictionary = STORE.migrate(document)
    var updated: Dictionary = migrated.enemies.filter(func(enemy): return enemy.id == entry.id)[0]
    var expected: int = int(round(target.scaled_health(2, target.REGION.level_of(entry.id, 2)) * 1.5))
    _check(updated.maximum_hp == expected and updated.hp == int(round(expected * 0.5)), "v22 migration preserves the group HP multiplier and remaining health fraction")
    _check(updated.credit.host == int(floor(expected * 0.5)), "v22 migration rescales prior damage credit with creature HP")
    var legacy := document.duplicate(true)
    legacy.version = 20
    legacy.enemies = legacy.enemies.filter(func(enemy): return not target.REGION.is_spot_creature(enemy.id))
    var upgraded: Dictionary = STORE.migrate(legacy)
    var spot: Dictionary = upgraded.enemies.filter(func(enemy): return enemy.id == "spot_crater_b_3")[0]
    _check(spot.maximum_hp == target.scaled_health(2, 13), "Creatures introduced by older migrations receive level scaling exactly once")
    legacy = document.duplicate(true)
    legacy.players.host.progression.level = 20
    legacy.players.host.progression.experience = 9500
    legacy.players.host.progression.skill_points = 20
    upgraded = STORE.migrate(legacy)
    _check(upgraded.players.host.progression.level == 20 and upgraded.players.host.progression.experience == preload("res://scripts/progression/leveling.gd").max_experience() and upgraded.players.host.progression.skill_points == 20, "Capped legacy characters retain level and points at the new XP cap")
    world.queue_free()
    await process_frame
    print("Balance edge checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
