extends SceneTree
## Storage (after 1.0): settlement storage opens at a Vault and at every major city's town hall;
## Vaults add room; city storage is rented in a city and opens only there; items and gear go in
## and out; storage stays with its world; saves and the window.
const STORAGE := preload("res://scripts/settlement/storage.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
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

func _run() -> void:
    var cities: Array = STORAGE.cities()
    _check(cities.size() == 12 and "brookhaven" in cities and not "thornhollow" in cities, "Every major city (12) has a town hall with storage; villages do not")
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-storage-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24826, dir.path_join("storage.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var storage: Node = world.storage
    var camp: Node = world.camp
    var bag: Node = me.get_node("Inventory")
    bag.add_material("ore_iron", 30)
    var rng := RandomNumberGenerator.new()
    rng.seed = 6
    var sword: Dictionary = GEAR.roll("sword_080", 2, rng)
    sword["id"] = "item_store_sword0001"
    me.add_item(sword)
    me.progression["zeni"] = 10000
    var hall: Vector2 = STORAGE.hall_position("brookhaven")
    # City storage.
    me.global_position = hall
    _check(storage.reachable(me) == ["brookhaven"], "At Brookhaven's town hall: its storage (no settlement storage without a Vault)")
    _check(not session.apply_action(me, "storage", {"operation": "put", "where": "brookhaven", "item": "ore_iron", "count": 5}), "Nothing to store in before renting")
    _check(session.apply_action(me, "storage", {"operation": "buy", "where": "brookhaven", "item": "", "count": 0}) and int(me.progression.zeni) == 10000 - STORAGE.CITY_PRICE, "Renting storage in Brookhaven")
    _check(not storage.buy(me, "brookhaven"), "...once")
    _check(session.apply_action(me, "storage", {"operation": "put", "where": "brookhaven", "item": "ore_iron", "count": 10}) and bag.count_of("ore_iron") == 20 and int(STORAGE.box(me.progression, "brookhaven").goods.ore_iron) == 10, "Ten iron ore stored in Brookhaven")
    _check(storage.put(me, "brookhaven", "item_store_sword0001", 1) and me.item_by_id("item_store_sword0001").is_empty(), "A sword stored too")
    me.global_position = STORAGE.hall_position("harrowmere")
    _check(not storage.take(me, "brookhaven", "ore_iron", 1), "Brookhaven's storage cannot be opened in Harrowmere")
    me.global_position = hall
    _check(storage.take(me, "brookhaven", "item_store_sword0001", 1) and not me.item_by_id("item_store_sword0001").is_empty() and storage.take(me, "brookhaven", "ore_iron", 4) and bag.count_of("ore_iron") == 24, "Taking the sword and four ore back")
    # Settlement storage (the test founds the camp by hand; its real state comes back before saving).
    var camp_before: Dictionary = camp.state.duplicate(true)
    camp.state.founded = true
    camp.state.founder = "host"
    camp.state.nation.tier = 1
    _check(camp.place_problem(null, "vault", Vector2i(30, 30)) != "Unknown building.", "The Vault is a nation building")
    camp.state.nation.buildings.append({"id": "b_vault_1", "kind": "vault", "tile": [24, 24]})
    var vault_foot: Vector2 = NATION.foot(Vector2i(24, 24))
    me.global_position = vault_foot
    _check(storage.reachable(me) == ["home"] and storage.room("home") == [STORAGE.VAULT_UNITS, STORAGE.VAULT_GEAR], "At the Vault: settlement storage with one Vault's room")
    _check(storage.put(me, "home", "ore_iron", 20) and int(STORAGE.box(me.progression, "home").goods.ore_iron) == 20, "Storing ore in the settlement")
    me.global_position = STORAGE.hall_position("dunemarch")
    _check("home" in storage.reachable(me) and storage.take(me, "home", "ore_iron", 5) and bag.count_of("ore_iron") == 9, "Settlement storage opens at a faraway city's town hall (Dunemarch)")
    _check(not "brookhaven" in storage.reachable(me), "...but Brookhaven's city storage does not")
    camp.state.nation.buildings.append({"id": "b_vault_2", "kind": "vault", "tile": [28, 24]})
    _check(storage.room("home")[0] == STORAGE.VAULT_UNITS * 2, "A second Vault doubles the room")
    me.global_position = vault_foot
    for _round in range(4):
        bag.add_material("log_oak", 100)
        storage.put(me, "home", "log_oak", 1000)
    _check(STORAGE.units(STORAGE.box(me.progression, "home")) == STORAGE.VAULT_UNITS * 2 and bag.count_of("log_oak") > 0, "Storing stops at the room left")
    # (The test's Vaults stood on made-up tiles; the camp's own save checks would refuse them.)
    camp.state = camp_before
    # Saves; storage stays with its world.
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("storage.json")))
    _check(int(raw.players.host.progression.storage.home.goods.ore_iron) == 15 and STORAGE.units(raw.players.host.progression.storage.home) == STORAGE.VAULT_UNITS * 2 and raw.players.host.progression.storage.city.has("brookhaven"), "Storage is saved")
    var bad: Dictionary = raw.duplicate(true)
    bad.players.host.progression.storage.city["atlantis"] = {"gear": [], "goods": {}}
    var bad_goods: Dictionary = raw.duplicate(true)
    bad_goods.players.host.progression.storage.home.goods["gold_bricks"] = 5
    _check(not STORE.validate(bad) and not STORE.validate(bad_goods), "Unknown cities and goods are rejected")
    var travelling: Dictionary = preload("res://scripts/network/character_import.gd").carried(raw.players.host)
    _check(not travelling.progression.has("storage"), "Storage does not travel with a character into a friend's world")
    _check(not session.apply_action(me, "storage", {"operation": "steal", "where": "home", "item": "", "count": 0}), "Malformed storage requests are refused")
    # The window.
    var hud: CanvasLayer = world.get_node("HUD")
    hud.quest_panel._queue.clear()
    hud.dialog_panel.close()
    me.global_position = hall
    hud.storage_panel.open_at(storage.reachable(me), "brookhaven")
    await _frames(3)
    _check(hud.storage_panel.visible and hud.storage_panel._tabs.get_children().filter(func(tab): return not String(tab.name).begins_with("InnButton")).size() == 1 and hud.storage_panel._tabs.get_children().any(func(tab): return String(tab.name).begins_with("InnButton")) and hud.storage_panel._stored.get_child_count() >= 1, "The storage window shows Brookhaven storage and its contents (and the inn, M16)")
    hud.storage_panel.close_panel()
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Storage checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
