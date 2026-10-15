extends SceneTree
## Dungeons and hidden elites (M7c): five caves in the hidden Underdeep (rooms joined by bridges,
## creatures, an end boss, a rich chest), cave mouths and ways out (F), the map showing only the
## dungeon inside one; ten hidden elites discovered on approach with a guaranteed Rare+ drop.
const DUNGEONS := preload("res://scripts/dungeons/dungeon_catalogue.gd")
const BOSS := preload("res://scripts/bosses/boss_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const REGION := preload("res://scripts/world/region_content.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
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

## Walkable tiles reachable from `start` inside a rect (4-neighbour flood).
func _reachable(start: Vector2i, area: Rect2i) -> Dictionary:
    var seen := {start: true}
    var queue: Array = [start]
    while not queue.is_empty():
        var tile: Vector2i = queue.pop_back()
        for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            var next: Vector2i = tile + step
            if seen.has(next) or not area.has_point(next) or MAP.solid(next.x, next.y):
                continue
            seen[next] = true
            queue.append(next)
    return seen

func _run() -> void:
    # Catalogue and map.
    _check(DUNGEONS.ORDER.size() == 5 and BOSS.ELITES.size() == 10 and BOSS.DUNGEON_BOSSES.size() == 5, "Five dungeons with end bosses and ten hidden elites")
    var all_ok := true
    for id in DUNGEONS.ORDER:
        var rooms: Array = DUNGEONS.rooms(id)
        var reach := _reachable(Vector2i(DUNGEONS.entry_tile(id)), DUNGEONS.view(id))
        for room in rooms:
            all_ok = all_ok and DUNGEONS.in_strip(Vector2i(room[0])) and reach.has(Vector2i(room[0])) and MAP.region_at(MAP.to_world(room[0])) == MAP.Region.UNDERDEEP
        all_ok = all_ok and reach.has(Vector2i(DUNGEONS.chest_tile(id))) and DUNGEONS.view(id).has_point(Vector2i(DUNGEONS.exit_tile(id)))
        for creature in DUNGEONS.creatures(id):
            all_ok = all_ok and reach.has(Vector2i(creature[2])) and creature[4] >= DUNGEONS.DUNGEONS[id][3][0] and creature[4] <= DUNGEONS.DUNGEONS[id][3][1]
        all_ok = all_ok and not MAP.WORLD_VIEW.has_point(Vector2i(rooms[0][0])) and not MAP.REALM_RECT.has_point(Vector2i(rooms[0][0]))
        var mouth: Vector2 = DUNGEONS.DUNGEONS[id][2]
        all_ok = all_ok and not MAP.solid(int(mouth.x), int(mouth.y)) and MAP.region_name(MAP.to_world(mouth)) == DUNGEONS.DUNGEONS[id][1]
    _check(all_ok, "Every room, creature and chest is reachable over the bridges, hidden from the normal maps; every cave mouth stands in its region")
    _check(REGION.level_of("dg_ember_depths_1_1", 1) == DUNGEONS.creature_level("dg_ember_depths_1_1") and REGION.all_creatures().any(func(entry): return entry[0] == "dg_jade_grotto_2_3"), "Dungeon creatures are world creatures with their own levels")
    var elites_ok := true
    for id in BOSS.ELITES:
        var tile: Vector2 = BOSS.ELITES[id][3]
        elites_ok = elites_ok and not MAP.solid(int(tile.x), int(tile.y)) and MAP.WORLD_VIEW.has_point(Vector2i(tile)) or MAP.REALM_RECT.has_point(Vector2i(tile))
    _check(elites_ok, "Hidden elites stand on open ground")
    # A world.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-dungeon-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24803, dir.path_join("dungeon.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    var gates: Node = world.dungeon_gates
    _check(get_nodes_in_group("raid_bosses").size() == BOSS.all_ids().size(), "Raid bosses, elites and dungeon bosses all stand in the world")
    var rootmaw: Node2D = world.entity_by_id(DUNGEONS.boss_id("thornwood_hollow"))
    _check(rootmaw != null and rootmaw.level == 12 and rootmaw.get_node("Health").maximum < world.entity_by_id("boss_gnashmaw").get_node("Health").maximum, "Rootmaw guards Thornwood Hollow: an elite, weaker than a raid boss")
    # In and out.
    actor.global_position = gates.mouth_position("thornwood_hollow") + Vector2(0, 10)
    await _frames(2)
    _check(gates.nearest(actor) == ["enter", "thornwood_hollow"], "F at the cave mouth offers to go in")
    _check(not session.apply_action(actor, "dungeon", {"operation": "enter", "id": "frostfang_cavern"}), "Only the cave you stand at")
    _check(session.apply_action(actor, "dungeon", {"operation": "enter", "id": "thornwood_hollow"}) and MAP.dungeon_at(actor.global_position) == "thornwood_hollow" and MAP.place_name(actor.global_position) == "Thornwood Hollow", "Going in puts you in the entry room")
    var hud: CanvasLayer = world.get_node("HUD")
    await _frames(2)
    _check(world.sky.ambient.color.is_equal_approx(world.sky.CAVE_TINT), "It is darker underground")
    hud.world_map.open()
    await _frames(2)
    _check(hud.world_map._zone_rect() == DUNGEONS.view("thornwood_hollow") and not hud.world_map._shown(Vector2(190, 116)), "Inside, the map shows only the dungeon")
    hud.world_map.close()
    actor.global_position = gates.exit_position("thornwood_hollow") + Vector2(0, 10)
    await _frames(2)
    _check(gates.nearest(actor) == ["leave", "thornwood_hollow"] and session.apply_action(actor, "dungeon", {"operation": "leave", "id": "thornwood_hollow"}) and MAP.dungeon_at(actor.global_position).is_empty() and MAP.region_name(actor.global_position) == "Thornwood", "The way out takes you back to the cave mouth")
    await _frames(2)
    _check(not world.sky.ambient.color.is_equal_approx(world.sky.CAVE_TINT), "Daylight again")
    # The chest in the boss chamber is rich.
    _check(REGION.is_rich_chest(DUNGEONS.chest_id("jade_grotto")) and world.layout.chests.any(func(chest): return chest.id == DUNGEONS.chest_id("jade_grotto")), "Every boss chamber holds a rich chest")
    # Hidden elites: discovery and a guaranteed Rare+ drop.
    actor.global_position = BOSS.centre("elite_oakfang") + Vector2(BOSS.DISCOVER_RADIUS - 20, 0)
    world.terrain.ensure_props_at(actor.global_position)
    world._discover_spots()
    _check("elite_oakfang" in actor.progression.get("elites", []), "Coming near a hidden elite marks it on your map")
    var oakfang: Node2D = world.entity_by_id("elite_oakfang")
    actor.progression.level = 20
    actor.progression.experience = LEVELING.xp_for_level(20)
    actor.progression.skill_points = 20
    actor.global_position = BOSS.centre("elite_oakfang") + Vector2(30, 0)
    await _frames(8)
    var items: int = actor.gear.items.size()
    var health: Node = oakfang.get_node("Health")
    health.immunity_left = 0.0
    health.take_damage(health.current + 5, actor)
    await _frames(8)
    var drops: Array = get_nodes_in_group("gear_pickups").filter(func(pickup): return pickup.owner_id == actor.character_id).map(func(pickup): return pickup.item)
    if actor.gear.items.size() > items:
        drops.append(actor.gear.items[-1])
    _check(oakfang.state == oakfang.State.DEFEATED and drops.size() == 1 and int(drops[0].rarity) >= 2, "A hidden elite's personal drop is Rare or better")
    _check(world.respawner.pending.filter(func(entry): return entry.id == "elite_oakfang")[0].remaining > BOSS.ELITE_RESPAWN - 5.0, "Elites return after 10 minutes")
    # Saves: elites known, content present, older worlds upgraded.
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("dungeon.json")))
    _check(int(raw.version) == STORE.VERSION and raw.players.host.progression.elites == ["elite_oakfang"], "Known elites are saved")
    var bad: Dictionary = raw.duplicate(true)
    bad.players.host.progression.elites = ["not_an_elite"]
    _check(not STORE.validate(bad), "Unknown elites are rejected")
    var old: Dictionary = raw.duplicate(true)
    old.version = 34
    old.enemies = old.enemies.filter(func(enemy): return not String(enemy.id).begins_with("dg_") and not String(enemy.id).begins_with("elite_") and not String(enemy.id).begins_with("dungeon_"))
    old.respawns = old.respawns.filter(func(entry): return not String(entry.id).begins_with("elite_"))
    var migrated: Variant = STORE.migrate(old)
    _check(migrated is Dictionary and migrated.enemies.any(func(enemy): return enemy.id == "dg_gloom_catacombs_2_2") and migrated.enemies.any(func(enemy): return enemy.id == "dungeon_jade_grotto") and migrated.enemies.any(func(enemy): return enemy.id == "elite_rex_alpha") and STORE.validate(migrated), "v34 worlds get the dungeons and elites")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Dungeon checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
