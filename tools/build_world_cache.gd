extends SceneTree
## Rebuilds assets/game/world/world_cache.bin (WorldCache): the map masks, collision rectangles,
## terrain tile layers, prop plan and world-map picture, computed from the current sources.
## Run after changing world_map.gd, world_terrain.gd, world_layout.gd or region_content.gd:
##   godot --headless --path . --script tools/build_world_cache.gd
const MAP := preload("res://scripts/world/world_map.gd")
const TERRAIN := preload("res://scripts/world/world_terrain.gd")
const CACHE := preload("res://scripts/world/world_cache.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var started := Time.get_ticks_msec()
    MAP.use_cache = false
    MAP._cache = {}
    MAP._rects = []
    TERRAIN._layer_cache = {}
    TERRAIN._prop_cache = []
    TERRAIN._chunks = {}
    CACHE.reset()
    var map: Dictionary = MAP.data()
    var rects: Array = MAP.solid_rects()
    print("map + collisions: %d ms (%d rectangles)" % [Time.get_ticks_msec() - started, rects.size()])
    var terrain = TERRAIN.new()
    root.add_child(terrain)
    var layers := {}
    for layer in [terrain.ground, terrain.blend, terrain.canopy, terrain.heights, terrain.cliffs, terrain.features, terrain.bridges]:
        layers[layer.name] = layer.tile_map_data
    print("layers + props: %d ms (%d props)" % [Time.get_ticks_msec() - started, TERRAIN.planned_props().size()])
    var picture: Image = preload("res://scripts/ui/world_map_panel.gd").image()
    var error := CACHE.save({"map": map, "rects": rects, "layers": layers, "props": TERRAIN.planned_props(), "image": picture.save_png_to_buffer()})
    print("world cache %s: %s (%d ms)" % ["written" if error == OK else "FAILED (%d)" % error, CACHE.PATH, Time.get_ticks_msec() - started])
    terrain.queue_free()
    quit(0 if error == OK else 1)
