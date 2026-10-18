extends SceneTree
## Boss drops (user request after M15): every raid boss, hidden elite and dungeon boss has its own
## uniques and its own themed material (a name and icon of its own); a defeated boss gives every
## helper some of its material; the material and bars of the item's tier forge that boss's uniques
## at Smithing; the boss bar lists the drops (uniques in their rarity's colour, the material with
## how many).
const BOSS := preload("res://scripts/bosses/boss_catalogue.gd")
const LOOT := preload("res://scripts/bosses/boss_loot.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const CRAFT := preload("res://scripts/professions/crafting_catalogue.gd")
const PRO := preload("res://scripts/professions/profession_catalogue.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
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
    # Every boss: uniques, a material of its own.
    var problems: Array = []
    var names := {}
    for id in BOSS.all_ids():
        var uniques: Array = BOSS.entry(id)[8]
        if uniques.is_empty() or uniques.any(func(base): return not GEAR.BASES.has(base)):
            problems.append(id + " has no uniques")
        var material := LOOT.material(id)
        var name := LOOT.name_of(material)
        if not LOOT.NAMES.has(id) or names.has(name) or LOOT.icon(material) == null or not TRADE.bag_item(material):
            problems.append(id + " material")
        names[name] = true
        for base in uniques:
            if not CRAFT.recipe("bossforge:" + base).size() > 0:
                problems.append(base + " cannot be forged")
    _check(problems.is_empty(), "All %d bosses have uniques and a themed material of their own (forgeable) %s" % [BOSS.all_ids().size(), problems])
    _check(TRADE.good_info(LOOT.material("boss_gnashmaw"))[0] == "Gnashmaw's Brood Fangs" and TRADE.price(LOOT.material("boss_gnashmaw")) > 0, "Gnashmaw's Brood Fangs: a bag good with a price")
    # A world.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-boss-drops-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24835, dir.path_join("drops.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var bag: Node = me.get_node("Inventory")
    # The boss bar lists the drops.
    var boss: Node2D = null
    for node in get_nodes_in_group("raid_bosses"):
        if node.entity_id == "boss_gnashmaw":
            boss = node
    me.global_position = BOSS.centre("boss_gnashmaw") + Vector2(0, 40)
    world.terrain.ensure_props_at(me.global_position)
    var hud: CanvasLayer = world.get_node("HUD")
    hud.quest_panel._queue.clear()
    hud.dialog_panel.close()
    await _frames(3)
    hud._refresh_boss_bar()
    var drops_row: Node = hud.get_node_or_null("BossBar/Drops")
    _check(drops_row != null and drops_row.get_child_count() == LOOT.drops("boss_gnashmaw").size(), "The boss bar lists Gnashmaw's drops (%d)" % LOOT.drops("boss_gnashmaw").size())
    # Defeat: the material for every helper.
    boss.credit = {me.character_id: 100}
    boss._defeat()
    await _frames(2)
    var have: int = bag.count_of(LOOT.material("boss_gnashmaw"))
    var counts := LOOT.count_range("boss_gnashmaw")
    _check(have >= int(counts[0]) and have <= int(counts[1]), "A defeated boss gives its material (%d)" % have)
    # Forging a unique.
    var base: String = BOSS.entry("boss_gnashmaw")[8][0]
    var recipe: Array = CRAFT.recipe("bossforge:" + base)
    me.progression.professions["smithing"] = PRO.max_xp()
    me.global_position = world.trade.merchant_position("merchant_brookhaven") + Vector2(-14, 0)
    world.terrain.ensure_props_at(me.global_position)
    var made := false
    var items_before: int = me.gear.items.size()
    for _try in range(4):
        for ingredient in recipe[3]:
            bag.add_material(ingredient, int(recipe[3][ingredient]))
        if me.craft("bossforge:" + base):
            made = true
            break
    var forged: Array = me.gear.items.filter(func(item): return item.base == base)
    _check(made and me.gear.items.size() > items_before and not forged.is_empty() and int(forged[0].rarity) >= int(GEAR.BASES[base].min_rarity), "Forged %s from %s" % [GEAR.BASES[base].name, LOOT.name_of(LOOT.material("boss_gnashmaw"))])
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Boss drop checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
