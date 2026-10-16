extends SceneTree
## Achievements and titles (M9e): the catalogue's targets are reachable; game events count; old
## progress unlocks; titles are worn only when earned and show on the HUD; the window; saves.
const ACH := preload("res://scripts/progression/achievements.gd")
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
    var bosses := preload("res://scripts/bosses/boss_catalogue.gd")
    var map := preload("res://scripts/world/world_map.gd")
    var fishes := preload("res://scripts/professions/fish_catalogue.gd")
    var quests := preload("res://scripts/quests/quest_catalogue.gd")
    var pro := preload("res://scripts/professions/profession_catalogue.gd")
    var problems: Array = []
    var regions: int = map.REGION_NAMES.values().filter(func(region): return not region in ACH.SKIP_REGIONS).size()
    for id in ACH.ACHIEVEMENTS:
        var spec: Array = ACH.ACHIEVEMENTS[id]
        if not spec[2] in ACH.CATEGORIES:
            problems.append(id + " category")
        match String(spec[4]):
            "set":
                var most := {"raids": bosses.RAID.size(), "elites": bosses.ELITES.size(), "dungeons": bosses.DUNGEON_BOSSES.size(), "regions": regions, "heroic": bosses.DUNGEON_BOSSES.size()}
                if int(spec[5]) > int(most.get(spec[6], 0)):
                    problems.append(id + " unreachable")
            "fish":
                if not fishes.FISH.has(spec[6]):
                    problems.append(id + " fish")
            "quest":
                if quests.quest(spec[6]).is_empty():
                    problems.append(id + " quest")
            "pro":
                if not pro.initial_state().has(spec[6]):
                    problems.append(id + " profession")
            "mythic":
                if fishes.FISH.keys().filter(func(fish): return int(fishes.FISH[fish][4]) >= 5).size() < int(spec[5]):
                    problems.append(id + " mythic")
    _check(problems.is_empty(), "Every achievement can be reached %s" % [problems])
    _check(int(ACH.ACHIEVEMENTS.wanderer[5]) == regions and int(ACH.ACHIEVEMENTS.raid_all[5]) == bosses.RAID.size(), "Wanderer and Raid Legend need exactly every land and raid boss")
    var titles: Array = ACH.ACHIEVEMENTS.values().map(func(spec): return spec[3]).filter(func(title): return not String(title).is_empty())
    _check(titles.size() >= 30 and "Leviathan Catcher" in titles and "Master Miner" in titles, "Thirty or more titles, Leviathan Catcher and Master Miner among them (%d)" % titles.size())
    # A world.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-achievements-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24812, dir.path_join("achievements.json"), false) == OK, "Solo world hosted")
    await _frames(40)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    var log: Node = world.quests
    log.on_event(actor, "kill", {"kind": "gnasher", "region": "The First Clearing", "id": "x"})
    _check(ACH.has(actor, "first_blood") and int(ACH.stats(actor).kills) == 1, "The first defeat unlocks First Blood")
    for _i in range(10):
        log.on_event(actor, "kill", {"kind": "shade_spirit", "region": "Thornwood", "id": "night_spot"})
    _check(ACH.has(actor, "nightbane") and int(ACH.stats(actor).night_kills) == 10, "Ten night stalkers: Nightbane")
    log.on_event(actor, "boss", {"id": "boss_gnashmaw"})
    log.on_event(actor, "boss", {"id": "boss_gnashmaw"})
    log.on_event(actor, "boss", {"id": "elite_oakfang"})
    log.on_event(actor, "boss", {"id": "dungeon_thornwood_hollow"})
    _check(ACH.has(actor, "raid_first") and ACH.has(actor, "elite_first") and ACH.has(actor, "delver") and ACH.stats(actor).raids.size() == 1, "Raid boss, hidden elite and dungeon boss each count once")
    _check(not ACH.has(actor, "wyrmslayer"), "Wyrmslayer only for the Eclipse Wyrm")
    log.on_event(actor, "gather", {"resource": "log_oak", "amount": 499})
    log.on_event(actor, "gather", {"resource": "log_oak", "amount": 1})
    _check(ACH.has(actor, "tireless"), "500 things gathered: Tireless")
    # Progress a character already had.
    actor.progression.fish_log["leviathan"] = 1
    actor.progression.professions["mining"] = pro.max_xp()
    log.unlock(actor)
    _check(ACH.has(actor, "leviathan") and ACH.has(actor, "mining_50") and ACH.has(actor, "mining_25"), "Leviathan in the fish log and Mining 50 unlock Leviathan Catcher and Master Miner")
    actor.global_position = map.to_world(Vector2(110, 150))
    log._process(1.0)
    _check("Verdant Isle" in ACH.stats(actor).regions, "Lands visited are remembered")
    # Titles.
    _check(not session.apply_action(actor, "title", {"id": "slayer"}), "A title not yet earned cannot be worn")
    _check(not session.apply_action(actor, "title", {"id": "first_blood"}), "Achievements without a title give none")
    _check(session.apply_action(actor, "title", {"id": "leviathan"}) and ACH.worn_title(actor) == "Leviathan Catcher", "Wearing Leviathan Catcher")
    var hud: CanvasLayer = world.get_node("HUD")
    await _frames(3)
    _check(String(hud._name.text).contains("Leviathan Catcher"), "The title shows on the status card")
    _check(hud.achievements_panel.banner.visible or hud.achievements_panel._banner_left > 0.0, "A banner announces new achievements")
    hud.quest_panel._queue.clear()
    hud.dialog_panel.close()
    hud.achievements_panel.open()
    await _frames(2)
    _check(hud.achievements_panel.visible and hud.achievements_panel._list.get_child_count() >= 5, "Y opens the achievements window")
    hud.achievements_panel._category = "Fishing"
    hud.achievements_panel.refresh()
    await _frames(1)
    _check(String(hud.achievements_panel._summary.text).contains("Leviathan Catcher"), "The window names the worn title")
    _check(not hud.achievements_panel.banner.visible and not hud.get_node("Tracker").visible, "Banner and tracker stay out of open windows")
    hud.achievements_panel.close_panel()
    # Saves.
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("achievements.json")))
    var saved: Dictionary = raw.players.host.progression
    _check(saved.title == "leviathan" and bool(saved.achievements.leviathan) and int(saved.stats.kills) == 11, "Achievements, stats and the title are saved")
    _check(STORE.validate(raw), "The save validates")
    var bad_title: Dictionary = raw.duplicate(true)
    bad_title.players.host.progression.title = "slayer"
    var bad_stats: Dictionary = raw.duplicate(true)
    bad_stats.players.host.progression.stats.kills = -5
    var bad_list: Dictionary = raw.duplicate(true)
    bad_list.players.host.progression.stats.raids = [1, 2]
    _check(not STORE.validate(bad_title) and not STORE.validate(bad_stats) and not STORE.validate(bad_list), "Unearned titles and broken stats are rejected")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Achievement checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
