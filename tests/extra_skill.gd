extends SceneTree
const CATALOGUE := preload("res://scripts/skills/skill_catalogue.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
const THORNBACK := preload("res://scenes/enemies/thornback_gnasher.tscn")
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
func _spawn(scene: PackedScene, id: String, at: Vector2) -> Node2D:
    var enemy = scene.instantiate()
    enemy.entity_id = id
    enemy.position = at
    world.add_child(enemy)
    world.wire_enemy(enemy)
    enemy.set_physics_process(false)
    return enemy
## Defeat, stand beside the corpse and finish a full analysis on the host.
func _analyze(actor: Node2D, enemy: Node2D) -> bool:
    enemy.get_node("Health").take_damage(999)
    await _frames()
    actor.position = enemy.position + Vector2(-14, 0)
    await _frames(1)
    var absorption = actor.get_node("Absorption")
    if not absorption.attempt_absorb():
        return false
    absorption._process(2.0)
    return not absorption.active
func _guest(id: String, at: Vector2) -> Node2D:
    var guest = load("res://scenes/player/player.tscn").instantiate()
    guest.character_id = id
    guest.local_controlled = false
    guest.position = at
    world.add_child(guest)
    return guest
func _run() -> void:
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var session = root.get_node("GameSession")
    var actor = world.get_local_player()
    var book = actor.get_node("SkillBook")
    var bag = actor.get_node("Inventory")
    var pool = actor.get_node("Magicules")
    var melee = actor.get_node("MeleeAttack")
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var messages: Array = []
    actor.get_node("Absorption").status_changed.connect(func(message: String): messages.append(message))
    await _frames()
    _check(CATALOGUE.resource_errors().is_empty(), "Catalogue, skills and specimens agree: %s" % [CATALOGUE.resource_errors()])
    var thornback = world.entity_by_id("thornback_1")
    _check(thornback != null and thornback.kind == "thornback" and thornback.specimen.id == &"thornback_gnasher" and thornback.position == Vector2(880, 560), "Thornback Gnasher waits in the southeast corner")
    _check(CATALOGUE.RULES.piercing_fang == {"tier": "Extra", "requires": ["rending_bite", "thorn_lash"], "analysis": "thornback_gnasher"}, "Piercing Fang needs Rending Bite + Thorn Lash and a Thornback analysis")
    # Order A: Thornback first. Only the Common is earned; the Extra needs Rending Bite too.
    _check(await _analyze(actor, thornback), "Thornback analysis completes")
    _check(book.knows(&"thorn_lash") and not book.knows(&"piercing_fang") and book.skill_at_slot(0).id == &"thorn_lash", "Thorn Lash learned alone; no Extra without Rending Bite")
    _check(messages.back() == "Analysis complete. Common: Thorn Lash acquired.", "System Voice names the new Common skill")
    _check(bag.entries().any(func(entry): return entry.id == &"thornback_quill" and entry.name == "Thornback Quill"), "Thornback Quill stored in the bag")
    var gnasher = world.entity_by_id("gnasher_1")
    _check(await _analyze(actor, gnasher), "Forest Gnasher analysis completes")
    _check(book.knows(&"rending_bite") and book.knows(&"piercing_fang"), "Knowing both Commons with Thornback evidence unlocks the Extra")
    _check(messages.back() == "Analysis complete. Common: Rending Bite, Extra: Piercing Fang acquired.", "One analysis reports both new skills in tier order")
    _check(book.skill_at_slot(1).id == &"rending_bite" and book.skill_at_slot(2).id == &"piercing_fang", "New skills fill the remaining hotbar slots")
    var again = _spawn(THORNBACK, "thornback_test_a", Vector2(700, 600))
    _check(await _analyze(actor, again) and book.known_ids().size() == 3 and messages.back().contains("already known"), "Repeat analysis adds no skill")
    # Order B: Rending Bite first, then one Thornback analysis grants Common and Extra together.
    var guest = _guest("guest", Vector2(600, 600))
    guest.get_node("SkillBook").record_analysis(&"forest_gnasher")
    var gained: Array = guest.get_node("SkillBook").record_analysis(&"thornback_gnasher")
    _check(gained.map(func(skill): return String(skill.id)) == ["thorn_lash", "piercing_fang"], "Reverse order unlocks Thorn Lash and Piercing Fang in one analysis")
    var third = _guest("guest_b", Vector2(600, 620))
    third.get_node("SkillBook").record_analysis(&"thornback_gnasher")
    _check(third.get_node("SkillBook").known_ids() == ["thorn_lash"], "Each character needs its own Rending Bite for the Extra")
    # Piercing Fang hits every creature in a line; Rending Bite only the nearest.
    actor.position = Vector2(560, 600)
    var near = _spawn(GNASHER, "line_near", Vector2(580, 600))
    var far = _spawn(GNASHER, "line_far", Vector2(612, 600))
    var side = _spawn(GNASHER, "line_side", Vector2(580, 630))
    await _frames()
    pool._current = 100.0
    melee.cooldown_left = 0.0
    _check(melee.attack_skill(Vector2.RIGHT, &"rending_bite") and near.get_node("Health").current == 10 and far.get_node("Health").current == 30, "Rending Bite reaches only the adjacent creature")
    await create_timer(0.85).timeout
    var before: float = pool.current
    _check(melee.attack_skill(Vector2.RIGHT, &"piercing_fang"), "Piercing Fang activates")
    _check(near.get_node("Health").current == 0 and far.get_node("Health").current == 4 and side.get_node("Health").current == 30, "Piercing Fang damages both creatures in the line, not the one beside it")
    _check(is_equal_approx(pool.current, before - 18.0) and is_equal_approx(melee.cooldown_left, 1.2), "Piercing Fang costs 18 Magicules and starts a 1.2s cooldown")
    _check(not melee.attack_skill(Vector2.RIGHT, &"piercing_fang") and is_equal_approx(pool.current, before - 18.0), "Cooldown blocks a second thrust without spending")
    world._add_obstacle(Rect2(596, 588, 4, 24))
    await _frames()
    melee.cooldown_left = 0.0
    far.get_node("Health").current = 30
    melee.attack_skill(Vector2.RIGHT, &"piercing_fang")
    _check(far.get_node("Health").current == 30, "Terrain blocks the thrust's line of sight")
    pool._current = 10.0
    melee.cooldown_left = 0.0
    _check(not melee.attack_skill(Vector2.RIGHT, &"piercing_fang") and pool.current == 10.0, "Insufficient Magicules reject Piercing Fang")
    # Two characters reaching for one corpse: the host reserves it for the first.
    var contested = _spawn(THORNBACK, "thornback_test_b", Vector2(300, 600))
    contested.get_node("Health").take_damage(999)
    await _frames()
    var rival = _guest("rival", contested.position + Vector2(12, 0))
    actor.position = contested.position + Vector2(-12, 0)
    pool._current = 100.0
    await _frames(1)
    _check(actor.get_node("Absorption").attempt_absorb(), "First claim reserves the corpse")
    _check(not rival.get_node("Absorption").attempt_absorb(), "Second claim on the same corpse fails")
    actor.get_node("Absorption")._process(2.0)
    _check(rival.get_node("SkillBook").known_ids().is_empty() and rival.get_node("Inventory").total_units() == 0, "Rival gains no skill or quill")
    # Persistence: kinds, quills and evidence survive save and reload.
    var corpse = _spawn(THORNBACK, "thornback_corpse", Vector2(820, 600))
    corpse.get_node("Health").take_damage(999)
    await _frames()
    var data: Dictionary = CODEC.capture_entities(world)
    var players := {"host": CODEC.capture_player(actor)}
    for other in [guest, third, rival]:
        players[other.character_id] = CODEC.capture_player(other)
        players[other.character_id]["token_hash"] = "b".repeat(64)
    data.merge({"version": STORE.VERSION, "world_id": "extra_world", "players": players, "progression": world.progression.duplicate(true)})
    _check(STORE.VERSION == 8 and STORE.validate(data), "v8 world with Thornback, quills and Extra validates")
    _check(not data.enemies.any(func(enemy): return enemy.id == "thornback_1"), "Absorbed Thornback is consumed and absent from the save")
    _check(data.enemies.any(func(enemy): return enemy.id == "thornback_corpse" and enemy.kind == "thornback" and enemy.hp == 0), "Defeated, unabsorbed Thornback saved with its kind")
    var path := OS.get_temp_dir().path_join("tempestrpg-extra-" + Crypto.new().generate_random_bytes(8).hex_encode()) + "/world.json"
    _check(STORE.write_world(path, data) == OK, "World saves atomically")
    var loaded: Dictionary = STORE.load_world(path)
    _check(loaded.ok and loaded.data.players.host.skill_ids.size() == 3, "Reload keeps all three skills")
    var restored = _guest("restored", Vector2(500, 500))
    CODEC.apply_player(restored, loaded.data.players.host, world, false)
    _check(restored.get_node("SkillBook").knows(&"piercing_fang") and restored.get_node("Inventory").entries().any(func(entry): return entry.name == "Thornback Quill"), "Restored character keeps Extra and named quill")
    world.remove_child(corpse)
    corpse.queue_free()
    CODEC.apply_entities(world, loaded.data, false)
    var rebuilt = world.entity_by_id("thornback_corpse")
    _check(rebuilt != null and rebuilt.kind == "thornback" and rebuilt.get_node("Health").current == 0, "Reload rebuilds the Thornback from its saved kind")
    var bad := data.duplicate(true)
    bad.players.host.inventory.counts["dragon_scale"] = 1
    _check(not STORE.validate(bad), "Unknown materials rejected")
    bad = data.duplicate(true)
    bad.enemies[0].kind = "dragon"
    _check(not STORE.validate(bad), "Unknown enemy kinds rejected")
    bad = data.duplicate(true)
    bad.players.rival.skill_ids = ["piercing_fang"]
    _check(not STORE.validate(bad), "Extra without its evidence and Commons rejected")
    # v7 worlds gain the encounter exactly once.
    var legacy := data.duplicate(true)
    legacy.version = 7
    legacy.enemies = legacy.enemies.filter(func(enemy): return enemy.id != "thornback_1")
    var migrated: Dictionary = STORE.migrate(legacy)
    var added: Array = migrated.enemies.filter(func(enemy): return enemy.id == "thornback_1")
    _check(STORE.validate(migrated) and added.size() == 1 and added[0].hp == 30 and added[0].position == [880.0, 560.0], "v7 worlds gain one living Thornback at home")
    legacy = data.duplicate(true)
    legacy.version = 7
    var defeated: Dictionary = STORE.THORNBACK.duplicate(true)
    defeated.hp = 0
    defeated.state = 4
    legacy.enemies.append(defeated)
    migrated = STORE.migrate(legacy)
    _check(migrated.enemies.filter(func(enemy): return enemy.id == "thornback_1").size() == 1 and migrated.enemies.filter(func(enemy): return enemy.id == "thornback_1")[0].hp == 0, "Migration never duplicates or revives an existing Thornback")
    session.replica_world = true
    _check(guest.get_node("SkillBook").record_analysis(&"thornback_gnasher").is_empty(), "Replicas cannot record Thornback evidence")
    session.replica_world = false
    print("Extra skill checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
