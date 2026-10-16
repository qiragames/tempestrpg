extends SceneTree
## Title menu, save slots, solo hosting, pause menu, "Open to friends" and quit/load cycles.
const REGISTRY := preload("res://scripts/menu/world_registry.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
var checks := 0
var failures := 0
var session: Node
var dir: String
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
func _until(condition: Callable, seconds: float = 5.0) -> bool:
    var start := Time.get_ticks_msec()
    while not condition.call():
        if Time.get_ticks_msec() - start > seconds * 1000:
            return false
        await process_frame
    return true
func _menu() -> Control:
    var menu = load("res://scenes/menu/title_menu.tscn").instantiate()
    menu.worlds_dir = dir
    var old := current_scene
    root.add_child(menu)
    current_scene = menu
    if is_instance_valid(old) and old != menu:
        old.queue_free()
    await _frames(1)
    return menu
func _run() -> void:
    session = root.get_node("GameSession")
    dir = OS.get_temp_dir().path_join("tempestrpg-worlds-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    # Registry helpers.
    _check(REGISTRY.clean_name("  My\tWorld  ") == "MyWorld" and REGISTRY.clean_name("x".repeat(50)).length() == 32, "World names are cleaned and limited to 32 characters")
    _check(REGISTRY.parse_seed("12345") == 12345 and REGISTRY.parse_seed("-7") == 7, "Numeric seeds are used directly")
    _check(REGISTRY.parse_seed("goblin camp") == REGISTRY.parse_seed("goblin camp") and REGISTRY.parse_seed("goblin camp") != REGISTRY.parse_seed("goblin cave"), "Text seeds are hashed deterministically")
    var random_seed: int = REGISTRY.parse_seed("")
    _check(random_seed >= 0 and random_seed <= REGISTRY.MAX_SEED, "Empty seed gives a random valid seed")
    _check(REGISTRY.new_world_path("My World!", dir).get_file() == "my_world.json" and REGISTRY.new_world_path("???", dir).get_file() == "world.json", "World file names come from the name")
    _check(project_main_scene() == "res://scenes/menu/title_menu.tscn", "The game starts at the title menu")
    # Empty title menu.
    var menu = await _menu()
    menu._show("load")
    _check(menu._world_list.item_count == 0 and menu._play.disabled and menu._status.text.contains("No saved worlds"), "Load list starts empty with a hint")
    menu.refresh_join_characters()
    menu._show("join")
    menu.join_world()
    _check(menu._status.text.contains("invite code") and session.pending_launch.is_empty(), "Join needs an invite code")
    menu._address_field.text = "192.168.1.10"
    menu.join_world()
    _check(menu._status.text.contains("invite code") and session.pending_launch.is_empty(), "M10: an address is not accepted (invite codes only)")
    _check(menu._join_character.item_count == 1, "With no own worlds, only a new character can join")
    menu._address_field.text = ""
    # Create a world: solo, saved, no port opened.
    menu._show("new")
    menu._name_field.text = "Test World"
    menu._seed_field.text = "1234"
    menu.create_world()
    _check(await _until(func(): return session.active and current_scene != null and current_scene.scene_file_path == session.WORLD_SCENE), "Create and play opens the world")
    await _frames()
    var path := dir.path_join("test_world.json")
    _check(not session.listening and session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and session.multiplayer.is_server(), "Solo world is hosted without opening a port")
    _check(session.world_meta.name == "Test World" and session.world_meta.seed == 1234 and FileAccess.file_exists(path), "World saved immediately with its name and seed")
    var first: Dictionary = STORE.load_world(path)
    _check(first.ok and first.data.meta.name == "Test World" and first.data.meta.seed == 1234 and STORE.valid_meta(first.data.meta), "Save file carries valid meta")
    var world_id: String = session.world_id
    # Pause menu while alone freezes the world.
    var world = current_scene
    var hud = world.get_node("HUD")
    hud.open_pause()
    _check(paused and hud._pause_panel.visible and hud._pause_status.text.contains("single player") and not hud._pause_buttons.multiplayer.disabled and hud._pause_buttons.multiplayer.text == "MULTIPLAYER: OFF" and hud._pause_buttons.invite.disabled, "Solo pause freezes the world and offers the Multiplayer switch")
    _check(not hud._pause_buttons.has("open"), "M10: no Open to friends (address) entry")
    hud._pause_buttons.guests.pressed.emit()
    _check(bool(session.world_meta.imports) and hud._pause_buttons.guests.text == "GUESTS: OWN CHARACTERS OK" and STORE.load_world(path).data.meta.imports == true and STORE.valid_meta(STORE.load_world(path).data.meta), "Guests may bring their own characters (saved with the world)")
    hud._pause_buttons.guests.pressed.emit()
    _check(not bool(session.world_meta.imports) and hud._pause_buttons.guests.text == "GUESTS: NEW CHARACTERS", "...and back to new characters only")
    hud.close_pause()
    _check(not paused and not hud._pause_panel.visible, "Resume continues the world")
    world.get_local_player().position = Vector2(300, 200)
    # M10: multiplayer by invite codes, switched on and off in the running world.
    _check(session.open_with_codes() == OK and session.code_mode and session.multiplayer.multiplayer_peer is WebRTCMultiplayerPeer and session.world_id == world_id, "Multiplayer switches on in the same world (invite codes)")
    _check(session.open_with_codes() == ERR_UNAVAILABLE, "Switching on twice is refused")
    hud.open_pause()
    _check(paused and hud._pause_status.text.contains("multiplayer") and hud._pause_buttons.multiplayer.text == "MULTIPLAYER: ON" and not hud._pause_buttons.invite.disabled, "Pause shows multiplayer on and offers Invite a Friend; nobody joined yet, so the world still freezes")
    hud.close_pause()
    _check(session.close_multiplayer() == OK and not session.code_mode and session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and session.active, "Multiplayer switches off again: single player, same world")
    hud.open_pause()
    _check(hud._pause_buttons.quit.text == "SAVE & QUIT TO TITLE", "Host leaves with Save & quit")
    # A write failure must preserve the live world and its pause menu for a retry.
    var blocked_path := dir.path_join("not_a_directory")
    var blocker := FileAccess.open(blocked_path, FileAccess.WRITE)
    blocker.store_string("Blocks directory creation")
    blocker.close()
    session.save_path = blocked_path.path_join("world.json")
    hud._pause_buttons.quit.pressed.emit()
    await _frames(1)
    _check(session.active and current_scene == world and paused and hud._pause_panel.visible, "Failed Save & quit preserves the hosted world and pause menu")
    _check(STORE.load_world(path).ok, "Failed Save & quit preserves the previous valid save")
    session.save_path = path
    hud._pause_buttons.quit.pressed.emit()
    _check(await _until(func(): return not session.active and current_scene != null and current_scene.scene_file_path == session.TITLE_SCENE), "Save & quit returns to the title menu")
    _check(not paused and not session.listening, "Leaving closes the port and unpauses")
    var saved: Dictionary = STORE.load_world(path)
    _check(saved.ok and saved.data.players.host.position == [300.0, 200.0], "Quitting saved the character position")
    _check(saved.data.meta.last_played >= first.data.meta.last_played, "Last-played time recorded")
    # Load the same world again from the list.
    menu = current_scene
    menu.worlds_dir = dir
    menu._show("load")
    _check(menu._world_list.item_count == 1 and menu._world_list.get_item_text(0).begins_with("Test World · seed 1234") and not menu._play.disabled, "Saved world listed with name and seed")
    var bad_file := FileAccess.open(dir.path_join("broken.json"), FileAccess.WRITE)
    bad_file.store_string("{ not json")
    bad_file.close()
    menu.refresh_worlds()
    var damaged := -1
    for index in range(menu._world_list.item_count):
        if menu._world_list.get_item_text(index).contains("damaged"):
            damaged = index
    _check(damaged >= 0, "Damaged save files are listed, not hidden")
    menu._world_list.select(damaged)
    menu._world_list.item_selected.emit(damaged)
    _check(menu._play.disabled, "Damaged worlds cannot be played")
    for index in range(menu._world_list.item_count):
        if menu._world_list.get_item_text(index).begins_with("Test World"):
            menu._world_list.select(index)
    menu.load_selected()
    _check(await _until(func(): return session.active and current_scene.scene_file_path == session.WORLD_SCENE), "Load World opens the saved world")
    await _frames()
    _check(session.world_id == world_id and session.world_meta.name == "Test World" and not session.listening, "Loading restores the same world, again solo")
    _check(current_scene.get_local_player().position == Vector2(300, 200), "Character position restored")
    session.quit_to_title()
    await _until(func(): return current_scene != null and current_scene.scene_file_path == session.TITLE_SCENE)
    # A second world gets its own slot.
    menu = current_scene
    menu.worlds_dir = dir
    menu._name_field.text = "Test World"
    menu._seed_field.text = "goblin"
    menu.create_world()
    await _until(func(): return session.active)
    _check(FileAccess.file_exists(dir.path_join("test_world_2.json")) and session.world_meta.seed == REGISTRY.parse_seed("goblin"), "Same name creates a separate slot; text seed stored")
    session.quit_to_title()
    await _until(func(): return current_scene != null and current_scene.scene_file_path == session.TITLE_SCENE)
    _check(REGISTRY.list(dir).filter(func(w): return w.ok).size() == 2, "Both worlds are listed")
    # Meta validation and migration.
    var data: Dictionary = STORE.load_world(path).data
    for bad_meta in [{"name": "", "seed": 1, "created": 0, "last_played": 0}, {"name": "x".repeat(40), "seed": 1, "created": 0, "last_played": 0}, {"name": "A", "seed": -1, "created": 0, "last_played": 0}, {"name": "A", "seed": 1, "created": 0, "last_played": 0, "extra": 1}]:
        var bad := data.duplicate(true)
        bad.meta = bad_meta
        _check(not STORE.validate(bad), "Invalid meta rejected: %s" % [bad_meta])
    var legacy := data.duplicate(true)
    legacy.version = 11
    legacy.erase("meta")
    # Real v11 worlds were generated on the reference map (seeded layouts arrive in v13).
    legacy.camp = load("res://scripts/settlement/first_camp.gd").initial_state()
    var migrated: Dictionary = STORE.migrate(legacy)
    _check(STORE.validate(migrated) and migrated.meta.name == "Earlier world" and migrated.meta.seed == 0 and migrated.meta.seeded == false, "v11 worlds gain neutral meta and keep the original map")
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Worlds and menu checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
func project_main_scene() -> String:
    return ProjectSettings.get_setting("application/run/main_scene")
