extends SceneTree
## Skill tree (step 17c): data, points, stat and skill nodes, prerequisites, race ownership,
## activation of learned skills before use, host intent, the K window, saves and migration.
const TREE := preload("res://scripts/skills/skill_tree.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
var checks := 0
var failures := 0
var world: Node2D
var messages: Array = []
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
func _hit(actor: Node2D, id: String, skill: StringName = &"") -> int:
    var enemy = GNASHER.instantiate()
    enemy.entity_id = id
    enemy.position = actor.position + Vector2(0, 18)
    world.add_child(enemy)
    enemy.set_physics_process(false)
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    actor.get_node("Magicules")._current = actor.get_node("Magicules").maximum
    if skill == &"":
        actor.get_node("MeleeAttack").attack(Vector2.DOWN)
    else:
        actor.get_node("MeleeAttack").attack_skill(Vector2.DOWN, skill)
    var dealt: int = 30 - enemy.get_node("Health").current
    enemy.queue_free()
    return dealt

func _run() -> void:
    # --- Data
    _check(TREE.resource_errors().is_empty(), "Tree nodes and skills are consistent: %s" % [TREE.resource_errors()])
    var shape := true
    for race in ["Slime", "Human", "Demon"]:
        var nodes: Array = TREE.nodes_for(race)
        shape = shape and nodes.size() == 8 and TREE.granted_skills(nodes).size() == 2
    _check(shape, "Each race has its own tree: 8 nodes, 2 of them new skills")
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    world.system_message.connect(func(message: String): messages.append(message))
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    actor.position = Vector2(100, 600)
    var book = actor.get_node("SkillBook")
    var progression: Dictionary = actor.progression
    _check(progression.level == 1 and progression.skill_points == 1 and progression.tree == TREE.empty() and TREE.valid(progression, []), "New characters start at level 1 with 1 skill point and an empty tree")
    # --- Learned skills wait for activation
    book.record_analysis(&"forest_gnasher")
    _check(book.knows(&"rending_bite") and not book.is_active(&"rending_bite") and book.skill_at_slot(0) == null, "Absorbing learns Rending Bite, but it is not active or slotted")
    _check(_hit(actor, "t_locked", &"rending_bite") == 0 and not book.assign_slot(0, &"rending_bite"), "An inactive skill cannot be used or put on the hotbar")
    _check(actor.activate_skill("rending_bite") and progression.skill_points == 0 and book.is_active(&"rending_bite") and book.skill_at_slot(0).id == &"rending_bite", "Activating costs 1 point and places the skill on the hotbar")
    _check(_hit(actor, "t_active", &"rending_bite") == 20, "The activated skill works")
    messages.clear()
    _check(not actor.activate_skill("rending_bite") and not actor.activate_skill("thorn_lash") and not actor.buy_node("slime_vitality"), "No double activation, no activating unlearned skills, no buying without points")
    _check(messages.any(func(m): return m.contains("No skill points")), "The player is told why a purchase failed")
    # --- Stat and skill nodes
    actor.gain_experience(LEVELING.xp_for_level(4), "test")
    _check(progression.level == 4 and progression.skill_points == 3, "Levels 2–4 give three more points")
    _check(not actor.buy_node("slime_acid_splash") and not actor.buy_node("human_endurance") and not actor.buy_node("nope"), "Skill nodes need their row's stat nodes; other races' and unknown nodes are refused")
    var hp: int = actor.get_node("Health").maximum
    var mp: float = actor.get_node("Magicules").maximum
    _check(actor.buy_node("slime_vitality") and actor.get_node("Health").maximum == hp + 10 and actor.get_node("Health").current == actor.get_node("Health").maximum, "Gel Vitality: +10 max HP (and current HP)")
    _check(actor.buy_node("slime_reserve") and actor.get_node("Magicules").maximum == mp + 10, "Aura Reserve: +10 max Magicules")
    _check(not actor.buy_node("slime_vitality"), "A node is bought once")
    _check(actor.buy_node("slime_acid_splash") and book.is_active(&"acid_splash") and book.skill_at_slot(1).id == &"acid_splash" and progression.skill_points == 0, "Every third node is a new skill: Acid Splash, active at once and slotted")
    _check(_hit(actor, "t_acid", &"acid_splash") == 18, "The tree skill works (Acid Splash 18 damage)")
    _check(TREE.valid(progression, book.evidence_ids()) and progression.skill_points + TREE.spent(progression.tree) == progression.level, "Points spent plus unspent always equal the level")
    # A Human's Weapon Drill raises the basic strike.
    var human = load("res://scenes/player/player.tscn").instantiate()
    human.character_id = "human_tester"
    human.local_controlled = false
    human.position = Vector2(220, 600)
    world.add_child(human)
    await _frames(1)
    human.choose_race("Human")
    _check(_hit(human, "t_human_plain") == 14 and human.buy_node("human_drill") and _hit(human, "t_human_drill") == 15, "Human Weapon Drill: basic strike 14 → 15")
    _check(not human.buy_node("slime_vitality"), "A Human cannot buy Slime nodes")
    human.queue_free()
    # --- Host intent and client guard
    var session: Node = root.get_node("GameSession")
    var rejected: int = session.rejected_requests
    actor.gain_experience(LEVELING.xp_for_level(5) - progression.experience, "test")
    _check(session.apply_action(actor, "tree", {"operation": "buy", "id": "slime_digest"}) and "slime_digest" in progression.tree.nodes, "The host applies a tree purchase intent")
    session.apply_action(actor, "tree", {"operation": "steal", "id": "slime_bounce"})
    session.apply_action(actor, "tree", {"operation": "buy"})
    session.apply_action(actor, "tree", {"operation": "buy", "id": 7})
    _check(session.rejected_requests == rejected + 3, "Malformed tree intents are rejected")
    session.replica_world = true
    _check(not actor.buy_node("slime_bounce") and not actor.activate_skill("rending_bite"), "Clients cannot change their tree locally")
    session.replica_world = false
    # --- The K window
    var hud = world.get_node("HUD")
    actor.gain_experience(LEVELING.xp_for_level(6) - progression.experience, "test")
    var event := InputEventAction.new()
    event.action = "skill_tree"
    event.pressed = true
    Input.parse_input_event(event)
    await _frames(1)
    _check(hud.skill_tree.visible and paused, "K opens the skill tree and pauses offline play")
    _check(hud.skill_tree._node_buttons.size() == 8 and hud.skill_tree._title.text.contains("Slime") and hud.skill_tree._title.text.contains("1 skill point"), "The window shows the Slime tree and the unspent points")
    _check(hud.skill_tree._node_buttons.slime_vitality.text.begins_with("✓") and not hud.skill_tree._node_buttons.slime_bounce.disabled and hud.skill_tree._node_buttons.slime_engulf.disabled, "Owned nodes are ticked; affordable nodes enabled; locked ones disabled")
    hud.skill_tree._node_buttons.slime_bounce.pressed.emit()
    await _frames(1)
    _check("slime_bounce" in progression.tree.nodes and actor.move_speed == 100.0, "Clicking a node buys it (Bounce: +5 move speed)")
    _check(hud.skill_tree._activate_buttons[0].text == "Active ✓" and hud.skill_tree._activate_buttons[0].disabled, "Learned skills list shows Rending Bite as active")
    hud.skill_tree.close()
    await _frames(1)
    _check(not hud.skill_tree.visible and not paused, "Closing resumes")
    # --- Save, reload, validation and migration
    var dir := OS.get_temp_dir().path_join("tempestrpg-tree-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var path := dir.path_join("tree.json")
    var expected: Dictionary = progression.duplicate(true)
    var max_hp: int = actor.get_node("Health").maximum
    _check(session.start_host(24650, path, false, {"name": "Tree", "seed": 0, "created": 1, "last_played": 1}) == OK and session.save_world() == OK, "World with a skill tree saves")
    var saved: Dictionary = STORE.load_world(path)
    _check(saved.ok and saved.data.players.host.progression.tree == expected.tree and saved.data.players.host.skill_ids == ["rending_bite"] and saved.data.players.host.slots[1] == "acid_splash", "The save keeps nodes and activations; tree skills follow from nodes, not the learned list")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24650, path, false) == OK, "Tree world reloads")
    var reloaded = world.get_local_player()
    _check(reloaded.progression.tree == expected.tree and reloaded.progression.skill_points == expected.skill_points and reloaded.get_node("Health").maximum == max_hp and reloaded.get_node("SkillBook").is_active(&"acid_splash") and reloaded.get_node("SkillBook").is_active(&"rending_bite") and reloaded.get_node("SkillBook").skill_at_slot(1).id == &"acid_splash", "Reload restores nodes, activations, stats, tree skills and the hotbar")
    session.stop_session(false)
    var data: Dictionary = saved.data
    var forged := []
    var doc: Dictionary
    doc = data.duplicate(true); doc.players.host.progression.tree.nodes.append("human_drill"); forged.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.tree.nodes = ["slime_acid_splash"]; forged.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.skill_points += 1; forged.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.tree.active.append("thorn_lash"); forged.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.tree.free.append("rending_bite"); doc.players.host.progression.skill_points += 1; doc.players.host.progression.tree.active.erase("rending_bite"); forged.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.tree.active = []; doc.players.host.progression.skill_points += 1; forged.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.erase("tree"); forged.append(doc)
    var rejected_all := true
    for index in range(forged.size()):
        if STORE.validate(forged[index]):
            rejected_all = false
            push_error("Forged tree doc %d was accepted" % index)
    _check(rejected_all, "Rejected: other race's node, missing prerequisite, extra points, activating an unlearned skill, free without active, slotted inactive skill, missing tree")
    var legacy: Dictionary = data.duplicate(true)
    legacy.version = 14
    legacy.players.host.progression = {"level": 2, "experience": 60, "skill_points": 1, "race": "Slime", "quests": {}, "equipment": {}}
    legacy.players.host.slots = ["rending_bite", "", "", ""]
    var migrated: Variant = STORE.migrate(legacy)
    _check(migrated is Dictionary and STORE.validate(migrated) and migrated.players.host.progression.skill_points == 2 and migrated.players.host.progression.tree == {"nodes": [], "active": ["rending_bite"], "free": ["rending_bite"]}, "v14 characters gain their level-1 point and keep learned skills active for free")
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Skill tree checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
