extends SceneTree
## The archipelago (M4.5a): identical map on every machine, the clearing unchanged inside it,
## coasts and bridges, which regions are reachable on foot, region names, terrain layers and
## props, save position bounds, camera limits and the world map window.
const MAP := preload("res://scripts/world/world_map.gd")
const TERRAIN := preload("res://scripts/world/world_terrain.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const LAYOUT := preload("res://scripts/world/world_layout.gd")
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

## Tiles reachable on foot from a start tile (4-neighbour flood over non-solid tiles).
func _reachable(start: Vector2i) -> PackedByteArray:
    var seen := PackedByteArray()
    seen.resize(MAP.COLS * MAP.ROWS)
    var queue: Array = [start]
    seen[MAP.tile_index(start.x, start.y)] = 1
    var head := 0
    while head < queue.size():
        var tile: Vector2i = queue[head]
        head += 1
        for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            var next: Vector2i = tile + step
            if next.x < 0 or next.y < 0 or next.x >= MAP.COLS or next.y >= MAP.ROWS:
                continue
            var index := MAP.tile_index(next.x, next.y)
            if seen[index] == 0 and not MAP.solid(next.x, next.y):
                seen[index] = 1
                queue.append(next)
    return seen

func _run() -> void:
    # --- Determinism and layout
    var first: Dictionary = MAP.data()
    var copy := {}
    for key in first:
        copy[key] = first[key].duplicate()
    MAP._cache = {}
    var second: Dictionary = MAP.data()
    var same := true
    for key in copy:
        same = same and copy[key] == second[key]
    _check(same, "The world map is identical every time it is built (same on host and friends)")
    _check(MAP.bounds().encloses(Rect2(0, 0, 960, 640)) and MAP.to_world(Vector2(MAP.CLEARING.position)) == Vector2.ZERO, "The First Clearing keeps its exact coordinates inside the archipelago")
    _check(MAP.bounds().size == Vector2(6400, 4096), "The world is 6400 x 4096 pixels (about 10 x 11 screens)")
    var clearing_ok := true
    for y in range(MAP.CLEARING.position.y, MAP.CLEARING.end.y):
        for x in range(MAP.CLEARING.position.x, MAP.CLEARING.end.x):
            clearing_ok = clearing_ok and not MAP.solid(x, y) and second.region[MAP.tile_index(x, y)] == MAP.Region.CLEARING and MAP.corners(second.ocean, x, y) == 0
    _check(clearing_ok, "The clearing is all land, never blocked by the map, and named The First Clearing")
    var road := MAP.to_tile(Vector2(480, 330))
    var pond := MAP.to_tile(LAYOUT.POND.get_center())
    _check(second.dirt[MAP.vertex_index(road.x, road.y)] == 1 and second.lake[MAP.vertex_index(pond.x, pond.y)] == 1, "The clearing's road and pond are drawn by the terrain")
    # --- Reachability on foot
    var reach := _reachable(MAP.to_tile(LAYOUT.SPAWN))
    var spots := {"Thornwood": Vector2i(104, 84), "Mirror Lake keep": Vector2i(246, 68), "Cinder Crater rim": Vector2i(256, 178), "Harrowmere": Vector2i(346, 94), "Sunfall Beach": Vector2i(186, 192)}
    var reach_ok := true
    for name in spots:
        var at: Vector2i = spots[name]
        if reach[MAP.tile_index(at.x, at.y)] == 0:
            reach_ok = false
            push_error("Not reachable: " + name)
    _check(reach_ok, "Thornwood, the Mirror Lake keep (by its bridge), Cinder Crater, Harrowmere (by bridge) and the south beach are reachable on foot")
    _check(reach[MAP.tile_index(180, 245)] == 0 and reach[MAP.tile_index(356, 176)] == 0, "Ambervale and the Emberreach Isles lie across the sea (ferries and ships later)")
    var bridge_ok := true
    for rect in MAP.BRIDGES:
        for y in range(rect.position.y, rect.end.y):
            for x in range(rect.position.x, rect.end.x):
                bridge_ok = bridge_ok and not MAP.solid(x, y)
    _check(bridge_ok and MAP.solid(300, 85) and MAP.solid(300, 96), "Bridges are walkable; the water beside them is not")
    var crater: Vector2 = MAP.LAVA_POOLS[2][0]
    _check(MAP.solid(int(crater.x), int(crater.y)) and MAP.solid(356, 181), "Lava pools block movement")
    # --- Regions
    _check(MAP.region_name(Vector2(480, 340)) == "The First Clearing" and MAP.region_name(MAP.to_world(Vector2(346, 94))) == "Harrowmere" and MAP.region_name(MAP.to_world(Vector2(104, 84))) == "Thornwood" and MAP.region_name(MAP.to_world(Vector2(20, 20))) == "The Sapphire Sea", "Region names by position")
    # --- Collisions match the solid tiles
    var rects: Array = MAP.solid_rects()
    var covered := true
    for sample in [Vector2i(10, 10), Vector2i(300, 85), Vector2i(356, 181), Vector2i(246, 80)]:
        var centre := MAP.to_world(Vector2(sample) + Vector2(0.5, 0.5))
        var inside := false
        for rect in rects:
            inside = inside or rect.has_point(centre)
        covered = covered and inside == MAP.solid(sample.x, sample.y)
    _check(covered and rects.size() < 2000, "Water and lava collisions are merged rectangles exactly over the solid tiles (%d)" % rects.size())
    # --- Saves accept the whole world; older positions stay valid
    _check(STORE._position([-2000.0, -1000.0]) and STORE._position([100.0, 100.0]) and not STORE._position([-3000.0, 0.0]) and not STORE._position([0.0, 3000.0]), "Saved positions: anywhere in the world, nothing outside it")
    # --- Scene: terrain, props, camera, HUD region, world map window
    var started := Time.get_ticks_msec()
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var terrain: Node2D = world.terrain
    var water_tile: Array = TERRAIN.feature_for(5, 5)
    _check(water_tile == [TERRAIN.Source.WATER, Vector2i(1, 1)] and terrain.features.get_cell_source_id(Vector2i(5, 5) + Vector2i(MAP.ORIGIN / MAP.TILE)) == TERRAIN.Source.WATER, "Open sea is drawn as water")
    var keep_out := Rect2(MAP.to_world(Vector2(MAP.CLEARING.position - Vector2i(2, 2))), Vector2(MAP.CLEARING.size + Vector2i(4, 4)) * MAP.TILE)
    var props_ok: bool = terrain.props.get_child_count() > 300
    for prop in terrain.props.get_children():
        var tile := MAP.to_tile(prop.position - Vector2(0, 1))
        props_ok = props_ok and not keep_out.has_point(prop.position) and not MAP.solid(tile.x, tile.y)
    _check(props_ok, "Hundreds of props, none inside the clearing or in water (%d)" % terrain.props.get_child_count())
    var landmarks := {}
    for prop in terrain.props.get_children():
        landmarks[prop.get_meta("prop")] = true
    _check(landmarks.has("ruin_hall") and landmarks.has("house_c") and landmarks.has("tower") and landmarks.has("tree_autumn") and landmarks.has("tree_dead") and landmarks.has("pine"), "Landmarks and biome props: keep ruins, town houses and tower, autumn, dead and pine trees")
    var camera: Camera2D = world.get_local_player().get_node("Camera2D")
    _check(camera.limit_left == int(MAP.ORIGIN.x) and camera.limit_bottom == int(MAP.bounds().end.y), "The camera can follow you across the whole world")
    var hud = world.get_node("HUD")
    var actor = world.get_local_player()
    actor.position = MAP.to_world(Vector2(346, 94))
    await _frames(2)
    _check(hud.get_node("Title").text == "HARROWMERE", "The HUD names the region you are in")
    hud.world_map.open()
    await _frames(2)
    _check(hud.world_map.visible and paused and hud.menu_open() and hud.world_map.map_texture != null and hud.world_map.map_texture.get_size() == Vector2(MAP.COLS, MAP.ROWS), "M opens the world map (one pixel per tile) and pauses solo play")
    _check(hud.world_map.image().get_pixelv(Vector2i(5, 5)) == hud.world_map.COLORS.ocean, "The map shows the sea and land in their colours")
    hud.world_map.close()
    _check(not paused and not hud.world_map.visible, "Closing the map resumes")
    hud.open_pause()
    hud._pause_buttons.map.pressed.emit()
    await _frames(1)
    _check(hud.world_map.visible and not hud._pause_panel.visible, "The pause menu opens the world map")
    hud.world_map.close()
    _check(await _until_pause(hud), "Closing it returns to the pause menu")
    hud.close_pause()
    var prop_count: int = terrain.props.get_child_count()
    world.queue_free()
    await _frames()
    var again := Time.get_ticks_msec()
    var reloaded: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(reloaded)
    var load_ms := Time.get_ticks_msec() - again
    _check(load_ms < 400 and reloaded.terrain.props.get_child_count() == prop_count, "Reloading a world reuses the built map (%d ms)" % load_ms)
    reloaded.queue_free()
    await _frames()
    print("World map checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)

func _until_pause(hud) -> bool:
    for _i in range(30):
        if hud._pause_panel.visible:
            return true
        await process_frame
    return false
