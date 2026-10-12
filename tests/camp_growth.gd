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
func _frames(count: int = 3) -> void:
    for _i in range(count):
        await physics_frame
        await process_frame
func _document(world: Node2D, actor: Node2D) -> Dictionary:
    var data: Dictionary = CODEC.capture_entities(world)
    data.merge({"version": STORE.VERSION, "world_id": "growth_test", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    return data
func _gather_at(camp: Node2D, actor: Node2D, id: String) -> bool:
    actor.position = camp.DEPOSITS[id].position
    return camp.transact(actor, "gather", id)
func _run() -> void:
    var world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var session = root.get_node("GameSession")
    var actor = world.get_local_player()
    var camp = world.camp
    var ally = world.get_node("GoblinAlly")
    var bag = actor.get_node("Inventory")
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    ally.set_physics_process(false)
    await _frames()
    _check(camp.state.deposits.size() == 6 and camp.state.deposits.wood_3 == 8 and camp.state.deposits.stone_2 == 8 and camp.state.deposits.stone_3 == 8, "Three outlying deposits begin untouched")
    _check(camp.level() == 0 and camp.state.essence == 0, "Unfounded camp has no level or essence")
    _check(_gather_at(camp, actor, "wood_3") and camp.state.wood == 8 and camp.state.deposits.wood_3 == 0, "Explorers gather outlying wood into shared stock")
    # Founding fixture: named, evolved ally beside the flag.
    ally.owner_id = "host"
    ally.display_name = "Aster"
    ally.race = "Hobgoblin"
    ally.maximum_hp = 60
    ally.power = 8
    ally.follow_speed = 65
    ally.position = Vector2(330, 370)
    actor.position = camp.SITE
    _check(not camp.transact(actor, "offer", "gnasher_essence"), "Offering requires a founded camp")
    _check(camp.transact(actor, "found", "camp_1") and camp.level() == 1, "Founded camp reaches level 1")
    _check(not camp.transact(actor, "offer", "gnasher_essence") and camp.state.essence == 0, "Offering requires essence in the bag")
    bag.add_specimen(load(CODEC.SPECIMEN))
    bag.add_specimen(load(CODEC.SPECIMEN))
    actor.position = Vector2(100, 340)
    _check(not camp.transact(actor, "offer", "gnasher_essence"), "Offering requires standing at the camp")
    actor.position = camp.SITE
    _check(not camp.transact(actor, "offer", "rending_bite"), "Only Gnasher Essence can be offered")
    _check(not session.apply_action(actor, "camp", {"operation": "offer", "id": "gnasher_essence", "amount": 9}), "Host rejects forged offering payloads")
    _check(session.apply_action(actor, "camp", {"operation": "offer", "id": "gnasher_essence"}) and camp.state.essence == 1 and camp.state.essence_offered == 1 and bag.total_units() == 1, "Offering moves exactly one essence from bag to camp")
    session.replica_world = true
    _check(not camp.transact(actor, "offer", "gnasher_essence") and bag.total_units() == 1, "Client replicas cannot offer essence")
    session.replica_world = false
    _check(camp.transact(actor, "offer", "gnasher_essence") and camp.state.essence == 2 and bag.total_units() == 0, "Second essence offered")
    _check(not camp.transact(actor, "offer", "gnasher_essence") and camp.state.essence == 2, "Empty bag cannot offer again")
    # Gather everything else; near deposits by hand here, worker behavior is covered by ally_work.gd.
    for id in ["wood_1", "wood_2", "stone_1", "stone_2", "stone_3"]:
        _check(_gather_at(camp, actor, id), "Gathered %s" % id)
    _check(camp.state.wood == 24 and camp.state.stone == 24, "All six deposits supply 24 wood and 24 stone")
    actor.position = camp.SITE
    _check(not camp.affordable("storehouse_1") and not camp.affordable("shrine_1"), "Storehouse and shrine stay locked until the hut exists")
    _check(not camp.transact(actor, "build", "storehouse_1"), "Locked structures cannot be built")
    _check(camp.next_buildable() == "hut_1", "Hut is the first buildable structure")
    _check(camp.transact(actor, "build", "hut_1") and camp.level() == 2, "Hut raises the camp to level 2")
    var dialog = world.get_node("HUD")._camp_dialog
    dialog.open_dialog()
    _check(not dialog._build_buttons.storehouse_1.disabled and not dialog._build_buttons.shrine_1.disabled and dialog._build_buttons.hut_1.text.contains("built") and dialog._stock.text.contains("2 essence"), "Menu shows level, essence and unlocked recipes")
    _check(dialog._offer.disabled, "Offer button disabled with an empty bag")
    dialog._request("build", "storehouse_1")
    dialog.close_dialog()
    _check(camp.state.storehouse and camp.state.wood == 2 and camp.state.stone == 12 and camp.level() == 3, "Storehouse consumes 10 wood + 6 stone once")
    _check(not camp.transact(actor, "build", "storehouse_1") and camp.state.wood == 2, "Storehouse cannot be built twice")
    await _frames()
    var store_site: Vector2 = camp.STRUCTURES.storehouse_1.site
    var ray := PhysicsRayQueryParameters2D.create(store_site - Vector2(25, 0), store_site + Vector2(25, 0), 1)
    _check(not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "Built storehouse has collision")
    ally.position = camp.STRUCTURES.shrine_1.site
    _check(not camp.build_ready("shrine_1"), "Shrine footprint must be clear")
    ally.position = camp.SITE
    _check(ally.assign_work(actor, "build") and ally.work_target == "shrine_1" and ally.work_left == 2, "Worker picks the next funded structure; storehouse halves build time")
    ally._physics_process(1)
    _check(not camp.state.shrine and camp.state.essence == 2, "Shrine is paid only on completion")
    ally._physics_process(1)
    _check(camp.state.shrine and camp.state.stone == 4 and camp.state.essence == 0 and ally.work_role == "follow" and camp.level() == 4, "Worker completes shrine, charges stone + essence once")
    _check(not ally.assign_work(actor, "build"), "Nothing left to build")
    _check(not ally.assign_work(actor, "gather"), "Workers ignore outlying deposits and empty near deposits")
    # Shrine regeneration bonus.
    var pool = actor.get_node("Magicules")
    actor.position = camp.STRUCTURES.shrine_1.site + Vector2(0, 30)
    pool.try_spend(50)
    pool._delay_left = 0.5
    var before: float = pool.current
    camp._physics_process(1.0)
    _check(pool.current == before, "Shrine waits for the normal regeneration delay")
    pool._delay_left = 0
    camp._physics_process(1.0)
    _check(is_equal_approx(pool.current, before + pool.regeneration_per_second), "Shrine adds the character's regeneration rate again")
    actor.position = Vector2(100, 340)
    before = pool.current
    camp._physics_process(1.0)
    _check(pool.current == before, "No shrine bonus away from the shrine")
    # Persistence and validation.
    var document := _document(world, actor)
    _check(STORE.validate(document), "Grown camp snapshot validates")
    var path := OS.get_temp_dir().path_join("tempestrpg-growth-" + Crypto.new().generate_random_bytes(8).hex_encode()) + "/world.json"
    _check(STORE.write_world(path, document) == OK, "Grown camp saves atomically")
    var loaded: Dictionary = STORE.load_world(path)
    camp.restore(camp.initial_state())
    CODEC.apply_entities(world, loaded.data, false)
    ally.set_physics_process(false)
    _check(camp.state == loaded.data.camp and camp.state.deposits.size() == 6 and camp.state.storehouse and camp.state.shrine and camp.state.essence_offered == 2, "Reload restores structures, essence and outlying deposits")
    var bad := document.duplicate(true)
    bad.camp.essence = 5
    _check(not STORE.validate(bad), "Fabricated essence stock rejected")
    bad = document.duplicate(true)
    bad.camp.hut = false
    _check(not STORE.validate(bad), "Storehouse/shrine without hut rejected")
    bad = document.duplicate(true)
    bad.camp.deposits.stone_2 = 3
    _check(not STORE.validate(bad), "Partial outlying deposits rejected")
    bad = document.duplicate(true)
    bad.camp.erase("shrine")
    _check(not STORE.validate(bad), "Missing structure field rejected")
    bad = document.duplicate(true)
    bad.allies[0].work = {"role": "gather", "target": "stone_2", "remaining": 1.0}
    _check(not STORE.validate(bad), "Workers cannot be saved gathering outlying deposits")
    bad = document.duplicate(true)
    bad.allies[0].work = {"role": "build", "target": "storehouse_1", "remaining": 2.0}
    _check(STORE.validate(bad), "Saved build jobs accept any known structure")
    # A version-5 world (hut built, near deposits spent) gains the new content untouched.
    var legacy := document.duplicate(true)
    legacy.version = 5
    legacy.camp = {"id": "camp_1", "founded": true, "founder": "host", "wood": 4, "stone": 2, "hut": true, "deposits": {"wood_1": 0, "wood_2": 0, "stone_1": 0}}
    var migrated: Dictionary = STORE.migrate(legacy)
    _check(STORE.validate(migrated) and migrated.camp.deposits.wood_3 == 8 and migrated.camp.essence == 0 and not migrated.camp.storehouse and migrated.camp.wood == 4, "Version-5 camps migrate with untouched outlying deposits")
    legacy.version = 4
    legacy.allies[0].erase("work")
    _check(STORE.validate(STORE.migrate(legacy)), "Version-4 saves migrate through v5 to v6")
    print("Camp growth checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
