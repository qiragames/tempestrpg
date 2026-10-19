extends SceneTree
## "If it's there, it works" (user SVE recording 2026-10-19): every tree is chopped, every rock and
## pebble mined, every glowing mushroom picked, and none of them can be walked through — the
## world's props, the First Clearing's own trees and rocks, and the camp's deposits. Every water
## can be fished; small water only holds small fish, lakes up to Epic, the sea everything, and
## the biggest lake (Mirror Lake) its own Glasswater Wyrm.
const TERRAIN := preload("res://scripts/world/world_terrain.gd")
const PRO := preload("res://scripts/professions/profession_catalogue.gd")
const FISHES := preload("res://scripts/professions/fish_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const LAYOUT := preload("res://scripts/world/world_layout.gd")
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

## Can the character take a 2 px step from where it stands into `rect` (a body's footprint)?
func _blocked(actor: CharacterBody2D, from: Vector2, to: Vector2) -> bool:
    actor.global_position = from
    return actor.test_move(actor.global_transform, to - from)

func _run() -> void:
    # --- Every natural prop is workable and solid.
    var natural_ok := true
    var bad: Array = []
    for kind in TERRAIN.PROPS:
        var looks_natural: bool = kind.begins_with("tree") or kind.begins_with("pine") or kind in ["bamboo", "palm"] or kind.begins_with("boulder") or kind == "pebbles"
        if not looks_natural:
            continue
        var workable: bool = kind in PRO.TREE_PROPS or kind in PRO.ROCK_PROPS
        var solid: bool = TERRAIN.PROPS[kind][2].x > 0 and TERRAIN.PROPS[kind][2].y > 0
        if not workable or not solid:
            bad.append(kind)
    _check(bad.is_empty(), "Every tree, rock and pebble kind is workable and solid (%s)" % ", ".join(bad))
    _check("mushroom_glow" in PRO.HERB_PROPS and PRO.resource_for("mushroom_glow", "Gloomveil", 3) == "herb_glowcap" and PRO.resource_for("mushroom_glow", "Thornwood", 3) == "herb_glowcap", "Glowing mushrooms are picked for Glowcap everywhere")
    _check(PRO.ORES.has(PRO.resource_for("pebbles", "Cinder Crater", 5)), "Pebbles are mined for that region's ore")
    _check(preload("res://scripts/professions/crafting_catalogue.gd").POTIONS.potion_glowcap[6].has("herb_glowcap"), "Glowcap is brewed into a Glowcap Tonic")
    # --- In the world.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-res-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24871, dir.path_join("res.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var nodes: Node = world.nodes
    # The clearing's decorations are nodes.
    var decor: Dictionary = world.decor_nodes
    _check(decor.size() == world.layout.trees.size() + world.layout.rocks.size() and decor.keys().all(func(index): return not nodes.info(index).is_empty()), "Every tree and rock of the clearing is a resource node (%d)" % decor.size())
    var tree_index := -1
    var tree_foot: Vector2 = decor[tree_index][1]
    me.global_position = nodes.work_point(tree_index) + Vector2(0, 6)
    await _frames(2)
    _check(nodes.nearest(me) == tree_index, "Standing at a clearing tree, F finds it")
    _check(session.apply_action(me, "node", {"index": tree_index}) and me.gather_id == "node:%d" % tree_index, "F at a clearing tree starts chopping it")
    var logs_before: int = me.get_node("Inventory").total_units()
    me.progression.professions.woodcutting = PRO.xp_for(30)
    for _second in range(40):
        await _frames(20)
        if not nodes.intact(tree_index):
            break
        if me.gather_id.is_empty():
            session.apply_action(me, "node", {"index": tree_index})
    _check(me.get_node("Inventory").total_units() > logs_before and not nodes.intact(tree_index), "The clearing tree gives logs until it is a stump")
    var holder: Node2D = decor[tree_index][2]
    var marks: Node2D = holder.get_node_or_null("Marks")
    _check(marks != null and marks.depleted and not holder.get_children().any(func(child): return child is Sprite2D and child.visible), "The felled clearing tree shows a stump")
    _check(_blocked(me, tree_foot + Vector2(0, 12), tree_foot - Vector2(0, 8)), "A clearing tree (even a stump) cannot be walked through")
    var rock_index := -1001
    _check(PRO.ORES.has(nodes.info(rock_index).resource), "A clearing rock is mined for ore")
    var rock_body: StaticBody2D = decor[rock_index][2]
    _check(_blocked(me, rock_body.global_position + Vector2(0, 26), rock_body.global_position), "A clearing rock cannot be walked through")
    # Camp deposits are solid but still worked from close by.
    var camp: Node = world.camp
    var solid_ok := true
    var reach_ok := true
    for id in camp.sites:
        var point: Vector2 = camp.sites[id].position
        if not _blocked(me, point + Vector2(0, 30), point + Vector2(0, 2)):
            solid_ok = false
        me.global_position = point + Vector2(0, 22)
        if not camp.can_reach(me, point, 36):
            reach_ok = false
    _check(solid_ok, "No camp deposit can be walked through")
    _check(reach_ok, "Deposits are still in reach from in front of them")
    # --- Water.
    var pond_tile: Vector2i = MAP.to_tile(LAYOUT.POND.get_center())
    _check(FISHES.water_body(pond_tile, "The First Clearing") == "puddle", "The clearing's pond is small water")
    var lake_tile: Vector2i = Vector2i(MAP.LAKE[0] + Vector2(-14, 0))
    _check(FISHES.water_body(lake_tile, "Mirror Lake") == "great_lake", "Mirror Lake is the great lake")
    var other_lake: Vector2i = Vector2i(MAP.LAKES[0][0])
    _check(FISHES.water_body(other_lake, "Frostpeak") == "lake", "Other lakes are lakes")
    _check(FISHES.water_body(Vector2i(330, 160), "The Sapphire Sea") == "sea", "The open sea is the sea")
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var puddle_top := 0
    var lake_top := 0
    var wyrm_lake := false
    var wyrm_elsewhere := false
    for draw in range(4000):
        puddle_top = maxi(puddle_top, int(FISHES.FISH[FISHES.pick("The First Clearing", true, 7, 50, rng, false, "clear", "puddle")][4]))
        lake_top = maxi(lake_top, int(FISHES.FISH[FISHES.pick("Frostpeak", true, 7, 50, rng, false, "clear", "lake")][4]))
        if FISHES.pick("Mirror Lake", true, 7, 50, rng, false, "clear", "great_lake") == "glasswater_wyrm":
            wyrm_lake = true
        if FISHES.pick("Mirror Lake", true, 7, 50, rng, false, "clear", "lake") == "glasswater_wyrm":
            wyrm_elsewhere = true
    _check(puddle_top <= 1, "Small water: Common and Uncommon fish only")
    _check(lake_top <= 3, "Lakes: up to Epic")
    _check(wyrm_lake and not wyrm_elsewhere, "The Glasswater Wyrm bites only in the great lake")
    # Casting at the pond from its shore (the water is a little way off).
    me.global_position = Vector2(LAYOUT.POND.get_center().x, LAYOUT.POND.end.y + 14)
    me.facing = Vector2.UP
    me.fishing_bite_in = -INF
    _check(not me.water_ahead().is_empty() and me.cast_line() and me._fishing_body == "puddle", "F at the clearing's pond casts the line (small water)")
    me.fishing_bite_in = -INF
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("World resource checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
