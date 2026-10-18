extends SceneTree
## Guild hall, bank, level and quests (M14b): the Guild Hall is a nation building; its bank opens
## only there; members deposit items, gear and Zeni; only officers and the leader take (members
## too when the leader allows it); the bank has room limits; members' XP feeds the guild; levels
## give perks (XP, Zeni, gathering speed, bank room); three weekly quests count members' deeds and
## pay guild XP and Zeni; a new week brings new quests; the last member cannot leave a full bank;
## saved and checked.
const GUILDS := preload("res://scripts/guilds/world_guilds.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const DAY_NIGHT := preload("res://scripts/world/day_night.gd")
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

func _friend(id: String, at: Vector2) -> CharacterBody2D:
    var other = load("res://scenes/player/player.tscn").instantiate()
    other.character_id = id
    other.local_controlled = false
    other.position = at
    world.add_child(other)
    return other

func _run() -> void:
    _check(GUILDS.level_for(0) == 1 and GUILDS.level_for(500) == 2 and GUILDS.level_for(75000) == 10 and GUILDS.perk_lines(4).size() == GUILDS.PERKS.size(), "Ten guild levels with perks")
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-guild-hall-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24833, dir.path_join("hall.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var ann := _friend("ann", Vector2(300, 300))
    await _frames(1)
    var guilds: Node = world.guilds
    var camp: Node = world.camp
    me.progression["zeni"] = 20000
    _check(guilds.found(me, "Moon Wardens", "MOON", 1) and guilds.invite(me, "ann") and guilds.accept(ann), "A guild with Ann as a member")
    var id: String = guilds.guild_of(me.character_id)
    # The hall.
    var camp_before: Dictionary = camp.state.duplicate(true)
    camp.state.founded = true
    camp.state.founder = "host"
    camp.state.nation.tier = 1
    _check(NATION.BUILDINGS.has("guild_hall") and camp.place_problem(null, "guild_hall", Vector2i(30, 30)) != "Unknown building.", "The Guild Hall is a nation building")
    var bag: Node = me.get_node("Inventory")
    bag.add_material("ore_iron", 30)
    me.global_position = Vector2(200, 200)
    _check(not session.apply_action(me, "guild", {"operation": "put", "id": "ore_iron", "count": 5}), "The bank opens only at a Guild Hall")
    camp.state.nation.buildings.append({"id": "b_guild_1", "kind": "guild_hall", "tile": [24, 24]})
    me.global_position = NATION.foot(Vector2i(24, 24))
    ann.global_position = me.global_position
    _check(guilds.at_hall(me), "Standing at the hall")
    # The bank.
    _check(session.apply_action(me, "guild", {"operation": "put", "id": "ore_iron", "count": 10}) and bag.count_of("ore_iron") == 20 and int(guilds.guild(id).bank.goods.ore_iron) == 10, "Ten iron ore deposited")
    var sword: Dictionary = GEAR.roll("iron_sword", 1, RandomNumberGenerator.new())
    sword["id"] = "item_guild_sword0001"
    me.add_item(sword)
    _check(guilds.bank_put(me, "item_guild_sword0001", 1) and me.item_by_id("item_guild_sword0001").is_empty() and guilds.guild(id).bank.items.size() == 1, "A sword deposited")
    _check(session.apply_action(me, "guild", {"operation": "zeni", "id": "", "count": 2000}) and int(guilds.guild(id).bank.zeni) == 2000, "2000 Zeni deposited")
    _check(not guilds.bank_take(ann, "ore_iron", 1) and not guilds.bank_zeni(ann, -100), "Members cannot take (by default)")
    _check(session.apply_action(me, "guild", {"operation": "withdraw", "id": "members"}) and guilds.bank_take(ann, "ore_iron", 3) and ann.get_node("Inventory").count_of("ore_iron") == 3, "The leader lets members take: Ann takes three ore")
    _check(guilds.bank_take(me, "item_guild_sword0001", 1) and not me.item_by_id("item_guild_sword0001").is_empty(), "The sword comes back out")
    _check(guilds.bank_zeni(me, -500) and int(guilds.guild(id).bank.zeni) == 1500, "Zeni taken out")
    # The bag holds less than the bank: fill it in batches.
    for _batch in range(12):
        bag.add_material("ore_iron", 40)
        guilds.bank_put(me, "ore_iron", 40)
    _check(GUILDS.units(guilds.guild(id).bank) == guilds.bank_room(id)[0], "The bank fills up to its room (%d items at level 1)" % guilds.bank_room(id)[0])
    # Level and perks.
    var xp_before: int = int(guilds.guild(id).xp)
    me.gain_experience(10000, "test")
    _check(int(guilds.guild(id).xp) - xp_before == int(round(10000 * GUILDS.DEED_SHARE)), "2% of a member's XP goes to the guild")
    guilds.state.guilds[id].xp = 7000
    _check(guilds.level_of(id) == 5 and guilds.perk(me.character_id, "xp") == 3 and guilds.perk(me.character_id, "zeni") == 5 and guilds.perk(me.character_id, "gather") == 5 and guilds.bank_room(id)[0] == GUILDS.BANK_UNITS + 100, "Level 5: +3% XP, +5% Zeni, +5% gathering, a bigger bank")
    var zeni_before: int = int(me.progression.zeni)
    me.gain_zeni(100, "defeat")
    _check(int(me.progression.zeni) - zeni_before == 105, "The Zeni perk: 100 → 105 from a creature")
    var nodes: Node = world.nodes
    var index := -1
    for candidate in range(world.terrain.planned_props().size()):
        if not nodes.info(candidate).is_empty() and nodes.info(candidate).get("profession", "") == "woodcutting":
            index = candidate
            break
    var cy := _friend("cy", Vector2(320, 300))
    await _frames(1)
    _check(index >= 0 and nodes.swing_seconds(me, index) < nodes.swing_seconds(cy, index), "Gathering is faster with the perk than without a guild")
    # Weekly quests.
    var goals: Array = guilds.goals(id)
    _check(goals.size() == GUILDS.QUESTS_PER_WEEK and goals.all(func(goal): return GUILDS.QUEST_KINDS.has(goal.kind)), "Three guild quests this week")
    var goal: Dictionary = goals[0]
    var event: String = {"defeat": "kill", "gather": "gather", "boss": "boss", "bounty": "bounty", "craft": "craft"}[goal.kind]
    var xp_mid: int = int(guilds.guild(id).xp)
    var bank_zeni: int = int(guilds.guild(id).bank.zeni)
    for _deed in range(int(goal.need)):
        guilds.on_event(ann, event, {})
    _check(guilds.goals(id)[0].done and int(guilds.guild(id).xp) == xp_mid + GUILDS.QUEST_XP and int(guilds.guild(id).bank.zeni) == bank_zeni + GUILDS.QUEST_ZENI, "Members' deeds finish a quest: +%d guild XP, +%d Zeni in the bank" % [GUILDS.QUEST_XP, GUILDS.QUEST_ZENI])
    var week: int = guilds.week()
    world.progression["world_time"] = float(world.progression.get("world_time", 0.0)) + DAY_NIGHT.DAY_SECONDS * GUILDS.WEEK_DAYS
    _check(guilds.week() == week + 1 and not guilds.goals(id)[0].done and int(guilds.goals(id)[0].have) == 0, "A new week brings new quests")
    # The hall window.
    var hud: CanvasLayer = world.get_node("HUD")
    hud.quest_panel._queue.clear()
    hud.dialog_panel.close()
    hud.guild_hall_panel.open()
    await _frames(3)
    _check(hud.guild_hall_panel.visible and hud.guild_hall_panel._bank.get_child_count() >= 1 and hud.guild_hall_panel._week.get_child_count() >= 4, "The guild hall window shows the bank, perks and quests")
    hud.guild_hall_panel.close_panel()
    # Leaving with a full bank.
    guilds.kick(me, "ann")
    _check(not guilds.leave(me) and not guilds.disband(me), "The last member cannot leave or disband while the bank holds something")
    # Saves.
    camp.state = camp_before
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("hall.json")))
    _check(raw.guilds.guilds[id].bank.zeni > 0 and raw.guilds.guilds[id].quests.goals.size() == 3 and STORE.validate(raw), "The bank and the quests are saved")
    var bad: Dictionary = raw.duplicate(true)
    bad.guilds.guilds[id].bank.goods["not_an_item"] = 5
    _check(not STORE.validate(bad), "Unknown items in the bank are rejected")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Guild hall checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
