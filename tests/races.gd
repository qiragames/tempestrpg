extends SceneTree
## Playable races (step 17b): catalogue, creation stats, racial abilities (Human weapon mastery,
## Demon skill power and drain, Slime absorption and mimicry), host creation, saves and the menu.
const RACES := preload("res://scripts/races/race_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
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
func _creature(id: String, at: Vector2) -> Node2D:
    var enemy = GNASHER.instantiate()
    enemy.entity_id = id
    enemy.position = at
    world.add_child(enemy)
    world.wire_enemy(enemy)
    enemy.set_physics_process(false)
    return enemy
func _ready_to_act(actor: Node2D) -> void:
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    actor.get_node("Magicules")._current = actor.get_node("Magicules").maximum
## Strike a fresh Standard creature (30 HP) just below the actor; returns damage dealt.
func _hit(actor: Node2D, id: String, skill: StringName = &"") -> int:
    var enemy := _creature(id, actor.position + Vector2(0, 18))
    _ready_to_act(actor)
    var melee = actor.get_node("MeleeAttack")
    if skill == &"":
        melee.attack(Vector2.DOWN)
    else:
        melee.attack_skill(Vector2.DOWN, skill)
    var dealt: int = 30 - enemy.get_node("Health").current
    enemy.queue_free()
    return dealt

func _run() -> void:
    # --- Catalogue
    _check(RACES.ORDER == ["Slime", "Human", "Demon"] and RACES.valid("Human") and not RACES.valid("Orc") and not RACES.valid(3) and RACES.DEFAULT == "Slime", "Three playable races; unknown names are invalid")
    _check(RACES.RACES.Slime.mimic and not RACES.RACES.Human.mimic and not RACES.RACES.Demon.mimic, "Only Slimes can take mimic forms")
    _check(RACES.RACES.Slime.absorb_time < RACES.RACES.Human.absorb_time and RACES.RACES.Slime.absorb_heal > RACES.RACES.Demon.absorb_heal, "Everyone absorbs; the Slime absorbs fastest and heals most")
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    world.system_message.connect(func(message: String): messages.append(message))
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    actor.position = Vector2(100, 600)
    _check(actor.race() == "Slime" and actor.get_node("Health").maximum == 100 and actor.get_node("Magicules").maximum == 100.0, "Characters default to Slime (HP 100, Magicules 100)")
    # --- Creation stats
    _check(actor.choose_race("Human") and actor.race() == "Human" and actor.get_node("Health").maximum == 120 and actor.get_node("Health").current == 120 and actor.get_node("Magicules").maximum == 70.0 and actor.get_node("Magicules").current == 70.0, "Human: HP 120, Magicules 70, at full")
    _check(actor.choose_race("Demon") and actor.get_node("Health").maximum == 90 and actor.get_node("Magicules").maximum == 130.0 and actor.move_speed == 100.0, "Demon: HP 90, Magicules 130, a little faster")
    _check(not actor.choose_race("Orc") and actor.race() == "Demon", "Unknown races are refused")
    # --- Basic strike: Human weapon mastery
    actor.choose_race("Slime")
    var slime_hit := _hit(actor, "r_slime")
    var slime_recovery: float = actor.get_node("MeleeAttack").cooldown_left
    actor.choose_race("Human")
    var human_hit := _hit(actor, "r_human")
    var human_recovery: float = actor.get_node("MeleeAttack").cooldown_left
    _check(slime_hit == 10 and human_hit == 14, "Human weapon mastery: basic strike 14 instead of 10")
    _check(is_equal_approx(slime_recovery, 0.4) and is_equal_approx(human_recovery, 0.3), "Human attacks recover 25% faster (0.3 s instead of 0.4 s)")
    # --- Skills: Demon skill power and drain
    actor.get_node("SkillBook")._known[&"rending_bite"] = load("res://data/skills/rending_bite.tres")
    actor.progression.tree.active.append("rending_bite")
    var human_skill := _hit(actor, "r_human_skill", &"rending_bite")
    actor.choose_race("Demon")
    actor.get_node("Health").current = 50
    var demon_skill := _hit(actor, "r_demon_skill", &"rending_bite")
    _check(human_skill == 20 and demon_skill == 25, "Demon skills deal 25% more (Rending Bite 25 instead of 20)")
    _check(actor.get_node("Health").current == 55, "Demon drain heals 20% of skill damage dealt (+5 HP)")
    actor.get_node("Health").current = 90
    _hit(actor, "r_demon_full", &"rending_bite")
    _check(actor.get_node("Health").current == 90, "Drain never heals above maximum")
    actor.get_node("Health").current = 50
    _hit(actor, "r_demon_basic")
    _check(actor.get_node("Health").current == 50, "Drain applies to skills, not the basic strike")
    # --- Absorption speed and absorbed vitality
    for id in ["Slime", "Human"]:
        actor.choose_race(id)
        actor.get_node("Health").current = 40
        actor.get_node("Health").clear_regen()
        var corpse := _creature("r_corpse_" + id, Vector2(300, 600))
        corpse.get_node("Health").take_damage(999)
        actor.position = corpse.position + Vector2(-14, 0)
        await _frames()
        _ready_to_act(actor)
        var absorption = actor.get_node("Absorption")
        var started: bool = absorption.attempt_absorb()
        var channel: float = absorption.time_left
        absorption._process(3.0)
        var rate: float = actor.get_node("Health").regen_rate
        if id == "Slime":
            _check(started and is_equal_approx(channel, 1.2) and is_equal_approx(absorption.channel_seconds, 1.2) and is_equal_approx(rate, 2.5), "Slime: 1.2 s absorption, full absorbed vitality (25 HP)")
        else:
            _check(started and is_equal_approx(channel, 1.8) and is_equal_approx(absorption.channel_seconds, 1.8) and is_equal_approx(rate, 1.25), "Human: absorbs too, but 1.8 s and half the absorbed vitality")
        _check(not absorption.active and actor.get_node("SkillBook").evidence.analyzed.has("forest_gnasher"), "%s analysis completes and records evidence" % id)
    actor.position = Vector2(100, 600)
    # --- Mimicry is Slime-only
    actor.choose_race("Human")
    messages.clear()
    _check(not actor.try_transform("gnasher") and actor.form == "slime" and messages.any(func(m): return m.contains("Only Slimes")), "Humans cannot mimic, even with the analysis")
    actor.choose_race("Slime")
    actor.form_cooldown = 0.0
    _ready_to_act(actor)
    _check(actor.try_transform("gnasher") and actor.form == "gnasher", "Slimes can mimic after the analysis")
    actor.choose_race("Demon")
    _check(actor.form == "slime", "Becoming a non-Slime drops any mimic form")
    await _frames(1)
    _check(world.get_node("HUD").get_node("StrikeCost").text.contains("Demon: dark affinity"), "HUD shows the racial ability instead of mimic controls")
    # Clients cannot pick races.
    var session: Node = root.get_node("GameSession")
    session.replica_world = true
    _check(not actor.choose_race("Human") and actor.race() == "Demon", "Clients cannot change a race")
    session.replica_world = false
    # --- Hosting: the host picks a race once, saves keep it
    var dir := OS.get_temp_dir().path_join("tempestrpg-races-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var path := dir.path_join("races.json")
    world.queue_free()
    await _frames()
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24640, path, false, {"name": "Races", "seed": 0, "created": 1, "last_played": 1}, "Human") == OK and world.get_local_player().race() == "Human" and world.get_local_player().get_node("Health").maximum == 120, "A new world's host is created as the chosen race")
    var saved: Dictionary = STORE.load_world(path)
    _check(saved.ok and saved.data.players.host.progression.race == "Human" and saved.data.players.host.health.maximum == 120, "Race and its stats are saved")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24640, path, false, {}, "Demon") == OK and world.get_local_player().race() == "Human" and world.get_local_player().get_node("Health").maximum == 120, "Reloading keeps the host's race (the request applies only to new characters)")
    session.stop_session(false)
    var forged: Dictionary = saved.data.duplicate(true)
    forged.players.host.progression.race = "Orc"
    var missing: Dictionary = saved.data.duplicate(true)
    missing.players.host.progression.erase("race")
    _check(not STORE.validate(forged) and not STORE.validate(missing), "Saves with an unknown or missing race are rejected")
    var demon: Dictionary = saved.data.duplicate(true)
    demon.players.host.progression.race = "Demon"
    _check(STORE.validate(demon), "Each playable race validates")
    # Valid analysis evidence must not override a race's Slime-only mimic restriction.
    var restored_actor = world.get_local_player()
    restored_actor.get_node("SkillBook").record_analysis(&"forest_gnasher")
    var mimic_state: Dictionary = CODEC.capture_player(restored_actor)
    mimic_state.form.id = "gnasher"
    mimic_state.progression["race"] = "Slime"
    _check(STORE.validate_player(mimic_state, mimic_state.id), "An analyzed Slime mimic form remains valid")
    for race_id in ["Human", "Demon"]:
        mimic_state.progression["race"] = race_id
        mimic_state.form.id = "gnasher"
        _check(not STORE.validate_player(mimic_state, mimic_state.id), "%s saves cannot load a mimic form even with analysis evidence" % race_id)
        mimic_state.form.id = "slime"
        _check(STORE.validate_player(mimic_state, mimic_state.id), "%s base form with analysis evidence remains valid" % race_id)
    # --- Menu: race pickers pass the choice on
    var menu = load("res://scenes/menu/title_menu.tscn").instantiate()
    menu.worlds_dir = dir
    root.add_child(menu)
    await _frames(1)
    _check(menu._new_race.item_count == 3 and menu._join_race.item_count == 3 and menu._new_race.get_item_text(1).begins_with("Human · HP 120"), "New World and Join offer Slime, Human and Demon with their stats")
    menu._new_race.select(2)
    menu._name_field.text = "Demon World"
    menu.create_world()
    _check(session.pending_launch.get("race") == "Demon", "New World passes the chosen race to the host")
    session.pending_launch = {}
    menu._join_race.select(1)
    menu._address_field.text = "127.0.0.1"
    menu.join_world()
    _check(session.pending_launch.get("race") == "Human" and session.pending_launch.get("mode") == "join", "Join passes the chosen race for a new character")
    session.pending_launch = {}
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Race checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
