extends SceneTree
## The owner's mod menu (private dev build): boosts are off by default, only work for the host's
## own character, and the menu gives gear at any rarity and bag goods.
const DEV := preload("res://scripts/dev/dev_tools.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const SOURCES := preload("res://scripts/items/gear_sources.gd")
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
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-dev-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24791, dir.path_join("dev.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    var hud = world.get_node("GameHud") if world.has_node("GameHud") else null
    for child in world.get_children():
        if child is CanvasLayer and child.get("dev_panel") != null:
            hud = child
    _check(DEV.available(), "Editor runs count as the dev build")
    _check(not DEV.speed and not DEV.xp and not DEV.loot and not DEV.zeni and not DEV.god, "Every boost is off by default")
    _check(DEV.applies(actor), "Boosts apply to the host's own character")
    # Speed, XP, Zeni.
    var speed: float = actor.current_speed()
    DEV.set_flag("speed", true)
    _check(is_equal_approx(actor.current_speed(), speed * DEV.SPEED_FACTOR), "Super speed triples the speed")
    DEV.set_flag("speed", false)
    var zeni: int = actor.zeni()
    DEV.set_flag("zeni", true)
    actor.gain_zeni(5, "test")
    _check(actor.zeni() == zeni + 5 * DEV.ZENI_FACTOR, "Super Zeni multiplies Zeni")
    var experience: int = int(actor.progression.experience)
    DEV.set_flag("xp", true)
    actor.gain_experience(3, "test")
    _check(int(actor.progression.experience) == experience + 3 * DEV.XP_FACTOR, "Super XP multiplies experience")
    # Loot: every drop, mostly Epic and better.
    DEV.set_flag("loot", true)
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var drops := 0
    var high := 0
    for _i in range(100):
        var item: Dictionary = SOURCES.roll_drop(0, rng, 1)
        if not item.is_empty():
            drops += 1
            if int(item.rarity) >= 3:
                high += 1
    _check(drops == 100 and high >= 60, "Super loot: every creature drops, mostly Epic+ (%d/%d)" % [high, drops])
    # God mode.
    DEV.set_flag("god", true)
    var health: Node = actor.get_node("Health")
    _check(not health.take_damage(50) and health.current == health.maximum, "God mode: no damage")
    DEV.reset()
    _check(not DEV.flag("god") and not DEV.loot and not DEV.xp, "Reset turns every boost off")
    # The menu: gear at any rarity, bag goods.
    _check(hud != null and hud.dev_panel != null, "The HUD has the mod menu in dev runs")
    if hud != null and hud.dev_panel != null:
        var panel = hud.dev_panel
        panel.open()
        _check(panel.visible and panel._list.item_count > 0, "F10 opens the item list")
        panel._kind.select(panel.KINDS.find("dagger"))
        panel._search.text = ""
        panel._refresh_list()
        _check(panel._list.item_count >= 100, "The dagger list shows every dagger (%d)" % panel._list.item_count)
        panel._rarity.select(5)
        panel._list.select(0)
        var count: int = actor.gear.items.size()
        panel._give()
        _check(actor.gear.items.size() == count + 1 and int(actor.gear.items[-1].rarity) == 5, "Give: a Mythic dagger lands in the bag")
        panel._kind.select(panel.KINDS.find("Bag goods"))
        panel._refresh_list()
        _check(panel._list.item_count == panel.goods().size(), "Every bag good is listed")
        var orb: int = panel._ids.find("wish_orb_1")
        panel._list.select(orb)
        panel._amount.value = 1
        panel._give()
        _check(actor.get_node("Inventory").total_units() >= 1, "Give: a wish orb lands in the bag")
        var level: int = int(actor.progression.level)
        panel._gift("level")
        _check(int(actor.progression.level) == level + 1, "+1 level")
        panel._gift("points")
        _check(preload("res://scripts/progression/leveling.gd").valid(actor.progression), "Gifted skill points keep the save valid")
        panel.close_panel()
    # Clients never get boosts.
    actor.character_id = "friend"
    DEV.set_flag("speed", true)
    _check(not DEV.applies(actor), "Other characters never get boosts")
    actor.character_id = "host"
    DEV.reset()
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Dev tools checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
