extends SceneTree
const FORMS := preload("res://scripts/forms/form_catalogue.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
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
func _document(world: Node2D, actor: Node2D) -> Dictionary:
    var data: Dictionary = CODEC.capture_entities(world)
    data.merge({"version": STORE.VERSION, "world_id": "mimic_world", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    return data
func _run() -> void:
    var world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var session = root.get_node("GameSession")
    var actor = world.get_local_player()
    var pool = actor.get_node("Magicules")
    var health = actor.get_node("Health")
    var book = actor.get_node("SkillBook")
    var shape: CircleShape2D = actor.get_node("CollisionShape2D").shape
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    actor.position = Vector2(560, 600)
    await _frames()
    _check(FORMS.BASE == "slime" and FORMS.FORMS.gnasher.analysis == "forest_gnasher", "Gnasher Form unlocks from Forest Gnasher analysis")
    _check(actor.form == "slime" and shape.radius == 6.0 and InputMap.has_action("transform"), "Characters start as slimes with a T binding")
    _check(actor.next_form() == "", "No mimic form is offered before any analysis")
    _check(not actor.try_transform("gnasher") and pool.current == 100.0, "Unanalyzed form fails without cost")
    _check(not actor.try_transform("dragon") and not actor.try_transform("slime"), "Unknown and current forms are rejected")
    book.record_analysis(&"forest_gnasher")
    _check(actor.next_form() == "gnasher", "Analysis unlocks Gnasher Form for T")
    health.current = 60
    var bag_before: int = actor.get_node("Inventory").total_units()
    _check(actor.try_transform("gnasher"), "Transformation succeeds once unlocked")
    _check(actor.form == "gnasher" and shape.radius == 8.0 and pool.current == 80.0, "Gnasher Form costs 20 Magicules and enlarges the body")
    _check(health.current == 60 and actor.get_node("Inventory").total_units() == bag_before and actor.character_id == "host", "Transformation never refills HP or changes inventory/identity")
    _check(is_equal_approx(actor.current_speed(), actor.move_speed * 1.3) and actor.form_strike_bonus() == 4, "Gnasher Form moves 30% faster and strikes 4 harder")
    _check(not actor.try_transform("slime") and actor.form == "gnasher", "Change cooldown blocks an immediate revert")
    # Basic strikes gain the bonus; skills keep their own damage.
    var dummy = GNASHER.instantiate()
    dummy.entity_id = "dummy"
    dummy.position = actor.position + Vector2(20, 0)
    world.add_child(dummy)
    dummy.set_physics_process(false)
    await _frames()
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    actor.get_node("MeleeAttack").attack(Vector2.RIGHT)
    _check(dummy.get_node("Health").current == 16, "Gnasher Form basic strike deals 14 damage")
    dummy.queue_free()
    # Waiting out the cooldown: revert is free and always fits.
    actor._process(FORMS.CHANGE_COOLDOWN)
    var before: float = pool.current
    _check(actor.try_transform("slime") and actor.form == "slime" and shape.radius == 6.0 and pool.current == before, "Revert to slime is free after the cooldown")
    actor._process(FORMS.CHANGE_COOLDOWN)
    # A body pressed against terrain has no room for the larger form.
    world._add_obstacle(Rect2(actor.position.x + 7, actor.position.y - 20, 6, 40))
    await _frames()
    before = pool.current
    _check(not actor.try_transform("gnasher") and actor.form == "slime" and pool.current == before, "Blocked transformation fails without charging")
    actor.position = Vector2(500, 600)
    await _frames()
    actor.begin_exhaustion(8)
    _check(not actor.try_transform("gnasher") and actor.is_exhausted() and actor.exhaustion_left == 8.0, "Sleeping characters cannot transform; exhaustion is untouched")
    actor.exhaustion_active = false
    actor.exhaustion_left = 0.0
    session.replica_world = true
    _check(not actor.try_transform("gnasher"), "Client replicas cannot transform")
    session.replica_world = false
    _check(not session.apply_action(actor, "transform", {"form": "gnasher", "cost": 0}), "Forged transform payload rejected")
    actor.input_blocked = true
    _check(not session.apply_action(actor, "transform", {"form": "gnasher"}), "Open menus block transformation")
    actor.input_blocked = false
    _check(session.apply_action(actor, "transform", {"form": "gnasher"}) and actor.form == "gnasher", "Host intent transforms the owner")
    _check(not session.apply_action(actor, "transform", {"form": "gnasher"}), "Repeated requests charge once")
    # Persistence.
    var data := _document(world, actor)
    _check(STORE.VERSION >= 9 and STORE.validate(data) and data.players.host.form.id == "gnasher" and data.players.host.form.cooldown > 0, "v9 save stores form and cooldown")
    var restored = load("res://scenes/player/player.tscn").instantiate()
    restored.local_controlled = false
    world.add_child(restored)
    await _frames(1)
    CODEC.apply_player(restored, JSON.parse_string(JSON.stringify(data.players.host)), world, false)
    _check(restored.form == "gnasher" and restored.get_node("CollisionShape2D").shape.radius == 8.0 and restored.form_cooldown > 0, "Reload restores form, body size and cooldown")
    _check(actor.get_node("CollisionShape2D").shape.radius == 8.0, "Each character has its own collision shape")
    var bad := data.duplicate(true)
    bad.players.host.form.id = "dragon"
    _check(not STORE.validate(bad), "Unknown saved form rejected")
    bad = data.duplicate(true)
    bad.players.host.skill_evidence.analyzed = []
    bad.players.host.skill_ids = []
    bad.players.host.slots = ["", "", ""]
    _check(not STORE.validate(bad), "Saved form without its analysis rejected")
    bad = data.duplicate(true)
    bad.players.host.form.cooldown = 99
    _check(not STORE.validate(bad), "Out-of-range form cooldown rejected")
    bad = data.duplicate(true)
    bad.players.host.health.current = 0
    _check(not STORE.validate(bad), "Defeated characters cannot be saved in a mimic form")
    var legacy := data.duplicate(true)
    legacy.version = 8
    legacy.players.host.erase("form")
    var migrated: Dictionary = STORE.migrate(legacy)
    _check(STORE.validate(migrated) and migrated.players.host.form == {"id": "slime", "cooldown": 0.0}, "v8 characters migrate as slimes")
    # Defeat and respawn always return to the base form.
    health.take_damage(999)
    await _frames()
    _check(actor.form == "slime" and shape.radius == 6.0 and STORE.validate(_document(world, actor)), "Defeat reverts to the slime and the save stays valid")
    _check(session.apply_action(actor, "respawn") and actor.form == "slime" and health.current == health.maximum, "Respawn returns as a slime")
    print("Mimic form checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
