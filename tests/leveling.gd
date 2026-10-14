extends SceneTree
## Experience and levels (step 17): curve, validation, host-only awards for defeats, absorptions
## and trials, credit to the defeating character only, skill points, HUD text, save and migration.
const LEVELING := preload("res://scripts/progression/leveling.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const HUD := preload("res://scripts/ui/game_hud.gd")
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
func _creature(id: String, difficulty: int, at: Vector2) -> Node2D:
    var enemy = GNASHER.instantiate()
    enemy.entity_id = id
    enemy.difficulty = difficulty
    enemy.position = at
    world.add_child(enemy)
    world.wire_enemy(enemy)
    enemy.set_physics_process(false)
    return enemy
func _progress(level: int, experience: int, points: int) -> Dictionary:
    return {"level": level, "experience": experience, "skill_points": points, "race": "Slime", "quests": {}, "equipment": {}}

func _run() -> void:
    # --- Curve and validation
    # 24b curve: 100 * (level - 1)^2.8 -> 100, 696, 2167, 4850, ... (tuned by tests/balance_probe.gd)
    _check(LEVELING.xp_for_level(1) == 0 and LEVELING.xp_for_level(2) == 100 and LEVELING.xp_for_level(3) == 696 and LEVELING.xp_for_level(4) == 2167 and LEVELING.xp_for_level(5) == 4850, "Level curve (24b): 100, 696, 2167, 4850, ...")
    var increasing := true
    for level in range(2, LEVELING.LEVEL_CAP):
        increasing = increasing and LEVELING.xp_for_level(level + 1) - LEVELING.xp_for_level(level) > LEVELING.xp_for_level(level) - LEVELING.xp_for_level(level - 1)
    _check(increasing and LEVELING.max_experience() > 45000, "Each level needs more XP than the one before (long tail to level 20: %d XP)" % LEVELING.max_experience())
    _check(LEVELING.level_for(0) == 1 and LEVELING.level_for(99) == 1 and LEVELING.level_for(100) == 2 and LEVELING.level_for(695) == 2 and LEVELING.level_for(696) == 3, "Level follows total experience")
    _check(LEVELING.level_for(LEVELING.max_experience()) == LEVELING.LEVEL_CAP and LEVELING.level_for(99999999) == LEVELING.LEVEL_CAP, "Levels stop at the M4 cap of %d" % LEVELING.LEVEL_CAP)
    _check(LEVELING.valid(_progress(1, 0, 0)) and LEVELING.valid(_progress(3, 2000, 2)) and LEVELING.valid(_progress(3, 2000, 0)), "Consistent progression is valid (points may be spent)")
    var fractional := _progress(2, 400, 0)
    fractional["experience"] = 400.5
    var bad := [_progress(2, 10, 0), _progress(1, 400, 0), _progress(3, 2000, 4), _progress(1, -5, 0), _progress(1, 0, -1), _progress(LEVELING.LEVEL_CAP, LEVELING.max_experience() + 1, 0), fractional]
    var rejected := true
    for entry in bad:
        rejected = rejected and not LEVELING.valid(entry)
    var missing := _progress(1, 0, 0)
    missing.erase("skill_points")
    _check(rejected and not LEVELING.valid(missing), "Level/XP mismatches, too many points, negative, fractional, over-cap and missing points are rejected")
    # --- Awards on an offline world (host authority)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    world.system_message.connect(func(message: String): messages.append(message))
    await _frames()
    var actor = world.get_local_player()
    actor.position = Vector2(100, 600)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    _check(actor.progression.level == 1 and actor.progression.experience == 0 and actor.progression.skill_points == 1, "New characters start at level 1 with no XP and one skill point")
    actor.gain_experience(400, "test")
    _check(actor.progression.level == 2 and actor.progression.experience == 400 and actor.progression.skill_points == 2, "Reaching 100 XP gives level 2 and one more skill point")
    _check(messages.any(func(m): return m.contains("+400 XP") and m.contains("Level 2 reached")), "Level-up is announced")
    actor.gain_experience(4400, "test")
    _check(actor.progression.level == 4 and actor.progression.skill_points == 4, "A large award can grant several levels and points at once")
    actor.gain_experience(0, "test")
    actor.gain_experience(-50, "test")
    _check(actor.progression.experience == 4800, "Zero or negative awards change nothing")
    # Defeat credit goes to the character who landed the defeating blow.
    var easy := _creature("xp_easy", 0, Vector2(140, 600))
    easy.get_node("Health").take_damage(999, actor)
    _check(actor.progression.experience == 4800 + LEVELING.DEFEAT_XP[0], "Defeating an Easy creature gives %d XP" % LEVELING.DEFEAT_XP[0])
    var elite := _creature("xp_elite", 2, Vector2(160, 600))
    elite.get_node("Health").take_damage(30, actor)
    var other = load("res://scenes/player/player.tscn").instantiate()
    other.character_id = "rival"
    other.local_controlled = false
    other.position = Vector2(100, 560)
    world.add_child(other)
    await _frames(1)
    var before: int = actor.progression.experience
    elite.get_node("Health").immunity_left = 0.0
    elite.get_node("Health").take_damage(999, other)
    # 24a (user decision): everyone with at least 10% of the damage gets the full XP.
    _check(actor.progression.experience == before + LEVELING.DEFEAT_XP[2] and other.progression.experience == LEVELING.DEFEAT_XP[2], "Everyone with at least 10%% of the damage gets the full XP (Elite: %d XP each)" % LEVELING.DEFEAT_XP[2])
    before = actor.progression.experience
    var helper_before: int = other.progression.experience
    var shared := _creature("xp_share", 1, Vector2(170, 600))
    shared.get_node("Health").take_damage(28, actor)
    shared.get_node("Health").immunity_left = 0.0
    shared.get_node("Health").take_damage(999, other)
    _check(actor.progression.experience == before + LEVELING.DEFEAT_XP[1] and other.progression.experience == helper_before, "A last hit worth under 10%% of the damage earns no XP (the main attacker still does)")
    before = actor.progression.experience
    var unowned := _creature("xp_none", 1, Vector2(180, 600))
    unowned.get_node("Health").take_damage(999)
    _check(actor.progression.experience == before and other.progression.experience == helper_before, "Defeats without a character source give no XP")
    var trial_creature := _creature("trial_xp", 1, Vector2(200, 600))
    trial_creature.drops_rewards = false
    trial_creature.get_node("Health").take_damage(999, actor)
    _check(actor.progression.experience == before, "Trial creatures give no defeat XP")
    # A real strike through MeleeAttack passes the striker as the source.
    var struck := _creature("xp_strike", 0, actor.position + Vector2(0, 18))
    struck.get_node("Health").current = 1
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    actor.get_node("Magicules")._current = actor.get_node("Magicules").maximum
    actor.get_node("MeleeAttack").attack(Vector2.DOWN)
    await _frames(1)
    _check(struck.get_node("Health").current == 0 and actor.progression.experience == before + LEVELING.DEFEAT_XP[0], "A basic strike's defeating blow earns the striker XP")
    # Completing an absorption earns XP by tier.
    before = actor.progression.experience
    var absorbable := _creature("xp_absorb", 1, Vector2(300, 600))
    absorbable.get_node("Health").take_damage(999)
    actor.position = absorbable.position + Vector2(-14, 0)
    await _frames()
    actor.get_node("Magicules")._current = actor.get_node("Magicules").maximum
    var absorption = actor.get_node("Absorption")
    var started: bool = absorption.attempt_absorb()
    absorption._process(2.0)
    _check(started and not absorption.active and actor.progression.experience == before + LEVELING.ABSORB_XP[1], "A completed absorption gives %d XP (Standard)" % LEVELING.ABSORB_XP[1])
    # A completed trial credits only its starter.
    before = actor.progression.experience
    var rival_before: int = other.progression.experience
    world.trial.state.active = true
    world.trial.state.owner = actor.character_id
    world.trial._finish(true, "")
    _check(actor.progression.experience == before + LEVELING.TRIAL_XP and other.progression.experience == rival_before, "Completing the trial gives its starter %d XP" % LEVELING.TRIAL_XP)
    world.trial.state.active = true
    world.trial.state.owner = actor.character_id
    world.trial._finish(false, "Trial failed: test.")
    _check(actor.progression.experience == before + LEVELING.TRIAL_XP, "A failed trial gives nothing")
    # The cap holds experience and level.
    other.gain_experience(LEVELING.max_experience() * 2, "test")
    _check(other.progression.level == LEVELING.LEVEL_CAP and other.progression.experience == LEVELING.max_experience() and other.progression.skill_points == LEVELING.LEVEL_CAP, "Awards stop at the level cap")
    # Replicas never award experience.
    var session: Node = root.get_node("GameSession")
    session.replica_world = true
    before = actor.progression.experience
    actor.gain_experience(100, "test")
    _check(actor.progression.experience == before, "Clients cannot award themselves experience")
    session.replica_world = false
    # --- HUD text
    _check(HUD.level_text(_progress(1, 20, 0)) == "Lv 1 · XP 20 / 100", "HUD shows level and XP toward the next level")
    _check(HUD.level_text(_progress(3, 2000, 2)) == "Lv 3 · XP 2000 / 2167 · 2 skill points" and HUD.level_text(_progress(LEVELING.LEVEL_CAP, LEVELING.max_experience(), 0)) == "Lv %d · XP max" % LEVELING.LEVEL_CAP, "HUD shows unspent points and the cap")
    await _frames(1)
    _check(world.get_node("HUD")._level.text == HUD.level_text(actor.progression), "Live HUD label follows the local character")
    # --- Save, reload, validation and migration
    other.queue_free()
    await _frames(1)
    var dir := OS.get_temp_dir().path_join("tempestrpg-xp-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var path := dir.path_join("xp.json")
    var expected: Dictionary = actor.progression.duplicate(true)
    _check(session.start_host(24630, path, false, {"name": "XP", "seed": 0, "created": 1, "last_played": 1}) == OK, "World with progression hosted")
    _check(session.save_world() == OK, "Progression saves")
    var loaded: Dictionary = STORE.load_world(path)
    _check(loaded.ok and loaded.data.version == STORE.VERSION and loaded.data.players.host.progression.level == expected.level and loaded.data.players.host.progression.experience == expected.experience and loaded.data.players.host.progression.skill_points == expected.skill_points, "Level, XP and skill points round-trip through the save")
    var forged: Dictionary = loaded.data.duplicate(true)
    forged.players.host.progression.skill_points = 99
    var forged_level: Dictionary = loaded.data.duplicate(true)
    forged_level.players.host.progression.level = LEVELING.LEVEL_CAP
    _check(not STORE.validate(forged) and not STORE.validate(forged_level), "Forged skill points or levels are rejected")
    var legacy: Dictionary = loaded.data.duplicate(true)
    legacy.version = 13
    legacy.players.host.progression = {"level": 3, "experience": 45, "race": "Slime", "quests": {}, "equipment": {}}
    var migrated: Variant = STORE.migrate(legacy)
    _check(migrated is Dictionary and STORE.validate(migrated) and migrated.players.host.progression.level == 3 and migrated.players.host.progression.experience == LEVELING.xp_for_level(3) and migrated.players.host.progression.skill_points == 3, "v13 characters keep their level (XP raised to its threshold) and gain its skill points (one per level from v15)")
    legacy.players.host.progression = {"level": 1, "experience": 0, "race": "Slime", "quests": {}, "equipment": {}}
    migrated = STORE.migrate(legacy)
    _check(migrated is Dictionary and STORE.validate(migrated) and migrated.players.host.progression.skill_points == 1, "Fresh v13 characters migrate to level 1 with its one point")
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Leveling checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
