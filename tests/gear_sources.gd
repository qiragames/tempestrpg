extends SceneTree
## Gear sources (step 17g): drop/chest/trial/forge roll rules, seeded chests, creature drops on the
## ground and picking them up, opening chests once per character, the trial reward, the Forge
## structure and recipes, saves, validation and the v18→v19 migration.
const SOURCES := preload("res://scripts/items/gear_sources.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const LAYOUT := preload("res://scripts/world/world_layout.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const CAMP := preload("res://scripts/settlement/first_camp.gd")
var checks := 0
var failures := 0
var world: Node2D
var messages: Array = []
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
    var rng := RandomNumberGenerator.new()
    rng.seed = 4711
    # --- Roll rules
    var drops := [0, 0, 0]
    var best := [0, 0, 0]
    for tier in range(3):
        for attempt in range(3000):
            var item: Dictionary = SOURCES.roll_drop(tier, rng)
            if not item.is_empty():
                drops[tier] += 1
                best[tier] = maxi(best[tier], int(item.rarity))
    _check(abs(drops[0] / 3000.0 - 0.1) < 0.025 and abs(drops[1] / 3000.0 - 0.2) < 0.03 and abs(drops[2] / 3000.0 - 0.45) < 0.035, "Drop chances by tier are about 10%% / 20%% / 45%% (%s)" % [drops])
    _check(best[0] <= 2 and best[1] <= 3 and best[2] >= 4, "Easy creatures drop at most Rare, Standard at most Epic, Elite up to Legendary (rarely Mythic)")
    var chest_ok := true
    var trial_ok := true
    var forge_ok := true
    for attempt in range(400):
        var chest: Dictionary = SOURCES.roll_chest(rng)
        chest_ok = chest_ok and chest.rarity >= 1 and GEAR.valid_item(chest)
        var reward: Dictionary = SOURCES.roll_trial(rng)
        trial_ok = trial_ok and reward.rarity in [2, 3] and GEAR.valid_item(reward)
        for recipe in SOURCES.RECIPES:
            var made: Dictionary = SOURCES.roll_forge(recipe, rng)
            forge_ok = forge_ok and made.rarity <= 2 and GEAR.BASES[made.base].slot in SOURCES.RECIPES[recipe].slots
    _check(chest_ok, "Chests give Uncommon or better")
    _check(trial_ok, "The trial gives Rare or Epic")
    _check(forge_ok, "Forge recipes make their kind (armor / weapon / accessory), Common to Rare")
    # --- Seeded chests
    var classic: Dictionary = LAYOUT.generate(0)
    _check(classic.chests.map(func(chest): return chest.position) == [Vector2(80, 80), Vector2(900, 600), Vector2(700, 60)], "The reference map has three fixed chests")
    var placement := true
    var same := true
    for seed in range(1, 201):
        var layout: Dictionary = LAYOUT.generate(seed)
        same = same and layout == LAYOUT.generate(seed)
        if layout.chests.map(func(chest): return chest.id) != LAYOUT.CHEST_IDS:
            placement = false
        for chest in layout.chests:
            var at: Vector2 = chest.position
            var bad: bool = not LAYOUT.WORLD.grow(-24).has_point(at) or LAYOUT.POND.grow(10).has_point(at) or at.distance_to(CAMP.SITE) < 150
            for rock in layout.rocks:
                bad = bad or rock.grow(12).has_point(at)
            for tree in layout.trees:
                bad = bad or Rect2(tree + Vector2(-6, 4), Vector2(12, 12)).grow(10).has_point(at)
            for other in layout.chests:
                bad = bad or (other.id != chest.id and at.distance_to(other.position) < 150)
            if bad:
                placement = false
    _check(placement and same, "200 seeds: three chests each, deterministic, in the open, away from the camp and from each other")
    # --- World: drops on the ground, pickup
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    world.system_message.connect(func(message: String): messages.append(message))
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    actor.position = Vector2(100, 600)
    var lucky := -1
    for seed in range(200):
        var probe := RandomNumberGenerator.new()
        probe.seed = seed
        if not SOURCES.roll_drop(2, probe).is_empty():
            lucky = seed
            break
    world.loot_rng.seed = lucky
    var elite = load("res://scenes/enemies/forest_gnasher.tscn").instantiate()
    elite.entity_id = "elite_dropper"
    elite.difficulty = 2
    elite.position = Vector2(300, 600)
    world.add_child(elite)
    world.wire_enemy(elite)
    elite.set_physics_process(false)
    elite.get_node("Health").take_damage(999, actor)
    await _frames()
    var loot: Array = get_nodes_in_group("gear_pickups")
    _check(loot.size() == 1 and GEAR.valid_item(loot[0].item) and loot[0].position.distance_to(elite.position) <= 25 and loot[0].pop_from == elite.position - loot[0].position, "A defeated creature can drop gear: it pops out of the creature and lands next to it")
    var dropped: Dictionary = loot[0].item.duplicate(true)
    var trial_corpse = load("res://scenes/enemies/forest_gnasher.tscn").instantiate()
    trial_corpse.entity_id = "trial_nodrop"
    trial_corpse.drops_rewards = false
    trial_corpse.difficulty = 2
    trial_corpse.position = Vector2(400, 600)
    world.add_child(trial_corpse)
    world.loot_rng.seed = lucky
    trial_corpse.get_node("Health").take_damage(999, actor)
    await _frames()
    _check(get_nodes_in_group("gear_pickups").size() == 1, "Trial creatures never drop gear")
    actor.position = loot[0].position
    await _frames(45)
    _check(get_nodes_in_group("gear_pickups").is_empty() and actor.item_by_id(dropped.id) == dropped and messages.any(func(m): return m.begins_with("Picked up")), "Walking over the loot picks it up into the gear bag")
    # A full bag leaves loot on the ground.
    while actor.gear.items.size() < GEAR.MAX_ITEMS:
        actor.add_item(GEAR.roll("cloth_hood", 0, rng))
    actor.position = Vector2(100, 600)
    var spare: Node2D = world.drop_gear(GEAR.roll("copper_ring", 1, rng), Vector2(160, 600))
    actor.position = Vector2(160, 600)
    await _frames(45)
    _check(is_instance_valid(spare) and spare.is_inside_tree() and messages.any(func(m): return m.begins_with("Gear bag full")), "With a full bag the loot stays on the ground")
    actor.gear.items = actor.gear.items.slice(0, 1)
    await _frames()
    _check(not is_instance_valid(spare) and actor.gear.items.size() == 2, "After making room the loot is picked up")
    # --- Chests
    var session: Node = root.get_node("GameSession")
    var chest_at: Vector2 = world.layout.chests[0].position
    actor.position = chest_at + Vector2(60, 0)
    _check(world.nearest_chest(actor).is_empty() and not session.apply_action(actor, "chest", {"id": "chest_1"}), "Chests open only from close by")
    actor.position = chest_at + Vector2(0, 14)
    var before: int = actor.gear.items.size()
    _check(world.nearest_chest(actor) == "chest_1" and session.apply_action(actor, "chest", {"id": "chest_1"}) and actor.progression.chests == ["chest_1"], "F at a chest opens it and remembers the chest")
    await _frames(1)
    var popped: Array = get_nodes_in_group("gear_pickups").filter(func(node): return node.owner_id == actor.character_id and node.position.distance_to(chest_at) <= 25.0)
    _check(popped.size() == 1 and popped[0].item.rarity >= 1 and actor.gear.items.size() == before, "The chest's Uncommon-or-better item pops out and lies beside it, claimed by the opener")
    var far_loot: String = popped[0].entity_id if popped.size() == 1 else ""
    actor.position = popped[0].position + Vector2(70, 0) if popped.size() == 1 else actor.position
    _check(world.nearest_loot(actor).is_empty() and not session.apply_action(actor, "loot", {"id": far_loot}), "F cannot reach loot that is too far away")
    actor.position = popped[0].position + Vector2(36, 0) if popped.size() == 1 else actor.position
    _check(world.nearest_loot(actor) == far_loot and session.apply_action(actor, "loot", {"id": far_loot}) and actor.gear.items.size() == before + 1, "F picks the loot up from a short way off")
    var rejected_loot: int = session.rejected_requests
    session.apply_action(actor, "loot", {"id": 4})
    _check(session.rejected_requests == rejected_loot + 1 and not session.apply_action(actor, "loot", {"id": "loot_nothing"}), "Malformed or unknown loot intents do nothing")
    actor.position = chest_at + Vector2(0, 14)
    _check(not session.apply_action(actor, "chest", {"id": "chest_1"}) and world.nearest_chest(actor).is_empty(), "Each character opens a chest once")
    var friend = load("res://scenes/player/player.tscn").instantiate()
    friend.character_id = "friend"
    friend.local_controlled = false
    friend.position = chest_at + Vector2(10, 12)
    world.add_child(friend)
    await _frames(1)
    _check(session.apply_action(friend, "chest", {"id": "chest_1"}), "Another character can open the same chest for their own item")
    await _frames(1)
    var theirs: Array = get_nodes_in_group("gear_pickups").filter(func(node): return node.owner_id == "friend")
    _check(theirs.size() == 1 and world.nearest_loot(actor) != theirs[0].entity_id and not session.apply_action(actor, "loot", {"id": theirs[0].entity_id}), "Someone else's claimed chest loot cannot be taken")
    friend.position = theirs[0].position if theirs.size() == 1 else friend.position
    await _frames(45)
    _check(friend.gear.items.size() == 1, "Walking over your own loot puts it in the bag")
    var rejected: int = session.rejected_requests
    session.apply_action(actor, "chest", {})
    session.apply_action(actor, "chest", {"id": 3})
    _check(session.rejected_requests == rejected + 2, "Malformed chest intents are rejected")
    friend.queue_free()
    # --- Trial reward
    before = actor.gear.items.size()
    world.trial.state.active = true
    world.trial.state.owner = actor.character_id
    world.trial._finish(true, "")
    _check(actor.gear.items.size() == before + 1 and actor.gear.items.back().rarity in [2, 3], "Completing the trial rewards a Rare or Epic item")
    # --- Forge
    var camp = world.camp
    _check(CAMP.STRUCTURES.has("forge_1") and CAMP.STRUCTURES.forge_1.requires == "hut_1" and camp.cost_text("forge_1") == "4 stone + 3 essence", "The Forge is a camp building (4 stone + 3 essence, after the hut)")
    camp.state.founded = true
    camp.state.founder = "host"
    camp.state.hut = true
    camp.state.forge = true
    var bag = actor.get_node("Inventory")
    bag.capacity = 20
    for count in range(2):
        bag.add_specimen(load("res://data/specimens/forest_gnasher.tres"))
    bag.add_specimen(load("res://data/specimens/thornback_gnasher.tres"))
    actor.position = CAMP.STRUCTURES.forge_1.site + Vector2(0, -40)
    before = actor.gear.items.size()
    _check(not camp.transact(actor, "craft", "weapon") and actor.gear.items.size() == before, "The weapon recipe needs 2 Thornback Quills")
    _check(camp.transact(actor, "craft", "armor") and actor.gear.items.size() == before + 1 and GEAR.BASES[actor.gear.items.back().base].slot in ["head", "body", "hands", "feet"], "2 Gnasher Essence forge a piece of armor")
    _check(bag.total_units() == 1, "The recipe consumed its materials")
    actor.position = Vector2(100, 600)
    _check(not camp.transact(actor, "craft", "accessory"), "Crafting needs you at the forge")
    camp.state.forge = false
    actor.position = CAMP.STRUCTURES.forge_1.site + Vector2(0, -40)
    _check(not camp.transact(actor, "craft", "accessory"), "No forge, no crafting")
    camp.state.forge = true
    # --- Saves
    world.drop_gear(GEAR.roll("iron_sword", 2, rng), Vector2(500, 600), "loot_savecheck01")
    var dir := OS.get_temp_dir().path_join("tempestrpg-sources-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var path := dir.path_join("sources.json")
    camp.state.forge = false
    camp.state.hut = false
    camp.state.founded = false
    camp.state.founder = ""
    _check(session.start_host(24700, path, false, {"name": "Sources", "seed": 0, "created": 1, "last_played": 1}) == OK and session.save_world() == OK, "World with loot and opened chests saves")
    var saved: Dictionary = STORE.load_world(path)
    _check(saved.ok and saved.data.version == STORE.VERSION and saved.data.loot.any(func(entry): return entry.id == "loot_savecheck01") and saved.data.players.host.progression.chests == ["chest_1"] and saved.data.camp.has("forge"), "Ground loot, opened chests and the forge flag are saved")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24700, path, false) == OK and world.entity_by_id("loot_savecheck01") != null and world.get_local_player().progression.chests == ["chest_1"], "Reload restores ground loot and opened chests")
    session.stop_session(false)
    var data: Dictionary = saved.data
    var duplicate_loot := data.duplicate(true)
    var copy: Dictionary = duplicate_loot.loot[0].duplicate(true)
    copy.id = "loot_duplicate_item"
    duplicate_loot.loot.append(copy)
    _check(not STORE.validate(duplicate_loot), "Two ground loot entities cannot contain the same gear instance")
    var already_owned := data.duplicate(true)
    already_owned.loot[0].item = already_owned.players.host.gear.items[0].duplicate(true)
    _check(not STORE.validate(already_owned), "Ground loot cannot duplicate a character-owned gear instance")
    var bad := []
    var doc: Dictionary
    doc = data.duplicate(true); doc.loot[0].item.stats.damage = 999; bad.append(doc)
    doc = data.duplicate(true); doc.loot.append(doc.loot[0].duplicate(true)); bad.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.chests = ["chest_9"]; bad.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.chests = ["chest_1", "chest_1"]; bad.append(doc)
    doc = data.duplicate(true); doc.camp.forge = true; bad.append(doc)
    doc = data.duplicate(true); doc.erase("loot"); bad.append(doc)
    var rejected_all := true
    for index in range(bad.size()):
        if STORE.validate(bad[index]):
            rejected_all = false
            push_error("Forged gear-source case %d was accepted" % index)
    _check(rejected_all, "Rejected: invalid loot item, duplicate loot, unknown or repeated chest, forge without a founded camp and hut, missing loot list")
    var legacy: Dictionary = data.duplicate(true)
    legacy.version = 18
    legacy.erase("loot")
    legacy.camp.erase("forge")
    legacy.players.host.progression.erase("chests")
    var migrated: Variant = STORE.migrate(legacy)
    _check(migrated is Dictionary and STORE.validate(migrated) and migrated.loot == [] and migrated.camp.forge == false and migrated.players.host.progression.chests == [], "v18 worlds migrate with no loot, no forge and no opened chests")
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Gear source checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
