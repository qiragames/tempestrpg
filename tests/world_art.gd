extends SceneTree
## World tiles and props (step 20): every region is real art, props stand on their collision
## footprints, buildings appear with their state, depth sorting is on, and the art never changes
## collision geometry, IDs or layouts.
const ART := preload("res://scripts/visual/world_art.gd")
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

func _opaque(texture: Texture2D, region: Rect2) -> bool:
    var image: Image = texture.get_image()
    if image.is_compressed():
        image.decompress()
    if not Rect2(Vector2.ZERO, image.get_size()).encloses(region):
        return false
    return image.get_region(Rect2i(region)).get_used_rect().size.x > 0

func _run() -> void:
    # --- Regions
    var props_ok := true
    for id in ART.PROPS:
        props_ok = props_ok and _opaque(ART.PROPS[id][0], ART.PROPS[id][1])
    _check(props_ok, "Every prop region lies inside its sheet and holds visible pixels")
    var tiles_ok := _opaque(ART.FLOOR, ART.GRASS)
    for tuft in ART.TUFTS:
        tiles_ok = tiles_ok and _opaque(ART.FLOOR, tuft)
    for corner in [Vector2.ZERO, Vector2(2, 2)]:
        tiles_ok = tiles_ok and _opaque(ART.FLOOR, Rect2(ART.DIRT_PATCH + corner * 16, Vector2(16, 16))) and _opaque(ART.WATER, Rect2(ART.POND_PATCH + corner * 16, Vector2(16, 16)))
    _check(tiles_ok, "Grass, road and pond tiles are real tiles")
    _check(ART._steps(304, 360) == [304.0, 320.0, 336.0, 344.0] and ART._steps(0, 32) == [0.0, 16.0], "Patches cover any size exactly (the last tile ends on the edge)")
    var sprite: Sprite2D = ART.prop("tree", Vector2(100, 50))
    _check(sprite.position == Vector2(100, 50) and is_equal_approx(sprite.offset.y + sprite.texture.get_height() / 2.0, 0.0) and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "A prop's node position is its foot (bottom-centre), drawn pixel-sharp")
    sprite.free()
    # --- World
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var decorations: Node2D = world.get_node("Decorations")
    _check(world.y_sort_enabled and decorations.y_sort_enabled and world.camp.y_sort_enabled and world.trial.y_sort_enabled, "Characters, props and buildings are depth-sorted by their feet")
    for seed in [0, 4242]:
        world.apply_layout(seed, true)
        await _frames(2)
        var expected: Dictionary = LAYOUT.generate(seed)
        var rects: Array = expected.rocks.duplicate()
        for tree in expected.trees:
            rects.append(Rect2(tree + Vector2(-6, 4), Vector2(12, 12)))
        var bodies: Array = decorations.get_children()
        var geometry_ok: bool = bodies.size() == rects.size()
        var art_ok := geometry_ok
        for index in range(mini(bodies.size(), rects.size())):
            var body: StaticBody2D = bodies[index]
            var shape: RectangleShape2D = body.get_child(0).shape
            geometry_ok = geometry_ok and body.position == rects[index].get_center() and shape.size == rects[index].size
            var art: Sprite2D = body.get_child(1) if body.get_child_count() > 1 else null
            art_ok = art_ok and art != null and body.y_sort_enabled and is_equal_approx(art.global_position.y, rects[index].end.y + 2.0) and is_equal_approx(art.global_position.x, rects[index].get_center().x)
        _check(geometry_ok, "Seed %d: obstacle collisions are exactly the layout's rocks and tree trunks" % seed)
        _check(art_ok, "Seed %d: each rock and tree stands on its own collision footprint" % seed)
        var spawn_clear := true
        for rect in rects:
            spawn_clear = spawn_clear and not rect.grow(8).has_point(LAYOUT.SPAWN)
        _check(spawn_clear, "Seed %d: the spawn is not inside any prop" % seed)
    # --- Camp buildings follow the camp state
    var camp: Node2D = world.camp
    world.apply_layout(0, true)
    await _frames(2)
    _check(not camp._art.hut_1.visible and not camp._art.forge_1.visible and camp._center.name == "camp_post", "An unfounded camp shows its post and no buildings")
    var state: Dictionary = camp.state.duplicate(true)
    state.founded = true
    state.hut = true
    state.forge = true
    camp.restore(state)
    await _frames(2)
    _check(camp._art.hut_1.visible and camp._art.forge_1.visible and not camp._art.storehouse_1.visible and camp._center.name == "campfire", "Built buildings appear; a founded camp shows its fire")
    var feet_ok := true
    for id in camp.STRUCTURES:
        var structure: Dictionary = camp.STRUCTURES[id]
        feet_ok = feet_ok and is_equal_approx(camp._art[id].position.y, structure.site.y + structure.size.y / 2.0 + 2.0) and is_equal_approx(camp._art[id].position.x, structure.site.x)
    _check(feet_ok, "Each building stands on the bottom edge of its collision footprint")
    _check(not camp._shapes.hut_1.disabled and camp._shapes.storehouse_1.disabled and camp._shapes.hut_1.shape.size == camp.STRUCTURES.hut_1.size, "Building collisions still follow the rules, not the art")
    # --- Depth: a character north of a tree is drawn before it (hidden by the canopy)
    var player: CharacterBody2D = world.get_local_player()
    var tree_body: Node2D = decorations.get_child(decorations.get_child_count() - 1)
    var tree_art: Sprite2D = tree_body.get_child(1)
    player.position = tree_art.global_position - Vector2(0, 14)
    await _frames(2)
    _check(player.global_position.y < tree_art.global_position.y and tree_art.global_position.y - tree_art.texture.get_height() < player.global_position.y, "A character just behind a tree is inside its canopy and sorted before it")
    world.queue_free()
    await _frames()
    print("World art checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
