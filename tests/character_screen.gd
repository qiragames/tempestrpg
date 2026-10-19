extends SceneTree
## Character-first start and names (user request): PLAY opens your characters (one per world)
## with a detailed overview; an unnamed character is named there; New character takes a name and
## a race and then creates a world or joins a friend; Join a Friend with one of yours hides the
## race; Delete asks twice. Names: saved in progression.name, shown above heads and in chat;
## Options hides your own.
const STORE := preload("res://scripts/persistence/save_store.gd")
const NAMES := preload("res://scripts/progression/character_names.gd")
var checks := 0
var failures := 0
var session: Node

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
    session = root.get_node("GameSession")
    # --- Names.
    _check(NAMES.clean("  Rimuru   Tempest  ") == "Rimuru Tempest" and NAMES.clean("[b]x<y>|z") == "bxyz" and NAMES.clean("a".repeat(30)).length() == NAMES.MAX_LENGTH, "Names are cleaned (spaces, markup) and at most 16 letters")
    _check(NAMES.valid("Aster") and NAMES.valid("") and not NAMES.valid("  x") and not NAMES.valid(5), "Valid names")
    _check(NAMES.display({"name": "", "race": "Human"}) == "Human" and NAMES.display({"name": "Milim", "race": "Demon"}) == "Milim", "Unnamed characters show their race")
    # A world with a named host character, one without a name.
    var dir := OS.get_temp_dir().path_join("tempestrpg-chars-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    session.host_name = "Shion"
    _check(session.start_host(24911, dir.path_join("first.json"), false, {"name": "First", "seed": 0, "created": 1, "last_played": 2}, "Demon") == OK, "A world for a named character")
    await _frames(10)
    var me = world.get_local_player()
    _check(me.progression.get("name") == "Shion", "The new world's character gets its name")
    world.chat.say(me, "world", "hello")
    _check(world.chat.state.lines.back().from == "Shion", "Chat shows the name")
    var hud: CanvasLayer = world.get_node("HUD")
    await _frames(30)
    _check(float(me.progression.get("playtime", 0.0)) > 0.0, "Playtime counts up")
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("first.json")))
    _check(raw.players.host.progression.name == "Shion" and STORE.validate(raw), "The name is saved")
    var bad: Dictionary = raw.duplicate(true)
    bad.players.host.progression.name = "[color=red]x"
    _check(not STORE.validate(bad), "Markup in names is refused")
    var unnamed: Dictionary = raw.duplicate(true)
    unnamed.players.host.progression.erase("name")
    unnamed.meta.name = "Second"
    unnamed.meta.last_played = 1
    STORE.write_world(dir.path_join("second.json"), unnamed)
    session.host_name = ""
    session.stop_session(false)
    world.queue_free()
    await _frames()
    # --- The character screen.
    var menu = load("res://scenes/menu/title_menu.tscn").instantiate()
    menu.worlds_dir = dir
    root.add_child(menu)
    current_scene = menu
    await _frames(2)
    _check(menu._entries.new.text == "PLAY" and not menu._entries.has("load"), "The main menu starts with PLAY (characters first)")
    menu._entries.new.pressed.emit()
    await _frames(2)
    var screen: Panel = menu.character_screen
    _check(screen.visible and screen.list.item_count == 3 and screen.list.get_item_text(1).begins_with("Shion · Lv 1 Demon"), "PLAY lists your characters (and New character)")
    _check(screen.details.get_parsed_text().contains("Level 1 Demon") and screen.details.get_parsed_text().contains("Home world: First") and screen.model.sprite_frames != null, "The overview: model, level, race, home world")
    screen.list.select(2)
    screen._show_selected()
    _check(screen.name_field.visible and screen.rename.visible, "An unnamed character is named on the screen")
    screen.play_selected()
    _check(menu._status.text.begins_with("Name your character"), "...before playing")
    screen.name_field.text = "Benimaru"
    screen.save_name()
    var renamed: Dictionary = STORE.load_world(dir.path_join("second.json"))
    _check(renamed.ok and renamed.data.players.host.progression.name == "Benimaru", "Save name writes it into the character's world")
    # Join with one of yours: no race picker.
    screen.list.select(1)
    screen._show_selected()
    screen.join_selected()
    _check(menu._panels.join.visible and not menu._join_race.visible and not menu._join_character.visible and menu._join_character.selected > 0, "Join a Friend with your character hides the race")
    menu._show("characters")
    await _frames(1)
    # A new character.
    screen.list.select(0)
    screen._show_selected()
    _check(screen.race_picker.visible and screen.play.text == "Create a World" and screen.delete.disabled, "New character: name and race")
    screen.play_selected()
    _check(menu._status.text.begins_with("Give your new character a name"), "A new character needs a name")
    screen.name_field.text = "Gobta"
    screen.race_picker.select(1)
    screen.join_selected()
    _check(menu._panels.join.visible and menu._pending_name == "Gobta" and menu._join_race.selected == 1 and not menu._join_race.visible, "A new character can join a friend")
    menu._show("characters")
    screen.list.select(0)
    screen._show_selected()
    screen.name_field.text = "Gobta"
    screen.play_selected()
    _check(menu._panels.new.visible and menu._pending_name == "Gobta" and not menu._new_race.visible, "...or get a new world")
    # Delete asks twice.
    menu._show("characters")
    screen.list.select(2)
    screen._show_selected()
    screen.delete_selected()
    _check(FileAccess.file_exists(dir.path_join("second.json")) and screen.delete.text == "Really?", "Delete asks first")
    screen.delete_selected()
    _check(not FileAccess.file_exists(dir.path_join("second.json")) and screen.list.item_count == 2, "...then deletes the character's world")
    # Creating the world passes the name on.
    menu._show("characters")
    screen.list.select(0)
    screen._show_selected()
    screen.name_field.text = "Ranga"
    screen.play_selected()
    menu._name_field.text = "Ranga Land"
    menu.create_world()
    _check(session.pending_launch.get("name") == "Ranga", "The new world is made for the new character")
    session.pending_launch = {}
    menu.queue_free()
    await _frames(3)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Character screen checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
