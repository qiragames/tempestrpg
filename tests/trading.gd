extends SceneTree
## Trading between players (M11c): requests need nearness; offers must be owned and unworn; any
## change clears Ready; both Ready swaps gear, items and Zeni at once; room and ownership are
## checked again; walking apart ends a trade; the window; trades are never saved.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
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

func _friend(id: String, at: Vector2) -> CharacterBody2D:
    var other = load("res://scenes/player/player.tscn").instantiate()
    other.character_id = id
    other.local_controlled = false
    other.position = at
    world.add_child(other)
    return other

func _run() -> void:
    # These checks are about items, not classes (M12b): class requirements are off here.
    preload("res://scripts/progression/class_catalogue.gd").enforced = false
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-trading-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24816, dir.path_join("trading.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    me.position = Vector2(140, 560)
    var ann := _friend("ann", Vector2(900, 560))
    await _frames(1)
    var exchange: Node = world.exchange
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    var sword: Dictionary = GEAR.roll("t30_sword_080", 3, rng)
    sword["id"] = "item_trade_sword0001"
    var vest: Dictionary = GEAR.roll("padded_vest", 1, rng)
    vest["id"] = "item_trade_vest00001"
    me.add_item(sword)
    ann.add_item(vest)
    me.get_node("Inventory").add_material("ore_iron", 10)
    ann.progression["zeni"] = 5000
    # Requests.
    _check(not exchange.request(me, "ann"), "Too far apart to trade")
    ann.position = Vector2(170, 560)
    _check(exchange.request(me, "ann") and exchange.state.requests.has("ann"), "A trade request to someone next to you")
    _check(not exchange.accept(me), "Only the one asked can accept")
    _check(exchange.accept(ann) and not exchange.trade_of("host").is_empty() and exchange.trade_of("host") == exchange.trade_of("ann"), "Accepted: one trade for both")
    # Offers.
    _check(not exchange.offer(me, {"gear": ["item_nothing_here01"], "goods": {}, "zeni": 0}), "Gear you do not own cannot be offered")
    _check(not exchange.offer(me, {"gear": [], "goods": {"ore_iron": 11}, "zeni": 0}), "More than you have cannot be offered")
    _check(not exchange.offer(ann, {"gear": [], "goods": {}, "zeni": 6000}), "More Zeni than you have cannot be offered")
    me.equip("item_trade_sword0001", "weapon")
    _check(not exchange.offer(me, {"gear": ["item_trade_sword0001"], "goods": {}, "zeni": 0}), "Worn gear cannot be offered")
    me.unequip("weapon")
    _check(exchange.offer(me, {"gear": ["item_trade_sword0001"], "goods": {"ore_iron": 4}, "zeni": 0}), "Offering a sword and 4 iron ore")
    _check(exchange.offer(ann, {"gear": ["item_trade_vest00001"], "goods": {}, "zeni": 1500}), "Ann offers a vest and 1,500 Zeni")
    var trade_id: String = exchange.trade_of("host")
    exchange.mark_ready(me, true)
    _check(exchange.offer(ann, {"gear": ["item_trade_vest00001"], "goods": {}, "zeni": 1200}) and not bool(exchange.state.trades[trade_id].ready.host), "A changed offer clears Ready")
    var my_zeni: int = int(me.progression.get("zeni", 0))
    exchange.mark_ready(me, true)
    _check(exchange.state.trades.has(trade_id), "One side ready is not enough")
    exchange.mark_ready(ann, true)
    _check(not exchange.state.trades.has(trade_id), "Both ready: the trade completes")
    _check(not me.item_by_id("item_trade_vest00001").is_empty() and me.item_by_id("item_trade_sword0001").is_empty(), "The vest is mine, the sword is gone")
    _check(not ann.item_by_id("item_trade_sword0001").is_empty() and ann.get_node("Inventory").count_of("ore_iron") == 4 and me.get_node("Inventory").count_of("ore_iron") == 6, "Ann has the sword and 4 iron ore")
    _check(int(me.progression.zeni) == my_zeni + 1200 and int(ann.progression.zeni) == 3800, "1,200 Zeni changed hands")
    # Checked again at the end; walking apart.
    exchange.request(ann, "host")
    exchange.accept(me)
    exchange.offer(ann, {"gear": ["item_trade_sword0001"], "goods": {}, "zeni": 0})
    ann.remove_item("item_trade_sword0001")
    trade_id = exchange.trade_of("host")
    exchange.mark_ready(me, true)
    exchange.mark_ready(ann, true)
    _check(not exchange.state.trades.has(trade_id) and ann.item_by_id("item_trade_sword0001").is_empty() and me.item_by_id("item_trade_sword0001").is_empty(), "Something gone by the end: the trade fails and nothing moves")
    exchange.request(me, "ann")
    exchange.accept(ann)
    ann.position = Vector2(900, 560)
    exchange._process(0.1)
    _check(exchange.trade_of("host").is_empty(), "Walking apart ends a trade")
    # The intent and the window.
    ann.position = Vector2(170, 560)
    _check(session.apply_action(me, "exchange", {"operation": "request", "who": "ann"}) and session.apply_action(ann, "exchange", {"operation": "accept"}), "Trading through the intent")
    _check(not session.apply_action(me, "exchange", {"operation": "offer", "offer": "everything"}) and not session.apply_action(me, "exchange", {"operation": "steal"}), "Malformed trade requests are refused")
    var hud: CanvasLayer = world.get_node("HUD")
    hud.quest_panel._queue.clear()
    hud.dialog_panel.close()
    await _frames(4)
    _check(hud.exchange_panel.visible and hud.exchange_panel._title.text.contains("ANN"), "The trade window opens by itself")
    _check(hud.exchange_panel._mine.get_child_count() >= 2, "It lists your things to offer")
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("trading.json")))
    _check(not raw.has("exchange") and session.document().has("exchange"), "Open trades travel with snapshots but are never saved")
    session.apply_action(me, "exchange", {"operation": "cancel"})
    await _frames(3)
    _check(not hud.exchange_panel.visible, "Cancelling closes the window")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Trading checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
