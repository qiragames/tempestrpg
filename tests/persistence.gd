extends SceneTree
const STORE := preload("res://scripts/persistence/save_store.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _run() -> void:
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var player = world.get_local_player()
    player.position = Vector2(300, 340)
    player.progression = {"level": 4, "experience": 3000, "skill_points": 4, "race": "Slime", "quests": {"intro": {"stage": 2}}, "equipment": {}, "tree": {"nodes": [], "active": [], "free": []}, "chests": [], "zeni": 0}
    player.get_node("Magicules").try_spend(30)
    player.get_node("Health").take_damage(23)
    player.get_node("SkillBook").record_analysis(&"forest_gnasher")
    player.get_node("Inventory").add_specimen(load(CODEC.SPECIMEN))
    player.get_node("MeleeAttack").cooldown_left = 0.7
    var enemy = world.get_node("ForestGnasher")
    enemy.get_node("Health").take_damage(999)
    await process_frame
    await process_frame
    var saved := CODEC.capture_entities(world)
    saved.merge({"version": STORE.VERSION, "world_id": "world_test", "players": {"host": CODEC.capture_player(player)}, "progression": {"quests": {"village": 1}, "settlements": {"camp": {"wood": 12}}, "world_time": 50.0}})
    _check(STORE.validate(saved), "Complete state must validate")
    var folder := OS.get_temp_dir().path_join("tempestrpg-save-test-" + Crypto.new().generate_random_bytes(16).hex_encode())
    var path := folder + "/world.json"
    _check(STORE.write_world(path, saved) == OK, "First atomic save must succeed")
    var result := STORE.load_world(path)
    _check(result.ok and not result.recovered, "Primary save must load")
    _check(result.data.players.host.position == [300.0, 340.0] and result.data.players.host.progression.level == 4, "Position and progression must round-trip")
    _check(result.data.players.host.health.current == 77 and result.data.players.host.magicules.current == 70, "Stats and resources must round-trip")
    _check(result.data.players.host.skill_ids == ["rending_bite"] and result.data.players.host.inventory.counts.gnasher_essence == 1, "Skills and inventory must round-trip")
    _check(result.data.enemies[0].hp == 0 and result.data.pickups.size() == 1, "Defeated entity and uncollected reward must round-trip")
    _check(result.data.progression.settlements.camp.wood == 12, "Shared world state must round-trip")
    player.position = Vector2(100, 100)
    CODEC.apply_player(player, result.data.players.host, world, false)
    _check(player.position.is_equal_approx(Vector2(300, 340)) and player.get_node("Inventory").total_units() == 1, "Actual actor restoration must apply saved state")
    _check(is_equal_approx(player.get_node("MeleeAttack").cooldown_left, result.data.players.host.attack_recovery), "Cooldown must survive restoration")
    CODEC.apply_entities(world, result.data, false)
    _check(get_nodes_in_group("magicule_pickups").size() == 1, "Applying saved defeated enemies must not create duplicate drops")
    var second := saved.duplicate(true)
    second.players.host.progression.level = 5
    second.players.host.progression.experience = 6000
    second.players.host.progression.skill_points = 5
    _check(STORE.write_world(path, second) == OK and FileAccess.file_exists(path + ".bak"), "Second save must preserve a backup")
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string("{truncated")
    file.close()
    result = STORE.load_world(path)
    _check(result.ok and result.recovered and result.data.players.host.progression.level == 4, "Corrupt primary must recover the previous valid save")
    _check(STORE.write_world(path, second) == OK and STORE.load_world(path).data.players.host.progression.level == 5, "Recovered world must be safely writable without destroying its good backup")
    file = FileAccess.open(folder + "/invalid.json", FileAccess.WRITE)
    file.store_string("not-json")
    file.close()
    _check(not STORE.load_world(folder + "/invalid.json").ok, "Corrupt save without valid backup must fail")
    var mutations: Array = []
    var bad := saved.duplicate(true)
    bad.version = 99
    mutations.append(bad)
    bad = saved.duplicate(true)
    bad.players.host.position = [NAN, 0]
    mutations.append(bad)
    bad = saved.duplicate(true)
    bad.players.host.skill_ids = ["../../malicious"]
    mutations.append(bad)
    bad = saved.duplicate(true)
    bad.players.host.inventory.counts.gnasher_essence = 999
    mutations.append(bad)
    bad = saved.duplicate(true)
    bad.pickups.append(bad.pickups[0].duplicate(true))
    mutations.append(bad)
    bad = saved.duplicate(true)
    bad.players.host.health.current = -1
    mutations.append(bad)
    bad = saved.duplicate(true)
    bad.players.host.magicules.current = 1000
    mutations.append(bad)
    bad = saved.duplicate(true)
    bad.players.host.slots = ["unlearned", "", ""]
    mutations.append(bad)
    bad = saved.duplicate(true)
    bad.enemies[0].state = 0
    mutations.append(bad)
    for index in range(mutations.size()):
        _check(not STORE.validate(mutations[index]), "Invalid schema case %d must be rejected" % index)
    _check(STORE.write_world(path, mutations[0]) == ERR_INVALID_DATA and STORE.load_world(path).data.players.host.progression.level == 5, "Invalid writes must preserve the valid primary")
    var legacy := saved.duplicate(true)
    legacy.version = 0
    legacy.erase("progression")
    legacy.players.host.erase("progression")
    legacy.players.host.erase("slots")
    var migrated: Variant = STORE.migrate(legacy)
    _check(STORE.validate(migrated) and migrated.players.host.progression.level == 1 and migrated.players.host.slots[0] == "rending_bite", "Draft-schema migration must supply progression and loadout defaults")
    _check(STORE.migrate({"version": 0, "players": []}) == null, "Malformed legacy schema must fail cleanly")
    var session: Node = root.get_node("GameSession")
    _check(not session.apply_action(player, "respawn"), "A living character must not reset health through respawn")
    player.get_node("Health").current = 0
    player.get_node("Magicules").enabled = false
    _check(session.apply_action(player, "respawn") and player.get_node("Health").current == 100 and player.get_node("Magicules").enabled, "Dead character respawn must restore playability")
    _check(player.get_node("Inventory").total_units() == 1 and player.get_node("SkillBook").knows(&"rending_bite") and player.progression.level == 4, "Respawn must preserve character progression and inventory")
    var guest = load("res://scenes/player/player.tscn").instantiate()
    guest.local_controlled = false
    guest.character_id = "guest"
    guest.position = Vector2(590, 340)
    world.add_child(guest)
    var live_enemy = world.get_node("SecondGnasher")
    live_enemy.position = Vector2(600, 340)
    _check(live_enemy._nearest_player() == guest, "Enemy targeting must select the nearest living character, not the first player")
    live_enemy.target = guest
    live_enemy.state = live_enemy.State.WINDUP
    live_enemy.state_time = 0.3
    world.remove_child(guest)
    guest.queue_free()
    live_enemy._physics_process(0.016)
    _check(live_enemy.target == player, "A disconnected target must be released even during a windup")
    print("Persistence checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
