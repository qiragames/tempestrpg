extends SceneTree
## Loot timers and dropping things (user requests): after 10 s on the ground loot shows whose it
## is and for how long ("Aster · 4:32"), then when it disappears ("gone in 9:21"); loot disappears
## 10 minutes after dropping. Bag things and loose gear can be dropped at your feet: anyone may
## take them, the dropper only walks them back up after stepping away (F any time), worn gear
## and wish orbs stay; saved with the world.
const LABEL := preload("res://scripts/pickups/claim_label.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
var world: Node2D
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

func _now() -> float:
    return float(world.progression.get("world_time", 0.0))

func _run() -> void:
    _check(LABEL.clock(272.0) == "4:32" and LABEL.clock(0.2) == "0:01", "Timers read m:ss")
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-drop-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24941, dir.path_join("drop.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    me.progression["name"] = "Aster"
    me.global_position = Vector2(480, 330)
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    # Timers over loot.
    var loot: Node2D = world.drop_gear(GEAR.roll("iron_sword", 1, rng), Vector2(600, 330), "", "host")
    _check(LABEL.text(loot, loot.owner_id, loot.claim_until, loot.since, loot.since + loot.LIFETIME).is_empty(), "Fresh loot shows no timer")
    world.progression["world_time"] = _now() + 12.0
    _check(LABEL.text(loot, loot.owner_id, loot.claim_until, loot.since, loot.since + loot.LIFETIME).begins_with("Aster · 4:"), "After 10 s: whose it is and for how long")
    world.progression["world_time"] = loot.claim_until + 1.0
    _check(LABEL.text(loot, loot.owner_id, loot.claim_until, loot.since, loot.since + loot.LIFETIME).begins_with("gone in "), "Then: when it disappears")
    world.progression["world_time"] = loot.since + loot.LIFETIME + 1.0
    await _frames(2)
    _check(not is_instance_valid(loot) or loot.is_queued_for_deletion(), "Loot disappears 10 minutes after dropping")
    # Dropping bag things.
    var bag: Node = me.get_node("Inventory")
    bag.add_material("ore_iron", 5)
    _check(session.apply_action(me, "drop_item", {"id": "ore_iron", "count": 2}) and bag.count_of(&"ore_iron") == 3, "Drop 2 iron ore")
    var piles: Array = get_nodes_in_group("item_piles").filter(func(pile): return pile.materials.has("ore_iron"))
    _check(piles.size() == 1 and piles[0].owner_id.is_empty() and piles[0].gone_at > _now() and piles[0].global_position.distance_to(me.global_position) < 16.0, "They lie at your feet for anyone, with an end time")
    await _frames(6)
    _check(is_instance_valid(piles[0]) and bag.count_of(&"ore_iron") == 3, "The dropper does not pick them straight back up")
    _check(world.nearest_loot(me) == piles[0].entity_id and session.apply_action(me, "loot", {"id": piles[0].entity_id}) and bag.count_of(&"ore_iron") == 5, "F takes them back")
    var rejected: int = session.rejected_requests
    session.apply_action(me, "drop_item", {"id": "ore_iron", "count": 0})
    session.apply_action(me, "drop_item", {"id": "ore_iron"})
    _check(session.rejected_requests == rejected + 2 and not session.apply_action(me, "drop_item", {"id": "nothing_here", "count": 1}), "Bad drops are refused")
    bag.add_material("wish_orb_1", 1)
    _check(not session.apply_action(me, "drop_item", {"id": "wish_orb_1", "count": 1}) and bag.count_of(&"wish_orb_1") == 1, "Wish orbs cannot be dropped")
    # Dropping gear.
    var spare: Dictionary = GEAR.roll("copper_ring", 1, rng)
    me.add_item(spare)
    _check(session.apply_action(me, "gear", {"operation": "drop", "id": spare.id}) and me.item_by_id(spare.id).is_empty(), "A loose piece can be dropped")
    var lying: Array = get_nodes_in_group("gear_pickups").filter(func(node): return node.item.id == spare.id)
    _check(lying.size() == 1 and lying[0].owner_id.is_empty() and lying[0].dropper == "host", "It lies at your feet for anyone")
    var worn: Dictionary = GEAR.roll("cloth_hood", 0, rng)
    me.add_item(worn)
    preload("res://scripts/progression/class_catalogue.gd").enforced = false
    me.equip(worn.id, "head")
    _check(not session.apply_action(me, "gear", {"operation": "drop", "id": worn.id}) and not me.item_by_id(worn.id).is_empty(), "Worn gear is taken off first")
    # Saved with the world.
    bag.add_material("ore_iron", 1)
    session.apply_action(me, "drop_item", {"id": "ore_iron", "count": 1})
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("drop.json")))
    _check(STORE.validate(raw) and raw.piles.any(func(pile): return pile.has("gone_at")) and raw.loot.any(func(entry): return entry.has("since")), "Dropped things keep their end time in the save")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Loot timer and drop checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
