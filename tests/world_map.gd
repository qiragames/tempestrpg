extends SceneTree
## The world (M4.5a, grown about 9x in M4.5c): identical map on every machine (and a current
## precomputed cache), the clearing unchanged inside it, coasts and bridges, the home continent on
## foot and the ferry lands by ferry, region names, terrain layers and streamed props, save
## position bounds, camera limits and the world map window.
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
func _reachable(start: Vector2i, extra: Array = []) -> PackedByteArray:
    var seen := PackedByteArray()
    seen.resize(MAP.COLS * MAP.ROWS)
    var queue: Array = [start] + extra
    for tile in queue:
        seen[MAP.tile_index(tile.x, tile.y)] = 1
    var head := 0
    while head < queue.size():
        var tile: Vector2i = queue[head]
        head += 1
        for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            var next: Vector2i = tile + step
            if not MAP.in_grid(next):
                continue
            var index := MAP.tile_index(next.x, next.y)
            if seen[index] == 0 and not MAP.solid(next.x, next.y):
                seen[index] = 1
                queue.append(next)
    return seen

func _run() -> void:
    # --- Determinism and layout
    var second: Dictionary = MAP.data()
    var fresh: Dictionary = MAP.compute()
    var same := true
    for key in fresh:
        same = same and fresh[key] == second[key]
    _check(same, "The world map is identical every time it is built (same on host and friends)")
    _check(preload("res://scripts/world/world_cache.gd").current(), "The precomputed world cache matches the current sources (rebuild: tools/build_world_cache.gd)")
    _check(MAP.bounds().encloses(Rect2(0, 0, 960, 640)) and MAP.to_world(Vector2(MAP.CLEARING.position)) == Vector2.ZERO, "The First Clearing keeps its exact coordinates inside the archipelago")
    _check(MAP.bounds().size == Vector2(46400, 12288), "The world is 46400 x 12288 pixels: the archipelago, the Eastern Reaches and the Ki Realm continent")
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
    var home := true
    for town in ["rimeholm", "dunemarch", "brookhaven", "snowdrift", "saltpan"]:
        var at := Vector2i(MAP.town(town)[3])
        home = home and reach[MAP.tile_index(at.x, at.y)] == 1
    _check(home, "Frostpeak and the Sunscorch Desert join Verdant Isle as one walkable continent")
    var by_ferry := true
    for town in ["amberhold", "bogsend", "hanamura", "cinderport"]:
        var at := Vector2i(MAP.town(town)[3])
        by_ferry = by_ferry and reach[MAP.tile_index(at.x, at.y)] == 0
    _check(by_ferry and reach[MAP.tile_index(356, 176)] == 0, "Ambervale, Mirewood Marsh, Sakura Vale and the Emberreach Isles lie across the sea")
    var docks: Array = MAP.HARBOURS.map(func(ferry): return Vector2i(ferry[2]))
    var sealed := _reachable(MAP.to_tile(LAYOUT.SPAWN), docks)
    var arrival := Vector2i(preload("res://scripts/realm/realm_catalogue.gd").ARRIVAL_TILE)
    _check(sealed[MAP.tile_index(arrival.x, arrival.y)] == 0 and not MAP.in_realm(LAYOUT.SPAWN) and MAP.in_realm(MAP.to_world(Vector2(arrival))), "The Ki Realm cannot be reached on foot or by ferry (only through the hermit)")
    var sailing := _reachable(MAP.to_tile(LAYOUT.SPAWN), docks + [arrival])
    var every_town := true
    for town in MAP.TOWNS:
        var at := Vector2i(town[3])
        every_town = every_town and sailing[MAP.tile_index(at.x, at.y)] == 1
        if sailing[MAP.tile_index(at.x, at.y)] == 0:
            push_error("Not reachable by ferry: " + town[0])
    _check(every_town and MAP.TOWNS.size() == 41 and MAP.TOWNS.filter(func(town): return town[4] == "town").size() == 12, "With the ferries (and the hermit) every one of the 12 towns and 29 villages can be reached")
    var bridge_ok := true
    for rect in MAP.BRIDGES:
        for y in range(rect.position.y, rect.end.y):
            for x in range(rect.position.x, rect.end.x):
                bridge_ok = bridge_ok and not MAP.solid(x, y)
    _check(bridge_ok and MAP.solid(300, 85) and MAP.solid(300, 96), "Bridges are walkable; the water beside them is not")
    var crater: Vector2 = MAP.LAVA_POOLS[2][0]
    _check(MAP.solid(int(crater.x), int(crater.y)) and MAP.solid(356, 181), "Lava pools block movement")
    # --- Regions
    _check(MAP.region_name(Vector2(480, 340)) == "The First Clearing" and MAP.region_name(MAP.to_world(Vector2(346, 94))) == "Harrowmere" and MAP.region_name(MAP.to_world(Vector2(104, 84))) == "Thornwood" and MAP.region_name(MAP.to_world(Vector2(-380, -240))) == "The Sapphire Sea" and MAP.place_name(MAP.to_world(Vector2(195, -70))) == "Rimeholm" and MAP.region_name(MAP.to_world(Vector2(-120, 140))) == "Sunscorch Desert", "Region names by position")
    # --- Collisions match the solid tiles
    var rects: Array = MAP.solid_rects()
    var covered := true
    for sample in [Vector2i(-380, -240), Vector2i(300, 85), Vector2i(356, 181), Vector2i(246, 80)]:
        var centre := MAP.to_world(Vector2(sample) + Vector2(0.5, 0.5))
        var inside := false
        for rect in rects:
            inside = inside or rect.has_point(centre)
        covered = covered and inside == MAP.solid(sample.x, sample.y)
    _check(covered and rects.size() < 10000, "Water, lava and cliff collisions are merged rectangles exactly over the solid tiles (%d)" % rects.size())
    # --- Saves accept the whole world; older positions stay valid
    _check(STORE._position([-8000.0, -5000.0]) and STORE._position([100.0, 100.0]) and not STORE._position([-26000.0, 0.0]) and not STORE._position([0.0, 7000.0]), "Saved positions: anywhere in the world, nothing outside it")
    # --- Scene: terrain, props, camera, HUD region, world map window
    var started := Time.get_ticks_msec()
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var terrain: Node2D = world.terrain
    var water_tile: Array = TERRAIN.feature_for(-380, -240)
    # M7b: open sea is one tiled water background under the map, not a cell per tile.
    var sea: TextureRect = terrain.get_node_or_null("Sea")
    _check(water_tile == [TERRAIN.Source.WATER, Vector2i(1, 1)] and terrain.features.get_cell_source_id(Vector2i(-380, -240) + Vector2i(MAP.ORIGIN / MAP.TILE)) == -1 and sea != null and sea.texture != null and Rect2(sea.position, sea.size) == MAP.bounds(), "Open sea is drawn as water (the tiled sea background)")
    var keep_out := Rect2(MAP.to_world(Vector2(MAP.CLEARING.position - Vector2i(2, 2))), Vector2(MAP.CLEARING.size + Vector2i(4, 4)) * MAP.TILE)
    var props_ok: bool = TERRAIN.planned_props().size() > 4000 and terrain.props.get_child_count() > 20 and terrain.props.get_child_count() < 1500
    for prop in terrain.props.get_children():
        var tile := MAP.to_tile(prop.position - Vector2(0, 1))
        props_ok = props_ok and not keep_out.has_point(prop.position) and not MAP.solid(tile.x, tile.y)
    _check(props_ok, "Thousands of props planned, only those near characters spawned (%d of %d), none inside the clearing or in water" % [terrain.props.get_child_count(), TERRAIN.planned_props().size()])
    var landmarks := {}
    for prop in TERRAIN.planned_props():
        landmarks[prop[0]] = true
    _check(landmarks.has("ruin_hall") and landmarks.has("house_c") and landmarks.has("tower") and landmarks.has("tree_autumn") and landmarks.has("tree_dead") and landmarks.has("pine"), "Landmarks and biome props: keep ruins, town houses and tower, autumn, dead and pine trees")
    var camera: Camera2D = world.get_local_player().get_node("Camera2D")
    _check(camera.limit_left == int(MAP.bounds().position.x) and camera.limit_bottom == int(MAP.bounds().end.y), "The camera can follow you across the whole world")
    var hud = world.get_node("HUD")
    var actor = world.get_local_player()
    actor.position = MAP.to_world(Vector2(346, 94))
    await _frames(2)
    _check(hud.get_node("Title").text == "HARROWMERE", "The HUD names the region you are in")
    hud.world_map.open()
    await _frames(2)
    _check(hud.world_map.visible and paused and hud.menu_open() and hud.world_map.world_texture().get_size() == Vector2(MAP.WORLD_VIEW.size), "M opens the world map (one pixel per tile of the archipelago) and pauses solo play")
    var realm_at := Vector2i(preload("res://scripts/realm/realm_catalogue.gd").ARRIVAL_TILE)
    _check(not MAP.WORLD_VIEW.has_point(realm_at) and hud.world_map.image().get_pixelv(realm_at - MAP.MIN) != hud.world_map.COLORS.ocean and hud.world_map._title.text.ends_with("ARCHIPELAGO"), "The normal map does not show the Ki Realm (it lies beyond the archipelago's sea)")
    _check(hud.world_map.image().get_pixelv(Vector2i(5, 5)) == hud.world_map.COLORS.ocean, "The map shows the sea and land in their colours")
    # Detail and zoom (user feedback): props marked on the picture, the mouse wheel zooms in.
    var detail: Image = hud.world_map.detail_image()
    var differs := 0
    var plain: Image = hud.world_map.image()
    for prop in preload("res://scripts/world/world_terrain.gd").planned_props().slice(0, 200):
        var at := Vector2i(((Vector2(prop[1]) - MAP.ORIGIN) / MAP.TILE).floor()) - MAP.MIN
        if detail.get_pixelv(at) != plain.get_pixelv(at):
            differs += 1
    _check(differs > 100, "Trees, rocks and buildings are marked on the map (%d of 200)" % differs)
    var scale_before: float = hud.world_map._scale
    hud.world_map.zoom_at(hud.world_map._canvas.size / 2.0, 4.0)
    _check(hud.world_map.zoom == 4.0 and is_equal_approx(hud.world_map._scale, scale_before * 4.0), "The mouse wheel zooms in (4x)")
    hud.world_map.zoom_at(Vector2.ZERO, 0.01)
    _check(hud.world_map.zoom == 1.0, "…and back out to the whole map")
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
    _check(load_ms < 1500 and reloaded.terrain.props.get_child_count() > 0 and prop_count > 0, "Reloading a world reuses the built map (%d ms)" % load_ms)
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
