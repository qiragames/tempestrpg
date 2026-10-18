extends SceneTree
## Classes (M12b): the old master in a founded settlement; choosing a class (free the first time)
## and a subclass from level 20; changes cost Zeni; weapons need their class or subclass
## (classless: up to Rare); level and attribute requirements; worn gear that no longer fits goes
## back to the bag; resetting attributes; saves.
const CLASSES := preload("res://scripts/progression/class_catalogue.gd")
const ATTRIBUTES := preload("res://scripts/progression/attributes.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
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

func _base(weapon: String, low: int, high: int) -> String:
    for id in GEAR.BASES:
        var spec: Dictionary = GEAR.BASES[id]
        if spec.get("weapon", "") == weapon and not spec.has("unique") and not spec.has("set") and not spec.has("boss") and int(spec.get("level", 1)) >= low and int(spec.get("level", 1)) <= high and int(spec.get("min_rarity", 0)) <= 2:
            return id
    return ""

func _run() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 12
    var bow_base := _base("bow", 1, 5)
    var sword_base := _base("sword", 1, 5)
    var mythic: Dictionary = GEAR.roll(_base("bow", 40, 48), 5, rng)
    var needs := CLASSES.requirements(mythic)
    _check(needs["class"] == "archer" and needs.attributes.has("dex") and needs.attributes.has("str") and int(needs.attributes.dex) > int(needs.attributes.str), "A Mythic bow needs an Archer with Dexterity (and some Strength): %s" % CLASSES.requirement_text(mythic))
    _check(CLASSES.requirements(GEAR.roll(bow_base, 0, rng)).attributes.is_empty(), "Common weapons ask for no attributes")
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-classes-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24830, dir.path_join("classes.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var master: Node = world.class_master
    var camp: Node = world.camp
    _check(not master.present(), "No master before the settlement is founded")
    var camp_before: Dictionary = camp.state.duplicate(true)
    camp.state.founded = true
    camp.state.founder = "host"
    await _frames(2)
    _check(master.present() and master._body.visible, "The old master lives in the founded settlement")
    # Classless.
    var rare_bow: Dictionary = GEAR.roll(bow_base, 2, rng)
    rare_bow["id"] = "item_class_bow000001"
    var epic_bow: Dictionary = GEAR.roll(bow_base, 3, rng)
    epic_bow["id"] = "item_class_bow000002"
    var sword: Dictionary = GEAR.roll(sword_base, 1, rng)
    sword["id"] = "item_class_sword0001"
    for item in [rare_bow, epic_bow, sword]:
        me.add_item(item)
    _check(me.equip("item_class_bow000001", "weapon"), "Classless: a Rare bow is fine")
    _check(not me.equip("item_class_bow000002", "weapon"), "Classless: an Epic bow is not")
    # Choosing.
    me.global_position = master.position_in_world() + Vector2(10, 0)
    _check(session.apply_action(me, "class", {"operation": "choose", "slot": "main", "id": "archer"}) and CLASSES.chosen(me.progression).main == "archer", "Choosing Archer (free the first time)")
    _check(me.equip("item_class_bow000002", "weapon"), "An Archer uses the Epic bow")
    _check(not me.equip("item_class_sword0001", "weapon") or CLASSES.problem(me.progression, sword).is_empty() == false, "...but not a sword (no Warrior class or subclass)")
    _check(not session.apply_action(me, "class", {"operation": "choose", "slot": "sub", "id": "warrior"}), "No subclass before level 20")
    me.gain_experience(LEVELING.xp_for_level(20), "test")
    _check(session.apply_action(me, "class", {"operation": "choose", "slot": "sub", "id": "warrior"}) and me.equip("item_class_sword0001", "weapon"), "Level 20: Warrior as a subclass; swords allowed")
    _check(not session.apply_action(me, "class", {"operation": "choose", "slot": "sub", "id": "archer"}), "The subclass cannot be the main class")
    # Changing costs Zeni; worn weapons that no longer fit go back to the bag.
    me.progression["zeni"] = 0
    _check(not session.apply_action(me, "class", {"operation": "choose", "slot": "sub", "id": "assassin"}), "Changing costs Zeni (none left)")
    me.progression["zeni"] = 100000
    var price := CLASSES.change_price(me.progression)
    _check(session.apply_action(me, "class", {"operation": "choose", "slot": "sub", "id": "assassin"}) and int(me.progression.zeni) == 100000 - price, "A change costs %d Zeni at this level" % price)
    _check(me.progression.equipment.get("weapon", "") == "" and not me.item_by_id("item_class_sword0001").is_empty(), "The sword went back into the bag")
    # Attributes for Legendary and Mythic.
    mythic["id"] = "item_class_mythic001"
    me.add_item(mythic)
    _check(not me.equip("item_class_mythic001", "weapon"), "A Mythic bow needs its level and attributes")
    _check(not me.equip("item_class_bow000002", "accessory_1"), "...and everything still has to fit its slot")
    # Reset.
    for _i in range(10):
        me.spend_attribute("dex")
    _check(session.apply_action(me, "class", {"operation": "reset", "slot": "", "id": ""}) and ATTRIBUTES.unspent(me.progression) == ATTRIBUTES.total_points(me.progression), "The master resets attribute points (for Zeni)")
    me.global_position = master.position_in_world() + Vector2(300, 0)
    _check(not master.choose(me, "main", "mage"), "Choosing needs the master nearby")
    _check(not session.apply_action(me, "class", {"operation": "choose", "slot": "main", "id": "pirate"}), "Unknown classes are refused")
    # The window.
    var hud: CanvasLayer = world.get_node("HUD")
    hud.quest_panel._queue.clear()
    hud.dialog_panel.close()
    hud.class_panel.open()
    await _frames(3)
    _check(hud.class_panel.visible and hud.class_panel._list.get_child_count() == 7, "The class window lists the seven classes")
    hud.class_panel.close_panel()
    # Saves.
    camp.state = camp_before
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("classes.json")))
    _check(raw.players.host.progression.classes.main == "archer" and raw.players.host.progression.classes.sub == "assassin", "Classes are saved")
    var bad: Dictionary = raw.duplicate(true)
    bad.players.host.progression.classes.sub = "archer"
    _check(not STORE.validate(bad), "A subclass equal to the class is rejected")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Class checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
