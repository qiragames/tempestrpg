extends SceneTree
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("_run")
func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func _run() -> void:
    var world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var session = root.get_node("GameSession")
    var actor = world.get_local_player()
    var ally = world.get_node("GoblinAlly")
    ally.set_physics_process(false)
    actor.position = Vector2(190, 360)
    var pool = actor.get_node("Magicules")
    pool.regeneration_per_second = 0
    await physics_frame
    await process_frame
    _check(not ally.try_name(actor, "Aster"), "Unclaimed allies cannot be named")
    world.get_node("ForestGnasher/Health").take_damage(999)
    _check(ally.try_recruit(actor), "Recruitment prerequisite")
    _check(not ally.try_name(actor, "<bad>") and pool.current == 100, "Invalid names must not spend resources")
    _check(not session.apply_action(actor, "name_ally", {"id": ally.entity_id, "name": 42}), "Host rejects malformed payloads")
    var guest = load("res://scenes/player/player.tscn").instantiate()
    guest.character_id = "guest"
    guest.local_controlled = false
    guest.position = actor.position
    world.add_child(guest)
    _check(not ally.try_name(guest, "Aster"), "Other characters cannot name owned allies")
    actor.position = Vector2(100, 360)
    _check(not ally.try_name(actor, "Aster"), "Naming requires proximity")
    actor.position = Vector2(190, 360)
    # 24a: naming the level-1 goblin costs 37.5% of the maximum (38 of 100 Magicules).
    pool.try_spend(63)
    _check(not ally.try_name(actor, "Aster") and ally.display_name.is_empty(), "Insufficient reserves cannot evolve the ally")
    pool.restore(1)
    var dialog = world.get_node("HUD")._ally_dialog
    dialog.open_nearest()
    dialog._name_field.text = "Aster"
    dialog._refresh()
    _check(paused and dialog._details.text.contains("38 Magicules") and not dialog._recruit.disabled, "UI previews cost and requires valid name confirmation")
    dialog._confirm()
    _check(ally.display_name == "Aster" and ally.race == "Hobgoblin" and ally.maximum_hp == 60 and ally.power == 8 and ally.follow_speed == 65, "Confirmed naming changes name, race and stats")
    _check(pool.current == 0 and actor.is_exhausted() and actor.exhaustion_left == 8, "Naming spends exactly 38 (level-1 goblin) and starts saved recovery")
    dialog.close_dialog()
    _check(not ally.try_name(actor, "Other") and pool.current == 0, "Repeated naming cannot charge again")
    _check(not guest.is_exhausted(), "Exhaustion belongs to the namer only")
    _check(not actor.get_node("MeleeAttack").attack(Vector2.RIGHT), "Sleeping characters cannot attack")
    _check(not actor.get_node("Absorption").attempt_absorb(), "Sleeping characters cannot absorb")
    Input.action_press("move_right")
    var before: Vector2 = actor.position
    await physics_frame
    await process_frame
    Input.action_release("move_right")
    _check(actor.position.is_equal_approx(before), "Sleep blocks movement")
    actor._process(9)
    _check(actor.is_exhausted() and actor.exhaustion_left == 0, "Timer alone cannot bypass the reserve threshold")
    var data: Dictionary = CODEC.capture_entities(world)
    data.merge({"version": STORE.VERSION, "world_id": "naming_world", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    _check(STORE.validate(data), "Named ally and exhaustion validate together")
    actor.exhaustion_active = false
    pool.restore(100)
    CODEC.apply_player(actor, data.players.host, world, false)
    CODEC.apply_entities(world, data, false)
    _check(actor.is_exhausted() and pool.current == 0 and ally.display_name == "Aster", "Reload retains costs, evolution and incomplete recovery")
    var bad := data.duplicate(true)
    bad.allies[0].race = "Goblin"
    _check(not STORE.validate(bad), "Inconsistent evolved stats must be rejected")
    bad = data.duplicate(true)
    bad.players.host.exhaustion.remaining = -1
    _check(not STORE.validate(bad), "Negative saved timers must be rejected")
    bad = data.duplicate(true)
    var duplicate: Dictionary = bad.allies[0].duplicate(true)
    duplicate.id = "another_ally"
    duplicate.name = "ASTER"
    bad.allies.append(duplicate)
    _check(not STORE.validate(bad), "Saved ally names are unique regardless of case")
    var legacy := data.duplicate(true)
    legacy.version = 2
    legacy.players.host.erase("exhaustion")
    var migrated: Dictionary = STORE.migrate(legacy)
    _check(STORE.validate(migrated) and not migrated.players.host.exhaustion.active, "Version-2 saves migrate with awake defaults")
    actor.get_node("Health").immunity_left = 0
    actor.get_node("Health").take_damage(999)
    actor.death_left = actor.RESPAWN_DELAY
    _check(not session.apply_action(actor, "respawn", {}), "Respawning waits for the 5 s countdown (24a)")
    actor.death_left = 0.0
    _check(session.apply_action(actor, "respawn", {}) and actor.is_exhausted() and pool.current == pool.maximum, "Respawn returns with full Magicules but keeps the recovery (sleep) timer")
    pool._current = 0.0
    pool.restore(24)
    actor._process(1)
    _check(actor.is_exhausted(), "Recovery still requires a quarter reserve")
    pool.restore(1)
    actor._process(0.1)
    _check(not actor.is_exhausted(), "Recovered reserves and elapsed timer restore control")
    actor.begin_exhaustion(8)
    actor._process(7)
    _check(actor.is_exhausted(), "Available reserves cannot skip the minimum recovery time")
    actor._process(1)
    _check(not actor.is_exhausted(), "Recovery ends after both prerequisites")
    session.replica_world = true
    var saved_owner: String = ally.owner_id
    ally.owner_id = "guest"
    ally.display_name = ""
    _check(not ally.try_name(guest, "Forged"), "Client replicas cannot authoritatively name allies")
    ally.owner_id = saved_owner
    session.replica_world = false
    guest.queue_free()
    print("Naming checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
