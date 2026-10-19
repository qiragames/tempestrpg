extends SceneTree
## SVE playtest fixes (after v1.2): the first quest counts creatures anywhere, double XP up to
## level 5, starter tools (and the v42 migration that hands them out), Shift sprint with its
## stamina meter, the log box (smaller/bigger, 30 lines to scroll back), the equipment stats in
## two columns and "Boots", the world map inside its frame with labels that never overlap, the
## house and boulder art, and classless characters using weapons up to Rare.
const STORE := preload("res://scripts/persistence/save_store.gd")
const QUESTS := preload("res://scripts/quests/quest_catalogue.gd")
const TERRAIN := preload("res://scripts/world/world_terrain.gd")
const CLASSES := preload("res://scripts/progression/class_catalogue.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const MAP_PANEL := preload("res://scripts/ui/world_map_panel.gd")
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

func _run() -> void:
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-sve-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24851, dir.path_join("sve.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var hud: CanvasLayer = world.get_node("HUD")
    # --- The first quest counts creatures defeated anywhere around the clearing.
    var first: Dictionary = QUESTS.QUESTS.main_0.steps[0]
    _check(first.type == "kill" and String(first.region).is_empty() and int(first.count) == 3, "The first quest's kill step is not tied to the First Clearing")
    # --- Double XP up to level 5 (the real values come back before saving).
    var kept: Dictionary = me.progression.duplicate(true)
    me.progression["level"] = 2
    me.progression["experience"] = preload("res://scripts/progression/leveling.gd").xp_for_level(2)
    var before: int = int(me.progression.experience)
    me.gain_experience(10, "test")
    _check(int(me.progression.experience) - before == 20, "Below level 6 experience counts double")
    me.progression["level"] = 9
    me.progression["experience"] = preload("res://scripts/progression/leveling.gd").xp_for_level(9)
    before = int(me.progression.experience)
    me.gain_experience(10, "test")
    _check(int(me.progression.experience) - before == 10, "From level 6 on experience is the usual amount")
    # --- Starter tools.
    var fresh = load("res://scenes/player/player.tscn").instantiate()
    _check(fresh.progression.tools == {"axe": 1, "pickaxe": 1, "rod": 1}, "New characters carry a basic axe, pickaxe and fishing rod")
    fresh.free()
    # --- Sprint and stamina.
    me.global_position = Vector2(480, 340)
    me.input_blocked = false
    Input.action_press("move_right")
    await _frames(2)
    var walk: float = me.velocity.length()
    Input.action_press("sprint")
    await _frames(2)
    var run: float = me.velocity.length()
    _check(walk > 0.0 and absf(run / walk - me.SPRINT_FACTOR) < 0.01 and me.sprinting, "Shift sprints 60% faster")
    _check(me.stamina < 1.0, "Sprinting uses stamina")
    Input.action_release("sprint")
    Input.action_release("move_right")
    await _frames(1)
    me.stamina = 1.0
    me._winded = false
    for _second in range(5):
        me._run_stamina(1.0, true)
    _check(me.stamina == 0.0 and not me.sprinting and me._winded, "Five seconds empty the stamina")
    me._run_stamina(0.5, true)
    _check(not me.sprinting, "An empty meter cannot sprint until it has refilled a little")
    me._run_stamina(0.5, false)
    me._run_stamina(0.1, true)
    _check(me.sprinting, "After a short rest sprinting works again")
    me.stamina = 0.0
    me._winded = false
    for _second in range(4):
        me._run_stamina(1.0, false)
    _check(me.stamina == 1.0, "Four seconds refill the stamina")
    _check(InputMap.has_action("sprint") and InputMap.action_get_events("sprint").any(func(event): return event is InputEventKey and event.physical_keycode == KEY_SHIFT), "Sprint is on Shift")
    _check(preload("res://scripts/ui/input_setup.gd").REBINDABLE.any(func(entry): return entry[0] == "sprint"), "Sprint can be rebound")
    # --- The log box.
    for index in range(40):
        hud.record_event("Line %d" % index)
    _check(hud._events.size() == hud.LOG_HISTORY and hud._log.get_parsed_text().contains("Line 39") and not hud._log.get_parsed_text().contains("Line 9\n"), "The log keeps the last 30 lines to scroll through")
    _check(hud._log.scroll_active and hud._log.mouse_filter == Control.MOUSE_FILTER_STOP, "The log scrolls with the mouse wheel")
    hud._log_less.pressed.emit()
    _check(hud.log_mode == hud.LOG_MINI and not hud._log.visible and hud._log_less.disabled and hud._log_title.visible, "- shrinks the log to its title bar")
    hud._log_more.pressed.emit()
    hud._log_more.pressed.emit()
    _check(hud.log_mode == hud.LOG_TALL and hud._log.visible and hud._log_more.disabled and hud._log_back.size.y > 150, "+ grows the log (normal, then tall)")
    hud.set_log_mode(hud.LOG_NORMAL)
    _check(hud._log_back.position.y + hud._log_back.size.y == 338.0, "The log's bottom edge stays put")
    # --- Equipment stats in two columns; "Boots".
    _check(hud.gear_panel.SLOT_NAMES.feet == "Boots" and preload("res://scripts/ui/item_card.gd").SLOT_TYPES.feet == "Boots", "The feet slot is called Boots")
    hud.gear_panel.open()
    await _frames(2)
    var box: Rect2 = hud.gear_panel.get_node("StatsBox").get_rect()
    var columns: Array = [hud.gear_panel._stats, hud.gear_panel._stats_values, hud.gear_panel._stats_2, hud.gear_panel._stats_2_values]
    _check(columns.all(func(label): return box.encloses(label.get_rect()) and label.get_line_count() <= 4), "Every stat fits inside the stats box (two columns of at most four)")
    _check(hud.gear_panel._stats_2.text.contains("Regen"), "Regeneration is shown in the box")
    hud.gear_panel.close()
    await _frames(1)
    # --- The world map.
    _check(Rect2(MAP_PANEL.FRAME).encloses(Rect2(MAP_PANEL.IMAGE_AT, MAP_PANEL.CANVAS_SIZE)), "The map canvas lies inside its frame")
    hud.world_map.open()
    await _frames(3)
    var placed: Array = hud.world_map._placed
    var overlap := false
    for a in range(placed.size()):
        for b in range(a + 1, placed.size()):
            if placed[a].intersects(placed[b]):
                overlap = true
    var inside: bool = placed.all(func(rect): return Rect2(Vector2.ZERO, hud.world_map._canvas.size).encloses(rect))
    _check(placed.size() >= 10 and not overlap and inside, "Map labels are placed without overlapping, all inside the map (%d)" % placed.size())
    hud.world_map.zoom_at(hud.world_map._canvas.size / 2.0, 4.0)
    await _frames(2)
    placed = hud.world_map._placed
    overlap = false
    for a in range(placed.size()):
        for b in range(a + 1, placed.size()):
            if placed[a].intersects(placed[b]):
                overlap = true
    _check(not overlap, "Zoomed in, the labels still never overlap")
    hud.world_map.close()
    # --- Props.
    _check(TERRAIN.PROPS.house_a[1] == Rect2(0, 0, 64, 48), "The house art is drawn whole (64 px wide)")
    _check(TERRAIN.PROPS.boulder[2].y >= 20 and TERRAIN.PROPS.boulder_snow[2].y >= 18, "Boulders block more than their bottom edge")
    # --- Classless weapons up to Rare (level and attributes still count).
    var rng := RandomNumberGenerator.new()
    rng.seed = 12
    var classless := {"level": 60, "classes": {"main": "", "sub": ""}}
    var sword_rare: Dictionary = GEAR.roll("iron_sword", 2, rng)
    var sword_epic: Dictionary = GEAR.roll("iron_sword", 3, rng)
    _check(CLASSES.problem(classless, sword_rare).is_empty(), "A classless character can use a Rare weapon")
    _check(CLASSES.problem(classless, sword_epic).begins_with("Choose a class"), "Above Rare needs a class")
    var low := {"level": 1, "classes": {"main": "", "sub": ""}}
    var high_rare: Dictionary = GEAR.roll("iron_sword", 2, rng)
    var needs: int = int(CLASSES.requirements(high_rare).level)
    _check(needs <= 1 or CLASSES.problem(low, high_rare).begins_with("Needs level"), "The weapon's level still applies")
    # --- Saves: v42 hands existing characters the basic tools.
    me.progression = kept
    me.progression.tools = {"axe": 0, "pickaxe": 3, "rod": 0}
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("sve.json")))
    _check(int(raw.version) == STORE.VERSION and STORE.validate(raw), "The save is current")
    var old: Dictionary = raw.duplicate(true)
    old.version = 41
    var migrated: Variant = STORE.migrate(old)
    var tools: Dictionary = migrated.players.host.progression.tools if migrated is Dictionary else {}
    _check(migrated is Dictionary and int(migrated.version) == STORE.VERSION and int(tools.axe) == 1 and int(tools.rod) == 1 and int(tools.pickaxe) == 5 and STORE.validate(migrated), "v41 characters get the basic tools; better ones stay (Master becomes Gold, v43)")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("SVE fix checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
