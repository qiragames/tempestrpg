extends SceneTree
## Class weapons and skills (M12c): staffs (a free magic bolt that grows with Intelligence) and fist
## weapons (very fast, every third jab harder) in the catalogue at every level and in the forge;
## the main class teaches its first skill when chosen and its second at level 25; changing the
## class swaps them; class skills on the hotbar survive saving and are checked on load.
const CLASSES := preload("res://scripts/progression/class_catalogue.gd")
const CLASS_SKILLS := preload("res://scripts/skills/class_skills.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const CRAFTING := preload("res://scripts/professions/crafting_catalogue.gd")
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

func _base(weapon: String, level: int) -> String:
    for id in GEAR.BASES:
        var spec: Dictionary = GEAR.BASES[id]
        if spec.get("weapon", "") == weapon and int(spec.get("level", 1)) == level and int(spec.get("min_rarity", 0)) == 0 and not spec.has("unique"):
            return id
    return ""

func _dummy(world: Node2D, at: Vector2, name: String) -> Node2D:
    var dummy = load("res://scenes/enemies/forest_gnasher.tscn").instantiate()
    dummy.entity_id = name
    dummy.drops_rewards = false
    dummy.position = at
    world.add_child(dummy)
    dummy.set_physics_process(false)
    dummy.get_node("Health").maximum = 100000
    dummy.get_node("Health").current = 100000
    return dummy

func _run() -> void:
    # --- Catalogue
    var staff_levels := {}
    var fist_levels := {}
    for id in GEAR.BASES:
        var kind: String = GEAR.BASES[id].get("weapon", "")
        if kind == "staff":
            staff_levels[int(GEAR.BASES[id].level)] = true
        elif kind == "fist":
            fist_levels[int(GEAR.BASES[id].level)] = true
    _check(staff_levels.has(1) and staff_levels.has(48) and fist_levels.has(1) and fist_levels.has(48), "Staffs and fist weapons exist from level 1 to the level-48 tier")
    _check(CLASSES.class_for_weapon("staff") == "mage" and CLASSES.class_for_weapon("fist") == "monk" and GEAR.WEAPONS.has("staff") and GEAR.WEAPONS.has("fist"), "Staffs belong to the Mage, fist weapons to the Monk")
    _check("staff" in CRAFTING.WEAPON_TYPES and "fist" in CRAFTING.WEAPON_TYPES and CRAFTING.FORGE.has("staff") and CRAFTING.FORGE.has("fist"), "Both can be forged")
    _check(CLASS_SKILLS.BY_CLASS.size() == 7 and CLASS_SKILLS.SKILLS.size() == 14, "Fourteen class skills, two per class")
    for id in CLASS_SKILLS.SKILLS:
        var skill: Resource = load(CLASS_SKILLS.SKILLS[id])
        _check(skill != null and String(skill.id) == id and skill.damage > 0 and ResourceLoader.exists("res://assets/game/ui/skills/%s.png" % id), "Class skill %s loads, deals damage and has an icon" % id)
    # --- World
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-class-skills-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24831, dir.path_join("skills.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var book: Node = me.get_node("SkillBook")
    var master: Node = world.class_master
    var camp: Node = world.camp
    var camp_before: Dictionary = camp.state.duplicate(true)
    camp.state.founded = true
    camp.state.founder = "host"
    await _frames(2)
    me.global_position = master.position_in_world() + Vector2(10, 0)
    # Mage: the first skill at once.
    _check(session.apply_action(me, "class", {"operation": "choose", "slot": "main", "id": "mage"}), "Mage chosen")
    _check(book.knows(&"fireball") and book.is_active(&"fireball") and not book.knows(&"frost_nova") and &"fireball" in book._slots, "The Mage learns Fireball at once (on the hotbar), Frost Nova not yet")
    me.gain_experience(LEVELING.xp_for_level(25), "test")
    master._check_left = 0.0
    master._physics_process(0.016)
    _check(book.knows(&"frost_nova"), "Level 25: Frost Nova follows")
    # The staff: a free bolt that grows with Intelligence.
    var staff: Dictionary = GEAR.roll(_base("staff", 1), 0, RandomNumberGenerator.new())
    staff["id"] = "item_cls_staff000001"
    me.add_item(staff)
    _check(me.equip("item_cls_staff000001", "weapon"), "A Mage wields a staff")
    var attack: Node = me.get_node("MeleeAttack")
    var magicules: float = me.get_node("Magicules").current
    attack.cooldown_left = 0.0
    _check(attack.attack(Vector2.RIGHT), "The staff casts")
    var bolt: Node2D = null
    for child in world.get_children():
        if child.get_script() == load("res://scripts/combat/arrow.gd"):
            bolt = child
    _check(bolt != null and bolt.magic and is_equal_approx(me.get_node("Magicules").current, magicules), "...a magic bolt that costs no Magicules")
    var plain: int = bolt.damage if bolt != null else 0
    for _i in range(20):
        me.spend_attribute("int")
    attack.cooldown_left = 0.0
    attack.attack(Vector2.RIGHT)
    var stronger: Node2D = null
    for child in world.get_children():
        if child.get_script() == load("res://scripts/combat/arrow.gd") and child != bolt:
            stronger = child
    _check(stronger != null and stronger.damage > plain, "Intelligence makes the bolt stronger (%d → %d)" % [plain, stronger.damage if stronger != null else 0])
    # Using a class skill.
    me.get_node("Magicules")._current = me.get_node("Magicules").maximum
    attack.cooldown_left = 0.0
    _check(attack.attack_skill(Vector2.RIGHT, &"frost_nova"), "Frost Nova can be cast")
    # Monk: the skills swap; fists jab fast and every third hits harder.
    me.progression["zeni"] = 1000000
    _check(session.apply_action(me, "class", {"operation": "choose", "slot": "main", "id": "monk"}), "Changed to Monk")
    _check(not book.knows(&"fireball") and not book.knows(&"frost_nova") and book.knows(&"palm_strike") and book.knows(&"hundred_fists") and not &"fireball" in book._slots, "The Mage's skills are gone (also from the hotbar); the Monk's two arrived")
    _check(me.progression.equipment.get("weapon", "") == "item_cls_staff000001", "A Common staff stays in hand (any weapon up to Rare works aside from the class)")
    var fist: Dictionary = GEAR.roll(_base("fist", 1), 0, RandomNumberGenerator.new())
    fist["id"] = "item_cls_fist0000001"
    me.add_item(fist)
    _check(me.equip("item_cls_fist0000001", "weapon") and GEAR.WEAPONS.fist.recovery < GEAR.WEAPONS.dagger.recovery, "A Monk wears fist weapons, the fastest weapon")
    var target := _dummy(world, me.global_position + Vector2(13, 0), "practice_fist")
    await _frames(2)
    var losses: Array = []
    for _hit in range(3):
        var before: int = target.get_node("Health").current
        target.get_node("Health").immunity_left = 0.0
        attack.cooldown_left = 0.0
        attack.attack(Vector2.RIGHT)
        losses.append(before - target.get_node("Health").current)
    _check(losses.size() == 3 and losses[0] > 0 and losses[2] > losses[0], "The third jab in a row hits harder (%s)" % str(losses))
    # Saves: class skills on the hotbar are valid; a skill the class does not give is not.
    camp.state = camp_before
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("skills.json")))
    var state: Dictionary = raw.players.host
    _check(&"palm_strike" in book._slots and "palm_strike" in state.slots and STORE.validate(raw), "Class skills on the hotbar are saved and valid")
    var bad: Dictionary = raw.duplicate(true)
    var slot: int = bad.players.host.slots.find("palm_strike")
    bad.players.host.slots[slot] = "fireball"
    _check(not STORE.validate(bad), "A class skill from another class is rejected")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Class skill checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
