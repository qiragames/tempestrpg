extends SceneTree
## SVE feedback 2026-10-22: the hotbar's icons fit their slots, a repeated message becomes one
## "×N" line, the analysis box falls back to its hint, characters are shown by name (party,
## messages, status card), the camp and nation share one tabbed window, and Your House may stand
## anywhere free in the world (not in a town, on a road or by a cave mouth).
const MAP := preload("res://scripts/world/world_map.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const NAMES := preload("res://scripts/progression/character_names.gd")
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
    var dir := OS.get_temp_dir().path_join("tempestrpg-hnh-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24961, dir.path_join("hnh.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me: CharacterBody2D = world.get_local_player()
    var hud: CanvasLayer = world.get_node("HUD")
    if hud.dialog_panel.is_open():
        hud.dialog_panel.close()
    # --- Hotbar and log
    _check(hud._slots.all(func(slot): return slot.expand_icon), "Hotbar icons shrink into their slots")
    var before: int = hud._events.size()
    for _i in range(4):
        hud.record_event("No reachable defeated creature nearby.")
    _check(hud._events.size() == before + 1 and String(hud._events[-1]).contains("×4"), "Four identical messages are one line with ×4")
    hud.record_event("Something else.")
    _check(hud._events.size() == before + 2, "A different message starts a new line")
    var hint: String = world.get_node("HUD/Analysis").text
    world._analysis_changed("No reachable defeated creature nearby.")
    _check(world.get_node("HUD/Analysis").text != hint, "The analysis box shows the status")
    await create_timer(world.ANALYSIS_STATUS_SECONDS + 0.5).timeout
    _check(world.get_node("HUD/Analysis").text == hint, "…and its hint again a few seconds later")
    # --- Names
    me.progression["name"] = "Benni"
    await _frames(2)
    _check(String(hud._name.text).begins_with("Benni (") and String(hud._name.text).contains(me.race()), "The status card says Name (Race)")
    _check(NAMES.named(world, "host") == "Benni" and NAMES.named(world, "nobody_here") == "Someone", "Ids are shown as names")
    _check(hud.party_panel._who("host") == "Benni", "The party window uses names")
    # --- One window with tabs
    var camp: Node2D = world.camp
    hud.nation_panel.open()
    await _frames(2)
    _check(hud._camp_dialog.visible and not hud.nation_panel.window().visible, "Before founding, N opens the Camp tab")
    hud.nation_panel.show_tab("build")
    _check(hud._camp_dialog.visible and not hud.nation_panel.window().visible, "…and the other tabs wait for the camp")
    hud._camp_dialog.close_dialog()
    camp.state.founded = true
    camp.state.founder = "host"
    camp.state.wood = 200
    camp.state.stone = 200
    camp.state.nation.spent.wood = int(camp.state.nation.spent.get("wood", 0))
    hud.nation_panel.open()
    await _frames(2)
    _check(hud.nation_panel.window().visible and hud.nation_panel._overview.visible and not hud.nation_panel._build_page.visible, "N opens the Nation tab")
    hud.nation_panel.show_tab("build")
    await _frames(1)
    var scroll: ScrollContainer = hud.nation_panel._build_page.get_node("Buildings")
    var frame: Rect2 = hud.nation_panel.FRAME
    _check(hud.nation_panel._build_page.visible and frame.encloses(Rect2(scroll.position, scroll.size)), "The Build tab's list stays inside the window (it scrolls)")
    _check(hud.nation_panel._build_buttons.home.is_visible_in_tree(), "Your House is in the build list")
    hud.nation_panel.show_tab("camp")
    await _frames(1)
    _check(hud._camp_dialog.visible and not hud.nation_panel.window().visible, "The Camp tab switches to the camp page")
    hud.nation_panel.show_tab("nation")
    await _frames(1)
    _check(not hud._camp_dialog.visible and hud.nation_panel.window().visible, "…and back")
    hud.nation_panel.close_panel()
    # --- Your House anywhere free
    var town: Array = MAP.TOWNS[0]
    var in_town := MAP.to_world(Vector2(town[3]))
    _check(camp.wild_problem(NATION.footprint("home", MAP.to_tile(in_town))).begins_with("Not inside"), "Not inside a town")
    var gate: Vector2 = MAP.to_world(preload("res://scripts/dungeons/dungeon_catalogue.gd").DUNGEONS.thornwood_hollow[2])
    _check(not camp.wild_problem(NATION.footprint("home", MAP.to_tile(gate))).is_empty(), "Not at a cave mouth")
    var far := MAP.to_tile(camp.SITE) + Vector2i(14, 0)
    _check(camp.place_problem(null, "well", far).begins_with("Outside"), "Other buildings stay inside the ring")
    var spot := Vector2i(9999, 9999)
    var centre := MAP.to_tile(camp.SITE)
    for ring in range(16, 60):
        for dy in range(-ring, ring + 1, 2):
            for dx in range(-ring, ring + 1, 2):
                if maxi(absi(dx), absi(dy)) != ring or spot.x != 9999:
                    continue
                var tile := centre + Vector2i(dx, dy)
                me.global_position = NATION.foot(tile) + Vector2(0, 40)
                if camp.place_problem(me, "home", tile).is_empty():
                    spot = tile
        if spot.x != 9999:
            break
    _check(spot.x != 9999 and NATION.foot(spot).distance_to(camp.SITE) > NATION.radius(camp.tier()), "A free spot outside the ring takes a house")
    if spot.x != 9999:
        me.global_position = NATION.foot(spot) + Vector2(0, 40)
        _check(session.apply_action(me, "camp", {"operation": "place", "id": "home@%d,%d" % [spot.x, spot.y]}) and NATION.count(camp.state.nation, "home") == 1, "Your House stands out in the world")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("HUD, names and house checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
