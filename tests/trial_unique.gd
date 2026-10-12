extends SceneTree
const CATALOGUE := preload("res://scripts/skills/skill_catalogue.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
var checks := 0
var failures := 0
var world: Node2D
var trial: Node2D
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
func _guest(id: String, at: Vector2, extra: bool) -> Node2D:
    var guest = load("res://scenes/player/player.tscn").instantiate()
    guest.character_id = id
    guest.local_controlled = false
    guest.position = at
    world.add_child(guest)
    if extra:
        guest.get_node("SkillBook").record_analysis(&"forest_gnasher")
        guest.get_node("SkillBook").record_analysis(&"thornback_gnasher")
    return guest
func _defeat_all() -> void:
    for creature in trial.creatures():
        creature.get_node("Health").take_damage(999)
    await _frames()
func _run() -> void:
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    trial = world.trial
    var session = root.get_node("GameSession")
    var actor = world.get_local_player()
    var book = actor.get_node("SkillBook")
    var pool = actor.get_node("Magicules")
    var melee = actor.get_node("MeleeAttack")
    var absorption = actor.get_node("Absorption")
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    await _frames()
    _check(CATALOGUE.resource_errors().is_empty(), "Catalogue consistent with Predator Focus: %s" % [CATALOGUE.resource_errors()])
    _check(CATALOGUE.RULES.predator_focus == {"tier": "Unique", "requires": ["piercing_fang"], "trial": "proving_trial"}, "Predator Focus needs Piercing Fang and the Proving Trial")
    _check(not trial.state.active and trial.STONE == Vector2(480, 100), "Trial stone waits idle in the north")
    # Starting rules.
    actor.position = trial.STONE + Vector2(0, 20)
    await _frames(1)
    _check(not trial.try_start(actor) and trial.creatures().is_empty(), "Without an Extra skill the stone stays silent")
    book.record_analysis(&"forest_gnasher")
    book.record_analysis(&"thornback_gnasher")
    actor.position = Vector2(480, 300)
    _check(not trial.try_start(actor), "Starting requires standing at the stone")
    actor.position = trial.STONE + Vector2(0, 20)
    actor.input_blocked = true
    _check(not session.apply_action(actor, "trial", {"operation": "start"}), "Open menus block the trial")
    actor.input_blocked = false
    _check(not session.apply_action(actor, "trial", {"operation": "start", "owner": "guest"}) and not session.apply_action(actor, "trial", {"operation": "win"}), "Forged trial payloads rejected")
    session.replica_world = true
    _check(not trial.try_start(actor), "Client replicas cannot start trials")
    session.replica_world = false
    var pickups_before: int = get_nodes_in_group("magicule_pickups").size()
    _check(session.apply_action(actor, "trial", {"operation": "start"}) and trial.state.active and trial.state.owner == "host", "Host intent starts the trial for its owner")
    var spawned: Array = trial.creatures()
    _check(spawned.size() == 3 and spawned.all(func(c): return c.entity_id.begins_with("trial_") and c.specimen == null and not c.drops_rewards and c.get_node("Health").maximum == 20), "Three Easy trial creatures without rewards appear")
    var helper = _guest("helper", trial.STONE + Vector2(20, 30), true)
    _check(not trial.try_start(helper), "Only one trial runs at a time")
    # Trial corpses cannot be analyzed.
    spawned[0].get_node("Health").take_damage(999)
    await _frames()
    helper.position = spawned[0].position + Vector2(-10, 0)
    await _frames(1)
    _check(not helper.get_node("Absorption").attempt_absorb(), "Trial corpses cannot be analyzed")
    # The helper finishes the creatures; only the owner is credited.
    await _defeat_all()
    trial._physics_process(0.016)
    _check(not trial.state.active and trial.creatures().is_empty(), "Defeating every creature ends the trial and clears the arena")
    _check("proving_trial" in book.evidence.trials and book.knows(&"predator_focus") and book.skill_at_slot(3).id == &"predator_focus", "Owner earns trial evidence and Predator Focus in slot 4")
    _check(helper.get_node("SkillBook").evidence.trials.is_empty() and not helper.get_node("SkillBook").knows(&"predator_focus"), "Helpers are not credited")
    _check(get_nodes_in_group("magicule_pickups").size() == pickups_before, "Trial creatures drop nothing")
    _check(not trial.try_start(actor), "A completed trial cannot be repeated for rewards")
    # Failure paths, each leaving no evidence.
    var challenger = _guest("challenger", trial.STONE + Vector2(0, 25), true)
    _check(trial.try_start(challenger), "Another qualified character may attempt it")
    challenger.position = trial.STONE + Vector2(0, 200)
    trial._physics_process(0.016)
    _check(not trial.state.active and trial.creatures().is_empty() and challenger.get_node("SkillBook").evidence.trials.is_empty(), "Leaving the circle fails the trial")
    challenger.position = trial.STONE + Vector2(0, 25)
    trial.try_start(challenger)
    trial.state.time_left = 0.01
    trial._physics_process(0.05)
    _check(not trial.state.active and challenger.get_node("SkillBook").evidence.trials.is_empty(), "Running out of time fails the trial")
    trial.try_start(challenger)
    challenger.get_node("Health").take_damage(999)
    await _frames()
    trial._physics_process(0.016)
    _check(not trial.state.active and challenger.get_node("SkillBook").evidence.trials.is_empty(), "Defeat fails the trial")
    var leaver = _guest("leaver", trial.STONE + Vector2(-20, 25), true)
    trial.try_start(leaver)
    world.remove_child(leaver)
    trial._physics_process(0.016)
    _check(not trial.state.active and trial.creatures().is_empty(), "Disconnect cancels the trial")
    leaver.queue_free()
    # Persistence: running trials and their creatures never enter saves, but do replicate.
    helper.position = trial.STONE + Vector2(20, 30)
    var runner = _guest("runner", trial.STONE + Vector2(0, 30), true)
    trial.try_start(runner)
    var snapshot: Dictionary = session.document()
    var saved: Dictionary = session.persistent_document()
    _check(snapshot.trial.active and snapshot.enemies.any(func(e): return e.id.begins_with("trial_")), "Snapshots replicate the running trial and its creatures")
    _check(not saved.has("trial") and not saved.enemies.any(func(e): return e.id.begins_with("trial_")), "Saves exclude the running trial and its creatures")
    trial._finish(false, "")
    # Predator Focus.
    pool._current = 100.0
    melee.cooldown_left = 0.0
    _check(melee.attack_skill(Vector2.RIGHT, &"predator_focus") and pool.current == 75.0 and absorption.focus_left == 20.0, "Predator Focus costs 25 Magicules and arms the next analysis for 20s")
    melee.cooldown_left = 0.0
    _check(not melee.attack_skill(Vector2.RIGHT, &"predator_focus") and pool.current == 75.0, "Focus cannot stack while armed")
    var far_corpse = GNASHER.instantiate()
    far_corpse.entity_id = "focus_target"
    far_corpse.position = Vector2(700, 600)
    world.add_child(far_corpse)
    far_corpse.set_physics_process(false)
    far_corpse.get_node("Health").take_damage(999)
    actor.position = far_corpse.position + Vector2(-60, 0)
    await _frames()
    _check(absorption.attempt_absorb() and absorption.focus_left == 0.0 and is_equal_approx(absorption.time_left, 0.3), "Focused analysis reaches 60px and starts a 0.3s channel; focus is consumed")
    absorption._process(0.35)
    _check(not absorption.active and not is_instance_valid(far_corpse) or far_corpse.is_queued_for_deletion(), "Focused analysis completes")
    var second = GNASHER.instantiate()
    second.entity_id = "unfocused_target"
    second.position = Vector2(700, 560)
    world.add_child(second)
    second.set_physics_process(false)
    second.get_node("Health").take_damage(999)
    actor.position = second.position + Vector2(-60, 0)
    await _frames()
    _check(not absorption.attempt_absorb(), "Without focus the same distance is out of reach")
    melee.cooldown_left = 0.0
    melee.attack_skill(Vector2.RIGHT, &"predator_focus")
    _check(absorption.attempt_absorb() and absorption.focus_left == 0.0, "Second focused analysis starts")
    actor.position = second.position + Vector2(-120, 0)
    absorption._process(0.1)
    _check(not absorption.active and absorption.focus_left == 0.0 and second.is_in_group("absorbable_creatures"), "Interrupting a focused analysis never refunds the focus")
    melee.cooldown_left = 0.0
    melee.attack_skill(Vector2.RIGHT, &"predator_focus")
    absorption._process(21.0)
    _check(absorption.focus_left == 0.0, "Unused focus expires after 20s")
    pool._current = 100.0
    melee.cooldown_left = 0.0
    melee.attack_skill(Vector2.RIGHT, &"predator_focus")
    # Save format v10.
    var data: Dictionary = CODEC.capture_entities(world)
    data.merge({"version": STORE.VERSION, "world_id": "trial_world", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    data.erase("trial")
    _check(STORE.VERSION >= 10 and STORE.validate(data) and data.players.host.slots.size() == 4 and data.players.host.analysis.focus == 20.0, "v10 save keeps four slots and the armed focus")
    var restored = _guest("restored", Vector2(600, 600), false)
    CODEC.apply_player(restored, JSON.parse_string(JSON.stringify(data.players.host)), world, false)
    _check(restored.get_node("Absorption").focus_left == 20.0 and restored.get_node("SkillBook").skill_at_slot(3).id == &"predator_focus", "Reload restores focus timer and slot 4")
    var bad := data.duplicate(true)
    bad.players.host.analysis.focus = 30
    _check(not STORE.validate(bad), "Out-of-range focus rejected")
    bad = data.duplicate(true)
    bad.players.host.slots = ["rending_bite", "thorn_lash", "piercing_fang"]
    _check(not STORE.validate(bad), "v10 needs four slots")
    bad = data.duplicate(true)
    bad.players.host.skill_ids.erase("piercing_fang")
    bad.players.host.slots = ["rending_bite", "thorn_lash", "", "predator_focus"]
    _check(not STORE.validate(bad), "Unique without its Extra rejected")
    bad = data.duplicate(true)
    bad.players.host.skill_evidence.trials = []
    _check(not STORE.validate(bad), "Unique without trial evidence rejected")
    var legacy := data.duplicate(true)
    legacy.version = 9
    legacy.players.host.slots = ["rending_bite", "thorn_lash", "piercing_fang"]
    legacy.players.host.analysis.erase("focus")
    legacy.players.host.skill_ids.erase("predator_focus")
    legacy.players.host.skill_evidence.trials = []
    var migrated: Dictionary = STORE.migrate(legacy)
    _check(STORE.validate(migrated) and migrated.players.host.slots.size() == 4 and migrated.players.host.analysis.focus == 0.0, "v9 characters gain an empty fourth slot and no focus")
    var overview: Array = book.describe()
    _check(overview.any(func(entry): return entry.id == "predator_focus" and entry.known) and not overview.any(func(entry): return entry.tier == "Ultimate"), "Overview lists the known Unique; no Ultimate is obtainable")
    print("Trial and Unique checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
