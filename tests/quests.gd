extends SceneTree
## Quests (M9c): the main story's opening (Prologue to Chapter 2), side quests from givers, bounty
## boards; every quest's targets exist; progress from game events; hand-ins and rewards; saves.
const QUESTS := preload("res://scripts/quests/quest_catalogue.gd")
const LOG := preload("res://scripts/quests/quest_log.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const DAY := preload("res://scripts/world/day_night.gd")
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
    # Content: every giver, item, creature, boss, dungeon, fish and region exists.
    var trade := preload("res://scripts/trade/trade_catalogue.gd")
    var codec := preload("res://scripts/persistence/state_codec.gd")
    var bosses := preload("res://scripts/bosses/boss_catalogue.gd")
    var fishes := preload("res://scripts/professions/fish_catalogue.gd")
    var dungeons := preload("res://scripts/dungeons/dungeon_catalogue.gd")
    var problems: Array = []
    for id in QUESTS.all():
        var quest: Dictionary = QUESTS.all()[id]
        if not (quest.giver == QUESTS.LUMI or QUESTS.NPCS.has(quest.giver) or String(quest.giver).begins_with("board_")):
            problems.append("%s giver" % id)
        for required in quest.requires:
            if QUESTS.quest(required).is_empty():
                problems.append("%s requires %s" % [id, required])
        for step in quest.steps:
            match step.type:
                "talk":
                    if not (step.npc == QUESTS.LUMI or QUESTS.NPCS.has(step.npc) or String(step.npc).begins_with("board_")):
                        problems.append("%s talk %s" % [id, step.npc])
                "bring":
                    if not trade.bag_item(step.item):
                        problems.append("%s item %s" % [id, step.item])
                "kill":
                    if not String(step.kind).is_empty() and not codec.known_kind(step.kind):
                        problems.append("%s kind %s" % [id, step.kind])
                    if not String(step.region).is_empty() and not step.region in MAP.REGION_NAMES.values():
                        problems.append("%s region %s" % [id, step.region])
                "boss":
                    if not bosses.is_boss(step.id):
                        problems.append("%s boss %s" % [id, step.id])
                "dungeon":
                    if not dungeons.DUNGEONS.has(step.id):
                        problems.append("%s dungeon %s" % [id, step.id])
                "catch":
                    if not String(step.fish).is_empty() and not fishes.FISH.has(step.fish):
                        problems.append("%s fish %s" % [id, step.fish])
    _check(problems.is_empty(), "Every quest names real givers, items, creatures, bosses, dungeons and fish %s" % [problems])
    var npcs_ok := true
    for npc in QUESTS.NPCS:
        var at: Vector2i = MAP.to_tile(QUESTS.npc_position(npc))
        npcs_ok = npcs_ok and not MAP.solid(at.x, at.y)
    _check(npcs_ok and QUESTS.QUESTS.keys().filter(func(id): return QUESTS.QUESTS[id].kind == "side").size() >= 15, "Quest givers stand on open ground; fifteen or more side quests")
    _check(QUESTS.BOARD_TOWNS.all(func(town): return QUESTS.bounties(town).size() >= 2), "Every town's board has bounties")
    # A world.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-quests-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24810, dir.path_join("quests.json"), false) == OK, "Solo world hosted")
    await _frames(40)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    var log: Node = world.quests
    _check(LOG.active(actor, "main_0"), "The story starts by itself (Lumi)")
    # Prologue.
    for _i in range(3):
        log.on_event(actor, "kill", {"kind": "gnasher", "region": "The First Clearing"})
    _check(int(LOG.entry(actor, "main_0").s) == 1, "Three defeats in the clearing")
    actor.global_position = world.camp.SITE
    log._check_places(actor)
    _check(int(LOG.entry(actor, "main_0").s) == 2, "Reaching the camp")
    world.progression.world_time = fposmod(23.0 - DAY.START_HOUR, 24.0) / 24.0 * DAY.DAY_SECONDS
    log._check_places(actor)
    world.progression.world_time += DAY.DAY_SECONDS / 24.0 * 8.0
    log._check_places(actor)
    _check(int(LOG.entry(actor, "main_0").s) == 3, "Living through a night")
    _check(not log.talk(actor, "orrin"), "Orrin is in Brookhaven, not here")
    actor.global_position = QUESTS.npc_position("orrin") + Vector2(10, 0)
    world.terrain.ensure_props_at(actor.global_position)
    var xp: int = int(actor.progression.experience)
    _check(log.nearest_npc(actor) == "orrin" and session.apply_action(actor, "quest", {"operation": "talk", "id": "orrin"}) and LOG.finished(actor, "main_0") and int(actor.progression.experience) > xp, "Talking to Orrin finishes the Prologue (with a reward)")
    # Chapter 1 at Orrin.
    actor.progression.level = 3
    actor.progression.experience = preload("res://scripts/progression/leveling.gd").xp_for_level(3) + 10
    actor.progression.skill_points = 3
    _check(log.marker(actor, "orrin") == "!" and log.available(actor, "main_1"), "Orrin has the next chapter (!)")
    _check(session.apply_action(actor, "quest", {"operation": "accept", "id": "main_1"}) and LOG.active(actor, "main_1"), "Chapter 1 accepted")
    var bag: Node = actor.get_node("Inventory")
    bag.add_material("log_oak", 3)
    bag.add_material("ore_copper", 2)
    _check(log.marker(actor, "orrin") == "?", "Orrin waits for the logs and ore (?)")
    log.talk(actor, "orrin")
    _check(int(LOG.entry(actor, "main_1").s) == 2 and bag.count_of("log_oak") == 0 and bag.count_of("ore_copper") == 0, "Handing in both deliveries at once")
    for _i in range(6):
        log.on_event(actor, "kill", {"kind": "gnasher", "region": "Thornwood"})
    log.on_event(actor, "kill", {"kind": "gnasher", "region": "Thornwood"})
    _check(int(LOG.entry(actor, "main_1").s) == 3 and int(LOG.entry(actor, "main_1").c) == 0, "Six Thornwood defeats (extra ones don't spill over)")
    actor.global_position = world.dungeon_gates.mouth_position("thornwood_hollow") + Vector2(0, 10)
    session.apply_action(actor, "dungeon", {"operation": "enter", "id": "thornwood_hollow"})
    _check(int(LOG.entry(actor, "main_1").s) == 4, "Going down into Thornwood Hollow")
    log.on_event(actor, "boss", {"id": "boss_gnashmaw"})
    _check(int(LOG.entry(actor, "main_1").s) == 4, "The wrong boss does not count")
    log.on_event(actor, "boss", {"id": "dungeon_thornwood_hollow"})
    actor.global_position = QUESTS.npc_position("orrin") + Vector2(10, 0)
    log.talk(actor, "orrin")
    _check(LOG.finished(actor, "main_1"), "Rootmaw defeated, the shard brought to Orrin: Chapter 1 done")
    # A side quest and a bounty.
    actor.global_position = QUESTS.npc_position("hilde") + Vector2(10, 0)
    _check(session.apply_action(actor, "quest", {"operation": "accept", "id": "side_bread"}), "Hilde's side quest accepted")
    bag.add_material("herb_mint", 4)
    var draughts: int = bag.count_of("healing_draught")
    log.talk(actor, "hilde")
    _check(LOG.finished(actor, "side_bread") and bag.count_of("healing_draught") == draughts + 2, "Mint for Hilde: done, two draughts as a reward")
    _check(not log.available(actor, "side_bread"), "Side quests are done once")
    var board: Vector2 = QUESTS.npc_position("board_brookhaven")
    actor.global_position = board + Vector2(10, 0)
    _check(log.nearest_npc(actor) == "board_brookhaven" and session.apply_action(actor, "quest", {"operation": "accept", "id": "bounty_brookhaven_cull"}), "A bounty from Brookhaven's board")
    for _i in range(8):
        log.on_event(actor, "kill", {"kind": "gnasher", "region": "Verdant Isle"})
    log.talk(actor, "board_brookhaven")
    _check(LOG.finished(actor, "bounty_brookhaven_cull") and not log.available(actor, "bounty_brookhaven_cull"), "Bounty claimed; gone from the board for now")
    world.progression.world_time += QUESTS.BOUNTY_SECONDS + 1.0
    _check(log.available(actor, "bounty_brookhaven_cull"), "A day later the bounty is back")
    # The UI: tracker and log.
    var hud: CanvasLayer = world.get_node("HUD")
    await _frames(3)
    hud.quest_panel.tracked = ""
    session.apply_action(actor, "quest", {"operation": "accept", "id": "bounty_brookhaven_cull"})
    _check(String(hud.quest_panel.tracker_text()).contains("Cull the Wilds"), "The tracker shows the active quest's objective")
    # The story's lines: a speech box that never pauses or blocks other windows.
    _check(not hud.quest_panel._queue.is_empty() or hud.quest_panel.speech.visible, "Finished steps queue the story's lines")
    _check(not hud.dialog_panel.is_open() and not paused, "Story lines neither pause the game nor open a dialogue")
    await _frames(2)
    _check(hud.quest_panel.speech.visible and not hud.quest_panel._speech_text.text.is_empty() and hud.quest_panel._speech_face.texture != null, "The speech box shows the speaker's portrait and words")
    hud.quest_panel.open()
    await _frames(2)
    _check(hud.quest_panel.visible and hud.quest_panel._list.get_child_count() >= 1, "O opens the quest log")
    hud.quest_panel.close_panel()
    # Saves.
    _check(session.save_world() == OK, "Saved with quest progress")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("quests.json")))
    _check(bool(raw.players.host.progression.quests.main_1.done), "Quest progress is saved")
    var bad: Dictionary = raw.duplicate(true)
    bad.players.host.progression.quests.main_2 = {"s": 99, "c": 0, "done": false}
    _check(not STORE.validate(bad), "Impossible quest steps are rejected")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Quest checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
