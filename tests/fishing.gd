extends SceneTree
## Fishing (M6b): about forty fish by region and water with six rarities (mythical sea creatures
## worth a fortune), a reel-in minigame whose green zone is the shown catch chance per press,
## Fishing XP and milestones, a fish log, and selling whole stacks.
const FISHES := preload("res://scripts/professions/fish_catalogue.gd")
const PRO := preload("res://scripts/professions/profession_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
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

func _land(actor) -> bool:
    for _press in range(8):
        if actor.reel.is_empty():
            break
        actor.reel.centre = FISHES.marker(float(actor.reel.t), float(actor.reel.speed))
        if actor.reel_in() and actor.reel.is_empty():
            return true
    return false

func _run() -> void:
    # Catalogue.
    var counts := [0, 0, 0, 0, 0, 0]
    var regions_ok := true
    for id in FISHES.FISH:
        counts[int(FISHES.FISH[id][4])] += 1
        var where: String = String(FISHES.FISH[id][2]).trim_prefix("lake@").trim_prefix("sea@")
        regions_ok = regions_ok and (where in ["any", "lake", "sea"] or where in MAP.REGION_NAMES.values())
    _check(FISHES.FISH.size() >= 40 and counts[5] >= 5 and counts.min() >= 3, "About forty fish in six rarities, five or more mythical (%s)" % [counts])
    _check(regions_ok, "Every fish lives in real water")
    var trade := preload("res://scripts/trade/trade_catalogue.gd")
    _check(trade.sell_price(trade.price("leviathan")) >= 10000 and trade.sell_price(trade.price("minnow")) <= 5, "Mythical creatures sell for a fortune, minnows for little")
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    var seen := {}
    for _i in range(20000):
        seen[FISHES.pick("Frostpeak", true, 3, 50, rng)] = true
    _check(seen.has("ice_pike") and not seen.has("koi") and not seen.has("tuna"), "Frostpeak's lakes have their own fish, not the sea's or Sakura's")
    var mythic := 0
    rng.seed = 5
    # Across all weathers and times (the Kraken only rises in thunderstorms since M9b).
    for index in range(40000):
        var weather: String = ["clear", "rain", "storm", "fog"][index % 4]
        if int(FISHES.FISH[FISHES.pick("Verdant Isle", false, 0, 1, rng, index % 3 == 0, weather)][4]) == 5:
            mythic += 1
    _check(mythic > 0 and mythic < 120, "Mythical creatures are very rare (%d in 40000 sea bites)" % mythic)
    _check(FISHES.zone(1, "minnow", 0) > FISHES.zone(1, "kraken", 0) and FISHES.zone(50, "kraken", 3) > FISHES.zone(1, "kraken", 3), "The zone (chance) shrinks for fish above your level and grows with level")
    _check(FISHES.marker(0.0, 1.0) == 0.0 and is_equal_approx(FISHES.marker(1.0, 1.0), 1.0) and is_equal_approx(FISHES.marker(1.5, 1.0), 0.5), "The marker sweeps back and forth")
    # In a world: cast at a pier, hook, miss, land.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-fish-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24794, dir.path_join("fish.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    actor.progression.tools.rod = 1
    actor.global_position = MAP.dock_position("sunfall")
    actor.facing = Vector2(MAP.HARBOURS[0][3])
    world.terrain.ensure_props_at(actor.global_position)
    await _frames(2)
    _check(actor.cast_line() and actor.reel.is_empty(), "Casting: waiting for a bite")
    actor._tick_fishing(actor.fishing_bite_in + 0.05)
    _check(not actor.reel.is_empty() and actor.reel.has("width") and int(actor.reel.need) >= 1, "A bite hooks a fish and starts the reel-in minigame")
    # Misses: press outside the zone until it escapes.
    var escaped := false
    for _press in range(FISHES.MISSES + 1):
        actor.reel.width = 0.1
        actor.reel.centre = fposmod(FISHES.marker(float(actor.reel.t), float(actor.reel.speed)) + 0.5, 1.0)
        escaped = not actor.reel_in()
    _check(escaped and actor.reel.is_empty() and actor.fishing_bite_in == -INF, "Too many misses and the fish escapes")
    _check(int(actor.progression.professions.fishing) > 0, "An escape still teaches a little")
    # Land several fish.
    var landed := 0
    for _i in range(5):
        actor.cast_line()
        actor._tick_fishing(actor.fishing_bite_in + 0.05)
        if _land(actor):
            landed += 1
    _check(landed == 5 and actor.progression.fish_log.size() >= 1, "Hits in the zone land the fish into the bag and the fish log")
    # A Mythical catch: four hits and an announcement.
    actor.cast_line()
    actor._tick_fishing(actor.fishing_bite_in + 0.05)
    actor.reel = {"fish": "kraken", "rarity": 5, "need": 4, "hits": 0, "misses": 0, "centre": 0.5, "width": 0.2, "speed": 1.45, "t": 0.0}
    var hits := 0
    for _press in range(4):
        actor.reel.centre = FISHES.marker(float(actor.reel.t), float(actor.reel.speed))
        actor.reel_in()
        hits += 1
        if actor.reel.is_empty():
            break
    _check(hits == 4 and int(actor.progression.fish_log.get("kraken", 0)) == 1 and actor.get_node("Inventory").count_of("kraken") == 1, "A Kraken needs four hits and is logged")
    # Time limit.
    actor.cast_line()
    actor._tick_fishing(actor.fishing_bite_in + 0.05)
    actor._tick_fishing(FISHES.REEL_SECONDS + 0.5)
    _check(actor.reel.is_empty() and actor.fishing_bite_in == -INF, "A fish fought too long escapes")
    # Selling a whole stack.
    var bag: Node = actor.get_node("Inventory")
    bag.add_material("sardine", 5)
    actor.global_position = world.trade.merchant_position("merchant_brookhaven") + Vector2(-14, 0)
    world.terrain.ensure_props_at(actor.global_position)
    await _frames(2)
    var zeni: int = actor.zeni()
    var stack: int = bag.count_of("sardine")
    _check(stack >= 5 and world.trade.sell(actor, "merchant_brookhaven", "bag_all", "sardine") and bag.count_of("sardine") == 0 and actor.zeni() == zeni + stack * trade.sell_price(trade.price("sardine")), "Sell all sells the whole stack")
    var kraken_zeni: int = actor.zeni()
    world.trade.sell(actor, "merchant_brookhaven", "bag", "kraken")
    _check(actor.zeni() - kraken_zeni >= 9000, "The Kraken sells for a fortune")
    # Saves keep the fish log.
    _check(session.save_world() == OK, "World saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("fish.json")))
    _check(int(raw.players.host.progression.fish_log.kraken) == 1, "The fish log is saved")
    var bad: Dictionary = raw.duplicate(true)
    bad.players.host.progression.fish_log["not_a_fish"] = 1
    _check(not preload("res://scripts/persistence/save_store.gd").validate(bad), "A fish log with unknown fish is rejected")
    # The window's fishing tab.
    var hud: CanvasLayer = world.get_node("HUD")
    hud.professions_panel.open()
    hud.professions_panel._select("fishing")
    await _frames(1)
    _check(hud.professions_panel._entries("fishing").size() == FISHES.FISH.size(), "The professions window lists every fish")
    hud.professions_panel.close_panel()
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Fishing checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
