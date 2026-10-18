extends SceneTree
## Guilds and chat (M14a): founding (price, name and tag rules, unique), invitations (leader and
## officers, expiry), ranks (promote, demote, hand over the lead), removing (officers only
## members), leaving (the lead passes on; the last one ends the guild), disbanding, tags above
## heads, the guild window, chat channels (world, guild, party) and the spacing between lines;
## guilds are saved, chat is not; broken guild data is rejected.
const GUILDS := preload("res://scripts/guilds/world_guilds.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
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
    _check(GUILDS.valid_name("Moon Wardens") and not GUILDS.valid_name("ab") and not GUILDS.valid_name("Bad<Name>") and GUILDS.valid_tag("MOON") and not GUILDS.valid_tag("moon") and not GUILDS.valid_tag("TOOLONG"), "Names: 3-20 letters; tags: 2-4 capitals or digits")
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-guilds-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24832, dir.path_join("guilds.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var ann := _friend("ann", Vector2(300, 300))
    var bo := _friend("bo", Vector2(320, 300))
    await _frames(1)
    var guilds: Node = world.guilds
    # Founding.
    me.progression["zeni"] = 500
    _check(not session.apply_action(me, "guild", {"operation": "found", "id": "", "name": "Moon Wardens", "tag": "MOON", "emblem": 1}), "Founding costs Zeni (500 is not enough)")
    me.progression["zeni"] = 5000
    _check(not session.apply_action(me, "guild", {"operation": "found", "id": "", "name": "x", "tag": "MOON", "emblem": 1}), "Too short a name is refused")
    _check(session.apply_action(me, "guild", {"operation": "found", "id": "", "name": "Moon Wardens", "tag": "MOON", "emblem": 1}) and int(me.progression.zeni) == 5000 - GUILDS.FOUND_PRICE, "Moon Wardens <MOON> founded for %d Zeni" % GUILDS.FOUND_PRICE)
    var id: String = guilds.guild_of(me.character_id)
    _check(not id.is_empty() and guilds.rank_of(me.character_id) == "leader" and guilds.tag_of(me.character_id) == "MOON", "The founder leads it and wears its tag")
    ann.progression["zeni"] = 5000
    _check(not guilds.found(ann, "moon wardens", "MW", 0) and not guilds.found(ann, "Sun Guard", "MOON", 0), "Names and tags are unique in the world")
    # Invitations.
    _check(session.apply_action(me, "guild", {"operation": "invite", "id": "ann"}) and guilds.state.invites.has("ann"), "The leader invites Ann")
    _check(session.apply_action(ann, "guild", {"operation": "accept"}) and guilds.guild_of("ann") == id and guilds.rank_of("ann") == "member", "Ann joins as a member")
    _check(not guilds.invite(ann, "bo"), "Members cannot invite")
    _check(session.apply_action(me, "guild", {"operation": "promote", "id": "ann"}) and guilds.rank_of("ann") == "officer", "Ann becomes an officer")
    _check(guilds.invite(ann, "bo") and guilds.accept(bo) and guilds.rank_of("bo") == "member", "Officers invite: Bo joins")
    _check(not guilds.kick(bo, "ann") and guilds.kick(ann, "bo") and guilds.guild_of("bo").is_empty(), "Members cannot remove anyone; officers remove members")
    guilds.invite(me, "bo")
    world.progression["world_time"] = float(world.progression.get("world_time", 0.0)) + GUILDS.INVITE_SECONDS + 5.0
    guilds._process(0.016)
    _check(not guilds.accept(bo) and guilds.guild_of("bo").is_empty(), "Invitations run out")
    # Hand over the lead and leave.
    _check(session.apply_action(me, "guild", {"operation": "transfer", "id": "ann"}) and guilds.rank_of("ann") == "leader" and guilds.rank_of(me.character_id) == "officer", "The lead goes to Ann; the old leader stays an officer")
    _check(session.apply_action(ann, "guild", {"operation": "leave"}) and guilds.rank_of(me.character_id) == "leader", "When the leader leaves, an officer takes over")
    # Tags above heads and the window.
    await _frames(2)
    var hud: CanvasLayer = world.get_node("HUD")
    hud.quest_panel._queue.clear()
    hud.dialog_panel.close()
    hud.guild_panel.open()
    await _frames(3)
    _check(hud.guild_panel.visible and hud.guild_panel._title.text.contains("MOON") and hud.guild_panel._list.get_child_count() >= 1, "The guild window shows the guild and its members")
    hud.guild_panel.close_panel()
    # Chat.
    _check(session.apply_action(me, "chat", {"channel": "world", "text": "Hello everyone"}), "Saying something to the world")
    _check(not session.apply_action(me, "chat", {"channel": "world", "text": "Too fast"}), "...one line at a time")
    await create_timer(0.7, true).timeout
    _check(session.apply_action(me, "chat", {"channel": "guild", "text": "Guild only"}), "...and to the guild")
    await create_timer(0.7, true).timeout
    _check(not session.apply_action(ann, "chat", {"channel": "guild", "text": "I left"}), "Without a guild there is no guild channel")
    var lines: Array = world.chat.state.lines
    var guild_line: Dictionary = lines[-1]
    _check(lines.size() == 2 and world.chat.reaches(lines[0], "ann") and world.chat.reaches(guild_line, me.character_id) and not world.chat.reaches(guild_line, "ann"), "World lines reach everyone, guild lines only the guild")
    await _frames(3)
    _check(hud._log.get_parsed_text().contains("Hello everyone") and hud._log.get_parsed_text().contains("[Guild]"), "Chat lines appear in the event log")
    # Saving: guilds stay, chat does not; broken guild data is rejected.
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("guilds.json")))
    _check(raw.get("guilds") is Dictionary and raw.guilds.guilds.has(id) and not raw.has("chat") and STORE.validate(raw), "Guilds are saved, chat is not")
    var bad: Dictionary = raw.duplicate(true)
    bad.guilds.guilds[id].leader = "nobody"
    _check(not STORE.validate(bad), "A leader who is no member is rejected")
    var old: Dictionary = raw.duplicate(true)
    old.erase("guilds")
    old.version = 39
    var migrated: Variant = STORE.migrate(old)
    _check(migrated is Dictionary and int(migrated.version) == STORE.VERSION and migrated.guilds.guilds.is_empty() and STORE.validate(migrated), "v39 worlds start without guilds")
    # Disbanding (the last member).
    _check(session.apply_action(me, "guild", {"operation": "disband"}) and guilds.state.guilds.is_empty(), "The leader disbands the guild")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Guild checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
