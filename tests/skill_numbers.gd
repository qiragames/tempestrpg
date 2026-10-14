extends SceneTree
## Step 24b numbers: skill damage from the cost curve (cost^0.75 against the Slime strike), every
## utility effect (slow, root, stun interrupting a bite, knockback, damage over time crediting the
## caster, area, dash, drain), creature level scaling, XP by level, the shown status for other
## peers and the v21 -> v22 migration keeping every character's level.
const FX := preload("res://scripts/skills/skill_effects.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
const SKILLS := ["thorn_lash", "acid_splash", "shadow_claw", "rending_bite", "power_slash", "engulf", "lunge", "piercing_fang", "dark_lance"]
var checks := 0
var failures := 0
var world: Node2D
var actor: CharacterBody2D
var serial := 0
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
func _target(offset: Vector2, hp: int = 300) -> Node2D:
    serial += 1
    var enemy = GNASHER.instantiate()
    enemy.entity_id = "sn_%d" % serial
    enemy.position = actor.position + offset
    world.add_child(enemy)
    world.wire_enemy(enemy)
    enemy.set_physics_process(false)
    enemy.get_node("Health").maximum = hp
    enemy.get_node("Health").current = hp
    return enemy
func _cast(skill: String, toward: Vector2 = Vector2.RIGHT) -> bool:
    var book = actor.get_node("SkillBook")
    book._known[StringName(skill)] = load("res://data/skills/%s.tres" % skill)
    if not skill in actor.progression.tree.active:
        actor.progression.tree.active.append(skill)
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    actor.get_node("Magicules")._current = actor.get_node("Magicules").maximum
    return actor.get_node("MeleeAttack").attack_skill(toward, StringName(skill))

func _run() -> void:
    # --- Curve
    var curve_ok := true
    for skill in SKILLS:
        var data: Resource = load("res://data/skills/%s.tres" % skill)
        curve_ok = curve_ok and data.damage == FX.damage_for(data.magicule_cost) and not FX.effects(skill).is_empty()
    _check(curve_ok, "Every damaging skill's damage follows the cost curve and has a utility effect")
    _check(FX.damage_for(2.0) == 12 and FX.damage_for(20.0) == 67 and FX.damage_for(20.0) < 12 * 10 and FX.damage_for(16.0) > FX.damage_for(6.0), "Damage grows with cost, sublinearly (10x the Slime strike's cost: 67 instead of 120)")
    # --- Levels and XP
    var gnasher_script := preload("res://scripts/enemies/forest_gnasher.gd")
    _check(gnasher_script.scaled_health(1, 2) == 30 and gnasher_script.scaled_health(1, 6) == 66 and gnasher_script.scaled_health(2, 12) == 204 and gnasher_script.scaled_damage(2, 12) == 33, "Creatures grow with level: +30% HP and +8% damage per level above their tier's base")
    _check(LEVELING.defeat_xp(1, 0) == 13 and LEVELING.defeat_xp(2, 1) == 21 and LEVELING.defeat_xp(4, 2) == 40 and LEVELING.defeat_xp(6, 1) == 35 and LEVELING.defeat_xp(12, 2) == 80, "XP by level and tier: the clearing's 13/21/40, Thornwood ~1.7x, Cinder Crater 2x")
    # --- World
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    actor = world.get_local_player()
    actor.position = Vector2(140, 600)
    await _frames(2)
    # Slow
    var slowed := _target(Vector2(18, 0))
    _check(_cast("thorn_lash") and slowed.get_node("Health").current == 300 - 34 and is_equal_approx(slowed._speed(), slowed.speed * 0.5) and slowed.shown_status == "slow", "Thorn Lash: 34 damage and halves the creature's speed (shown as slowed)")
    slowed._tick_status(2.1)
    _check(is_equal_approx(slowed._speed(), slowed.speed) and slowed.shown_status == "", "The slow wears off after 2 s")
    slowed.queue_free()
    # Damage over time crediting the caster, ignoring immunity
    var bleeding := _target(Vector2(18, 0))
    _cast("rending_bite")
    var after_hit: int = bleeding.get_node("Health").current
    bleeding._tick_status(1.0)
    _check(after_hit == 300 - 46 and bleeding.get_node("Health").current == after_hit - 5 and bleeding.credit.get(actor.character_id, 0) == 46 + 5, "Rending Bite bleeds 5 HP per second through immunity, credited to the caster")
    bleeding._tick_status(5.0)
    _check(bleeding.get_node("Health").current == after_hit - 15 and bleeding.dot_left == 0.0, "The bleed stops after 3 s (15 in total)")
    bleeding.queue_free()
    # Stun interrupts a bite wind-up; knockback pushes away
    var biting := _target(Vector2(18, 0))
    biting.state = biting.State.WINDUP
    var start: Vector2 = biting.position
    _cast("power_slash")
    _check(biting.state == biting.State.RECOVER and biting.stun_left > 0.5 and biting.position.x > start.x + 20.0, "Power Slash stuns (interrupting the bite wind-up) and knocks the creature back")
    biting.queue_free()
    # Root
    var rooted := _target(Vector2(18, 0))
    _cast("engulf")
    _check(rooted.root_left > 1.4 and rooted.dot_left > 1.9 and rooted.shown_status == "root", "Engulf roots for 1.5 s and dissolves for 2 s")
    rooted.queue_free()
    # Area
    actor.position = Vector2(140, 600)
    var a := _target(Vector2(30, 0))
    var b := _target(Vector2(18, 18))
    var c := _target(Vector2(-40, 0))
    _cast("acid_splash")
    _check(a.get_node("Health").current < 300 and b.get_node("Health").current < 300 and c.get_node("Health").current == 300 and a.dot_left > 0.0 and b.dot_left > 0.0, "Acid Splash hits everything in its area (not behind you) and burns")
    for enemy in [a, b, c]:
        enemy.queue_free()
    await _frames(1)
    # Dash
    actor.position = Vector2(140, 600)
    var dash_target := _target(Vector2(70, 0))
    _cast("lunge")
    _check(actor.position.x > 180.0 and dash_target.get_node("Health").current < 300, "Lunge dashes forward and strikes")
    dash_target.queue_free()
    await _frames(1)
    # Drain (Slime: only the skill's own drain)
    actor.position = Vector2(140, 600)
    var drained := _target(Vector2(18, 0))
    actor.get_node("Health").current = 50
    _cast("shadow_claw")
    _check(actor.get_node("Health").current == 50 + 12, "Shadow Claw drains 30% of its damage as HP (40 -> +12)")
    drained.queue_free()
    # Shown status reaches other peers through snapshots
    var shown := _target(Vector2(18, 0))
    _cast("dark_lance")
    var snapshot: Dictionary = CODEC.capture_entities(world)
    var entry: Dictionary = snapshot.enemies.filter(func(enemy): return enemy.id == shown.entity_id)[0]
    shown.shown_status = ""
    CODEC.apply_entities(world, snapshot, true)
    _check(entry.status == "slow" and shown.shown_status == "slow", "The strongest effect is replicated so friends see a slowed creature tinted")
    # --- Migration v21 -> v22 keeps the level and the progress within it (captured from a fresh
    # world: the skills above were injected into the test character for the effect checks).
    world.queue_free()
    await _frames()
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    var document: Dictionary = CODEC.capture_entities(world)
    document.merge({"version": 21, "world_id": "sn", "players": {"host": CODEC.capture_player(world.get_local_player())}, "progression": world.progression.duplicate(true)})
    document.players.host.progression.level = 4
    document.players.host.progression.experience = 400
    document.players.host.progression.skill_points = 4
    var migrated: Variant = STORE.migrate(document)
    var progression: Dictionary = migrated.players.host.progression if migrated is Dictionary else {}
    var expected: int = LEVELING.xp_for_level(4) + int(floor(0.5 * (LEVELING.xp_for_level(5) - LEVELING.xp_for_level(4))))
    _check(migrated is Dictionary and migrated.version == STORE.VERSION and progression.level == 4 and progression.skill_points == 4 and progression.experience == expected and STORE.validate(migrated), "v22 keeps each character's level, points and progress within the level on the new curve")
    world.queue_free()
    await _frames()
    print("Skill and number checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
