extends SceneTree
## Professions (M6a): trees and ore rocks of the world are resource nodes; working them levels
## Woodcutting and Mining (1–50, soft gates with a shown chance), fills the bag with logs, ores and
## gems, empties the node into a stump or rubble until it grows back; saves keep the experience.
const PRO := preload("res://scripts/professions/profession_catalogue.gd")
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

func _run() -> void:
    # Rules.
    _check(PRO.level_for(0) == 1 and PRO.level_for(PRO.max_xp()) == 50 and PRO.level_for(PRO.xp_for(10)) == 10 and PRO.level_for(PRO.xp_for(10) - 1) == 9, "Levels 1-50 follow the curve")
    _check(is_equal_approx(PRO.chance(1, 1), 0.70) and PRO.chance(1, 40) == 0.05 and PRO.chance(50, 1) == 0.98 and PRO.chance(5, 10) < PRO.chance(10, 10), "Soft gates: 70% at the level, less below (never zero), more above")
    _check(PRO.work_seconds(1.0, 1, 30) > PRO.work_seconds(1.0, 30, 30) and PRO.work_seconds(1.0, 50, 1) < 0.7, "Below the level work is slower; higher levels work faster")
    var regions_ok := true
    for table in [PRO.WOODS, PRO.ORES]:
        for id in table:
            for region in table[id][5]:
                regions_ok = regions_ok and region in preload("res://scripts/world/world_map.gd").REGION_NAMES.values()
    _check(regions_ok, "Every wood and ore grows in real regions")
    _check(PRO.resource_for("boulder", "The Ki Realm", 3) in ["ore_adamantite", "ore_starmetal"] and PRO.resource_for("tree_dead", "Mirewood Marsh", 9) == "log_bogwood", "Regions decide the resource")
    var trade := preload("res://scripts/trade/trade_catalogue.gd")
    _check(trade.is_good("ore_mithril") and trade.price("ore_mithril") > trade.price("ore_copper") and trade.sell_price(trade.price("gem_diamond")) >= PRO.GEMS.gem_diamond[1], "Logs, ores and gems are bag goods merchants buy")
    # A world: chop a tree, mine a rock.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-pro-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24792, dir.path_join("pro.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    var nodes: Node = world.nodes
    var plan: Array = world.terrain.planned_props()
    var tree := -1
    var rock := -1
    for index in range(plan.size()):
        var info: Dictionary = nodes.info(index)
        if tree < 0 and info.get("resource") == "log_oak":
            tree = index
        if rock < 0 and info.get("resource") == "ore_copper":
            rock = index
        if tree >= 0 and rock >= 0:
            break
    _check(tree >= 0 and rock >= 0, "The world has oak trees and copper rocks")
    actor.global_position = nodes.work_point(tree) + Vector2(0, 6)
    world.terrain.ensure_props_at(actor.global_position)
    await _frames(2)
    _check(nodes.nearest(actor) == tree, "The tree is the nearest node")
    var prompt: Array = nodes.prompt(actor, tree)
    _check(String(prompt[0]).contains("Oak Log") and String(prompt[0]).contains("%"), "The prompt names the wood and shows the chance (%s)" % prompt[0])
    _check(session.apply_action(actor, "node", {"index": tree}) and actor.gather_id == "node:%d" % tree, "F at the tree starts chopping")
    var bag: Node = actor.get_node("Inventory")
    for _i in range(60 * 30):
        await physics_frame
        if actor.gather_id.is_empty():
            break
    _check(actor.gather_id.is_empty() and not nodes.intact(tree), "The tree is felled after its logs are taken")
    _check(int(actor.progression.professions.woodcutting) > 0 and bag.total_units() >= 4, "Woodcutting XP and logs in the bag (%d units)" % bag.total_units())
    var holder: Node2D = world.terrain.spawned_prop(tree)
    _check(holder != null and holder.get_node_or_null("Marks") != null and holder.get_node("Marks").depleted, "The felled tree shows a stump")
    _check(not session.apply_action(actor, "node", {"index": tree}), "A stump cannot be chopped")
    nodes.regrow[tree] = 0.01
    await _frames(3)
    _check(nodes.intact(tree), "The tree grows back")
    # Mining with a gem; a weak character on a hard rock is slow and fails more.
    actor.global_position = nodes.work_point(rock) + Vector2(0, 6)
    world.terrain.ensure_props_at(actor.global_position)
    await _frames(2)
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    var mined := 0
    for _i in range(40):
        if not nodes.strike(actor, rock, rng):
            break
        mined += 1
    _check(int(actor.progression.professions.mining) > 0 and not nodes.intact(rock), "Mining a copper rock until it breaks")
    _check(nodes.success_chance(actor, rock) > 0.6, "Copper is easy at level 1")
    # Network snapshot round trip.
    var state: Dictionary = nodes.state()
    nodes.reset()
    _check(nodes.intact(rock), "Reset regrows everything")
    nodes.apply(state)
    _check(not nodes.intact(rock), "Snapshots carry broken rocks")
    # Saves keep profession experience; v31 saves migrate.
    var xp: int = int(actor.progression.professions.woodcutting)
    _check(session.save_world() == OK, "World saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("pro.json")))
    _check(int(raw.version) == STORE.VERSION and int(raw.players.host.progression.professions.woodcutting) == xp and int(raw.players.host.inventory.capacity) == 100, "Saves keep profession XP and the 100-unit bag")
    var old: Dictionary = raw.duplicate(true)
    old.version = 31
    for state_entry in old.players.values():
        state_entry.progression.erase("professions")
        state_entry.inventory.capacity = 20
    var migrated: Variant = STORE.migrate(old)
    _check(migrated is Dictionary and int(migrated.version) == STORE.VERSION and migrated.players.host.progression.professions.size() == 5 and int(migrated.players.host.inventory.capacity) == 100, "v31 saves get professions and bigger bags")
    # The window (L): levels, chances per wood and ore.
    var hud: CanvasLayer = null
    for child in world.get_children():
        if child is CanvasLayer and child.get("professions_panel") != null:
            hud = child
    _check(hud != null, "The HUD has the professions window")
    if hud != null:
        var panel: Control = hud.professions_panel
        panel.open()
        await _frames(1)
        _check(panel.visible and panel._entries("woodcutting").size() == PRO.WOODS.size(), "L opens the window with every wood")
        panel._select("mining")
        _check(panel._entries("mining").size() == PRO.ORES.size() and panel._tabs[1].text.contains("Lv"), "Mining tab lists every ore")
        panel.close_panel()
        _check(not panel.visible and not paused, "The window closes and the game runs again")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Professions checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
