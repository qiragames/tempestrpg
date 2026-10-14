extends SceneTree
## Save/reconnect must retain combat eligibility and pending respawns;
## reaching the world pile limit must never erase a character's bag.
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const PILE := preload("res://scripts/pickups/item_pile.gd")
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
    var session = root.get_node("GameSession")
    var world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await process_frame
    world.set_process(false)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    actor.set_process(false)
    actor.set_physics_process(false)
    var enemy = world.entity_by_id("gnasher_1")
    enemy.credit = {"host": 20}
    enemy._group_scaled = true
    var entities: Dictionary = CODEC.capture_entities(world)
    enemy.credit = {}
    enemy._group_scaled = false
    CODEC.apply_entities(world, entities, false)
    _check(enemy.credit == {"host": 20} and enemy.may_absorb("host") and not enemy.may_absorb("other"), "Reload preserves damage shares and absorption eligibility")
    _check(enemy._group_scaled, "Reload preserves whether group HP scaling already ran")
    actor.get_node("Health").current = 0
    actor.death_left = 2.25
    var saved: Dictionary = CODEC.capture_player(actor)
    actor.death_left = 0.0
    CODEC.apply_player(actor, saved, world, false)
    _check(actor.death_left == 2.25, "Reload/reconnect preserves the remaining automatic respawn timer")
    var legacy := saved.duplicate(true)
    legacy.erase("death_left")
    CODEC.apply_player(actor, legacy, world, false)
    _check(actor.death_left == actor.RESPAWN_DELAY, "Legacy dead characters receive an automatic respawn countdown")
    var bad := saved.duplicate(true)
    bad.death_left = -1.0
    _check(not STORE.validate_player(bad, "host"), "Negative death timers are rejected")
    bad.death_left = INF
    _check(not STORE.validate_player(bad, "host"), "Nonfinite death timers are rejected")
    var document: Dictionary = CODEC.capture_entities(world)
    document.merge({"version": STORE.VERSION, "world_id": "balance_review", "players": {"host": saved}, "progression": world.progression.duplicate(true)})
    _check(STORE.validate(document), "Captured credit and pending respawns form a valid save")
    var invalid := document.duplicate(true)
    invalid.enemies[0].credit = {"host": INF}
    _check(not STORE.validate(invalid), "Nonfinite damage credit is rejected")
    invalid.enemies[0].credit = {"host": -1}
    _check(not STORE.validate(invalid), "Negative damage credit is rejected")
    invalid.enemies[0].credit = {"host": 1}
    invalid.enemies[0].group_scaled = "yes"
    _check(not STORE.validate(invalid), "Malformed group scaling flags are rejected")
    # Capacity failure happens after bag removal in the original implementation.
    session.world = world
    for index in range(PILE.MAX_PILES):
        var pile = world.drop_pile("host", {"gnasher_essence": 1}, [], Vector2(-500, -500))
        pile.set_physics_process(false)
    actor.get_node("Inventory").add_specimen(load(CODEC.SPECIMEN))
    var item: Dictionary = world.SOURCES.roll_chest(world.loot_rng)
    actor.add_item(item)
    actor._death_penalty()
    _check(actor.get_node("Inventory").total_units() == 1 and not actor.item_by_id(item.id).is_empty() and get_nodes_in_group("item_piles").size() == PILE.MAX_PILES, "At the pile limit, materials and unequipped gear stay in the bag rather than vanishing")
    session.world = null
    world.queue_free()
    await process_frame
    print("Balance persistence checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
