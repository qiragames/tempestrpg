extends SceneTree
## Attributes (M12a): four points a level (old characters have theirs), spending raises the right
## stats (STR damage, DEX speed/recovery/crits, INT Magicules/skills, VIT HP/defence), the reset
## gives everything back, the intent, the equipment window and saves.
const ATTRIBUTES := preload("res://scripts/progression/attributes.gd")
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

func _run() -> void:
    _check(ATTRIBUTES.total_points({"level": 1}) == 0 and ATTRIBUTES.total_points({"level": 42}) == 164 and ATTRIBUTES.unspent({"level": 42}) == 164, "Four points per level after the first (a level 42 character has 164)")
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-attributes-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24828, dir.path_join("attributes.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    _check(not session.apply_action(me, "attribute", {"key": "str"}), "No points at level 1")
    me.gain_experience(LEVELING.xp_for_level(11), "test")
    _check(ATTRIBUTES.unspent(me.progression) == 4 * (int(me.progression.level) - 1), "Levelling up gives points (%d)" % ATTRIBUTES.unspent(me.progression))
    var hp: int = me.get_node("Health").maximum
    var mp: float = me.get_node("Magicules").maximum
    var speed: float = me.current_speed()
    for _i in range(5):
        session.apply_action(me, "attribute", {"key": "vit"})
    _check(me.get_node("Health").maximum == hp + 5 * ATTRIBUTES.VIT_HP and me.get_node("Health").armor >= 0, "Vitality: +4 HP a point")
    for _i in range(5):
        session.apply_action(me, "attribute", {"key": "int"})
    _check(is_equal_approx(me.get_node("Magicules").maximum, mp + 5 * ATTRIBUTES.INT_MAGICULES) and ATTRIBUTES.skill_factor(me.progression) > 1.0, "Intelligence: more Magicules and stronger skills")
    for _i in range(10):
        session.apply_action(me, "attribute", {"key": "dex"})
    _check(me.current_speed() > speed and ATTRIBUTES.recovery_factor(me.progression) < 1.0 and ATTRIBUTES.crit_chance(me.progression) > 0.0, "Dexterity: faster, quicker strikes, critical hits")
    for _i in range(10):
        session.apply_action(me, "attribute", {"key": "str"})
    _check(ATTRIBUTES.damage_factor(me.progression) > 1.07, "Strength: more damage")
    # A strike hits harder with Strength.
    var foe = load("res://scenes/enemies/forest_gnasher.tscn").instantiate()
    foe.entity_id = "attribute_test_gnasher"
    foe.position = me.position + Vector2(14, 0)
    world.add_child(foe)
    world.wire_enemy(foe)
    foe.set_physics_process(false)
    foe.get_node("Health").maximum = 100000
    foe.get_node("Health").current = 100000
    var strike: Node = me.get_node("MeleeAttack")
    strike.cooldown_left = 0.0
    strike.attack(Vector2.RIGHT)
    await _frames(2)
    var dealt: int = 100000 - foe.get_node("Health").current
    _check(dealt > 0, "Striking with attributes deals damage (%d)" % dealt)
    _check(not session.apply_action(me, "attribute", {"key": "luck"}), "Unknown attributes are refused")
    var spent: int = ATTRIBUTES.total_points(me.progression) - ATTRIBUTES.unspent(me.progression)
    _check(spent == 30, "30 points spent")
    me.reset_attributes()
    _check(ATTRIBUTES.unspent(me.progression) == ATTRIBUTES.total_points(me.progression) and me.get_node("Health").maximum == hp and is_equal_approx(me.get_node("Magicules").maximum, mp), "A reset gives every point back and restores the maxima")
    session.apply_action(me, "attribute", {"key": "vit"})
    # The window.
    var hud: CanvasLayer = world.get_node("HUD")
    hud.quest_panel._queue.clear()
    hud.dialog_panel.close()
    hud.open_inventory()
    await _frames(2)
    for child in hud._modal.get_children():
        if child is Button and child.text == "Equipment":
            child.pressed.emit()
    await _frames(3)
    _check(hud.gear_panel.visible and String(hud.gear_panel.get_node("Attr_vit").text).contains("VIT  1") and hud.gear_panel.get_node("AttrPlus_str").visible, "The equipment window shows attributes with a + while points are left")
    # Saves.
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("attributes.json")))
    _check(int(raw.players.host.progression.attributes.vit) == 1, "Attributes are saved")
    var bad: Dictionary = raw.duplicate(true)
    bad.players.host.progression.attributes.str = 999
    _check(not STORE.validate(bad), "More points than the level gives are rejected")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Attribute checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
