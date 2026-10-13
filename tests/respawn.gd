extends SceneTree
## Creature respawning (step 17d2): scheduling on defeat, delay, same ID/kind/difficulty at home,
## corpse cleanup, no spawning on a player, trial creatures excluded, repeatable XP and drops,
## host-only, saves, validation and the v16→v17 migration.
const RESPAWNER := preload("res://scripts/world/respawner.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const LAYOUT := preload("res://scripts/world/world_layout.gd")
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

func _run() -> void:
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    actor.position = Vector2(100, 600)
    var respawner = world.respawner
    var gnasher: Node2D = world.entity_by_id("gnasher_1")
    var home: Vector2 = gnasher.home
    var tier: int = gnasher.difficulty
    _check(respawner.pending.is_empty(), "No respawns are pending at the start")
    # --- Defeat schedules; the corpse waits
    gnasher.get_node("Health").take_damage(999, actor)
    var xp_first: int = actor.progression.experience
    _check(respawner.scheduled("gnasher_1") and respawner.pending[0].kind == "gnasher" and respawner.pending[0].remaining == RESPAWNER.RESPAWN_SECONDS and respawner.pending[0].home == [home.x, home.y], "A defeat schedules a respawn at the creature's home in %d s" % int(RESPAWNER.RESPAWN_SECONDS))
    gnasher.get_node("Health").take_damage(999, actor)
    _check(respawner.pending.size() == 1, "A creature is scheduled once")
    await _frames()
    var first_drop: Array = get_nodes_in_group("magicule_pickups").map(func(pickup): return pickup.entity_id)
    respawner._physics_process(RESPAWNER.RESPAWN_SECONDS - 1.0)
    _check(world.entity_by_id("gnasher_1") == gnasher and gnasher.get_node("Health").current == 0, "Nothing returns before the delay")
    # --- Respawn replaces an unabsorbed corpse, same ID/kind/difficulty, at home, full health
    respawner._physics_process(1.5)
    await _frames(1)
    var back: Node2D = world.entity_by_id("gnasher_1")
    _check(back != null and back != gnasher and back.get_node("Health").current == back.get_node("Health").maximum and back.position == home and back.home == home and back.kind == "gnasher" and back.difficulty == tier, "The creature returns at its home with full health, same ID, kind and difficulty")
    _check(not is_instance_valid(gnasher), "Its unabsorbed corpse is cleared")
    _check(respawner.pending.is_empty() and get_nodes_in_group("enemies").filter(func(enemy): return enemy.entity_id == "gnasher_1").size() == 1, "Exactly one gnasher_1 exists afterwards")
    # --- Repeatable rewards: XP again and a drop with a fresh ID
    back.set_physics_process(false)
    back.get_node("Health").take_damage(999, actor)
    await _frames()
    var drops: Array = get_nodes_in_group("magicule_pickups").map(func(pickup): return pickup.entity_id)
    var unique := {}
    for id in drops:
        unique[id] = true
    _check(actor.progression.experience == xp_first + LEVELING.DEFEAT_XP[back.difficulty] and respawner.scheduled("gnasher_1"), "Defeating it again gives XP again and schedules another respawn")
    _check(drops.size() == first_drop.size() + 1 and unique.size() == drops.size(), "Each drop gets its own ID, even from the same creature")
    # --- Absorbed corpse: the creature still returns
    actor.position = back.position + Vector2(-14, 0)
    await _frames()
    actor.get_node("Magicules")._current = actor.get_node("Magicules").maximum
    var absorption = actor.get_node("Absorption")
    _check(absorption.attempt_absorb(), "The corpse can be absorbed")
    # --- Never on top of a player
    respawner.pending[0].remaining = 0.0
    respawner._physics_process(0.016)
    _check(respawner.scheduled("gnasher_1") and respawner.pending[0].remaining == RESPAWNER.RETRY_SECONDS, "While being absorbed / with a player at its home, the respawn waits and retries")
    absorption._process(3.0)
    await _frames(1)
    _check(world.entity_by_id("gnasher_1") == null, "The absorbed corpse is consumed")
    actor.position = Vector2(100, 600)
    respawner._physics_process(RESPAWNER.RETRY_SECONDS)
    await _frames(1)
    _check(world.entity_by_id("gnasher_1") != null and world.entity_by_id("gnasher_1").get_node("Health").current > 0, "Once the player has left, an absorbed creature returns too")
    # --- Trial creatures never respawn
    var trial_creature = load("res://scenes/enemies/forest_gnasher.tscn").instantiate()
    trial_creature.entity_id = "trial_test_1"
    trial_creature.drops_rewards = false
    trial_creature.position = Vector2(300, 600)
    world.add_child(trial_creature)
    world.wire_enemy(trial_creature)
    trial_creature.get_node("Health").take_damage(999, actor)
    _check(not respawner.scheduled("trial_test_1"), "Trial creatures are never scheduled")
    # --- Host only
    var session: Node = root.get_node("GameSession")
    var thornback: Node2D = world.entity_by_id("thornback_1")
    session.replica_world = true
    respawner.schedule(thornback)
    _check(not respawner.scheduled("thornback_1"), "Clients do not schedule respawns")
    session.replica_world = false
    # --- Saves
    thornback.get_node("Health").take_damage(999, actor)
    var dir := OS.get_temp_dir().path_join("tempestrpg-respawn-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var path := dir.path_join("respawn.json")
    _check(session.start_host(24670, path, false, {"name": "Respawn", "seed": 0, "created": 1, "last_played": 1}) == OK and session.save_world() == OK, "World with a pending respawn saves")
    var saved: Dictionary = STORE.load_world(path)
    _check(saved.ok and saved.data.version == STORE.VERSION and saved.data.respawns.size() == 1 and saved.data.respawns[0].id == "thornback_1" and saved.data.respawns[0].kind == "thornback", "The pending Thornback respawn is saved")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24670, path, false) == OK and world.respawner.scheduled("thornback_1"), "Reload restores the pending respawn")
    world.get_local_player().position = Vector2(100, 600)
    world.respawner._physics_process(RESPAWNER.RESPAWN_SECONDS)
    await _frames(1)
    _check(world.entity_by_id("thornback_1") != null and world.entity_by_id("thornback_1").kind == "thornback" and world.entity_by_id("thornback_1").get_node("Health").current > 0, "After reload the Thornback returns on time")
    session.stop_session(false)
    var data: Dictionary = saved.data
    var ally_collision := data.duplicate(true)
    ally_collision.respawns[0].id = ally_collision.allies[0].id
    _check(not STORE.validate(ally_collision), "Respawn IDs cannot collide with an ally")
    var pickup_collision := data.duplicate(true)
    pickup_collision.respawns[0].id = "respawn_pickup_collision"
    pickup_collision.pickups.append({"id": "respawn_pickup_collision", "position": [600.0, 400.0], "amount": 8.0})
    _check(not STORE.validate(pickup_collision), "Respawn IDs cannot collide with a pickup")
    var forged := []
    var doc: Dictionary
    doc = data.duplicate(true); doc.respawns[0].kind = "dragon"; forged.append(doc)
    doc = data.duplicate(true); doc.respawns[0].id = "gnasher_2"; forged.append(doc)
    doc = data.duplicate(true); doc.respawns[0].remaining = -1; forged.append(doc)
    doc = data.duplicate(true); doc.respawns[0].remaining = 9999; forged.append(doc)
    doc = data.duplicate(true); doc.respawns.append(doc.respawns[0].duplicate()); forged.append(doc)
    doc = data.duplicate(true); doc.erase("respawns"); forged.append(doc)
    var rejected_all := true
    for index in range(forged.size()):
        if STORE.validate(forged[index]):
            rejected_all = false
            push_error("Forged respawn case %d was accepted" % index)
    _check(rejected_all, "Rejected: unknown kind, respawn of a living creature, negative or too long timers, duplicates, missing list")
    var legacy: Dictionary = data.duplicate(true)
    legacy.version = 16
    legacy.erase("respawns")
    legacy.enemies = legacy.enemies.filter(func(enemy): return enemy.id != "gnasher_1")
    var migrated: Variant = STORE.migrate(legacy)
    var ids: Array = migrated.respawns.map(func(entry): return entry.id) if migrated is Dictionary else []
    ids.sort()
    _check(migrated is Dictionary and STORE.validate(migrated) and ids == ["gnasher_1", "thornback_1"] and migrated.respawns.all(func(entry): return entry.remaining == RESPAWNER.RESPAWN_SECONDS), "v16 worlds schedule their absorbed and defeated seeded creatures to return")
    var spot: Dictionary = LAYOUT.generate(0).creatures.gnasher_1
    var gnasher_entry: Dictionary = migrated.respawns.filter(func(entry): return entry.id == "gnasher_1")[0] if migrated is Dictionary else {}
    _check(gnasher_entry.get("home") == [spot.position.x, spot.position.y] and gnasher_entry.get("kind") == "gnasher", "An absorbed creature returns at its seeded spot")
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Respawn checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
