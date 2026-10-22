extends SceneTree
## Teleport scrolls (user request): each city's merchant sells "Scroll: <City>"; using it opens the
## map, the cities you hold a scroll for glow, clicking one starts a 3 s cast (a hit cancels it and
## keeps the scroll) that ends in front of that city's merchant and uses the scroll.
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
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

func _run() -> void:
    _check(TRADE.teleport_town("teleport_harrowmere") == "harrowmere" and TRADE.teleport_town("teleport_nowhere") == "" and TRADE.is_good("teleport_harrowmere") and TRADE.price("teleport_harrowmere") == TRADE.TELEPORT_PRICE, "Scrolls exist for the cities")
    _check(TRADE.good_info("teleport_harrowmere")[0] == "Scroll: Harrowmere", "Named after their city")
    var stock: Array = TRADE.roll_stock(TRADE.merchant("merchant_harrowmere"), RandomNumberGenerator.new())
    _check(stock.any(func(entry): return entry.id == "teleport_harrowmere") and not stock.any(func(entry): return entry.id == "teleport_brookhaven") and TRADE.valid_stock(stock), "Each city's merchant sells its own city's scroll")
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-tp-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24951, dir.path_join("tp.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    me.global_position = Vector2(480, 330)
    _check(not session.apply_action(me, "teleport", {"to": "harrowmere"}), "No scroll, no teleport")
    var bag: Node = me.get_node("Inventory")
    bag.add_material("teleport_harrowmere", 2)
    var hud: CanvasLayer = world.get_node("HUD")
    if hud.dialog_panel.is_open():
        hud.dialog_panel.close()
    hud.world_map.open_teleport()
    await _frames(2)
    var targets: Array = hud.world_map.teleport_targets()
    _check(hud.world_map.teleport_mode and targets.size() == 1 and targets[0][0] == "harrowmere" and hud.world_map.teleport_at(targets[0][1]) == "harrowmere", "The map shows the cities you hold a scroll for")
    hud.world_map.choose_teleport("harrowmere")
    _check(not hud.world_map.visible and me.teleport_to == "harrowmere", "Clicking the city starts the teleport")
    await _frames(30)
    me.get_node("Health").take_damage(1)
    _check(me.teleport_to.is_empty() and bag.count_of(&"teleport_harrowmere") == 2, "A hit cancels it (the scroll is kept)")
    me.get_node("Health").immunity_left = 0.0
    _check(session.apply_action(me, "teleport", {"to": "harrowmere"}), "Starting again")
    me._calm = 0.0
    for _i in range(5):
        await _frames(40)
        if me.teleport_to.is_empty():
            break
    var merchant_at: Vector2 = world.trade.merchant_position("merchant_harrowmere")
    _check(me.global_position.distance_to(merchant_at) < 40.0 and bag.count_of(&"teleport_harrowmere") == 1, "After 3 seconds you stand at Harrowmere's merchant; one scroll used")
    var rejected: int = session.rejected_requests
    session.apply_action(me, "teleport", {"to": 5})
    _check(session.rejected_requests == rejected + 1 and not session.apply_action(me, "teleport", {"to": "nowhere"}), "Bad teleports are refused")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Teleport scroll checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
