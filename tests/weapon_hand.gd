extends SceneTree
## SVE feedback 2026-10-22: the weapon is held in the hand (no glow around it), each type moves
## its own way when striking, two gauntlets for fist weapons, behind the body when facing away,
## hidden while defeated; Epic and better twinkle in the equipment window.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const SPARKLE := preload("res://scripts/ui/rarity_sparkle.gd")
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
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-hand-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24971, dir.path_join("hand.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me: CharacterBody2D = world.get_local_player()
    var dev := preload("res://scripts/dev/dev_tools.gd")
    dev.free_gear = true
    var rng := RandomNumberGenerator.new()
    var kinds := {}
    for base in ["sword_118", "dagger_124", "spear_096", "staff_053", "fist_021", "bow_102", "scythe_078"]:
        var item: Dictionary = GEAR.roll(base, 5, rng)
        me.add_item(item)
        me.progression["equipment"]["weapon"] = item.id
        await _frames(2)
        kinds[me.weapon_hand._kind] = me.weapon_hand.visible and me._weapon_icon != null
    _check(kinds.size() == 7 and kinds.values().all(func(shown): return shown), "Every weapon type is held in the hand: %s" % str(kinds))
    _check(me._weapon_fx != null and me._weapon_fx.emitting, "A Mythic weapon still sparks")
    var hand: Node2D = me.weapon_hand
    var melee: Node = me.get_node("MeleeAttack")
    melee.flash_left = 0.0
    await _frames(2)
    melee.direction = Vector2.RIGHT
    melee.flash_left = 0.12
    await _frames(2)
    _check(hand._t < 1.0 and hand._aim == Vector2.RIGHT, "A strike starts the weapon's motion toward the aim")
    await create_timer(0.6).timeout
    _check(hand._t == 1.0, "…and it comes back to rest")
    me.facing = Vector2.UP
    await _frames(2)
    _check(hand.z_index < 0, "Facing away, the weapon is behind the body")
    me.facing = Vector2.RIGHT
    await _frames(2)
    _check(hand.z_index > 0, "Otherwise in front of it")
    me.get_node("Health").current = 0
    await _frames(2)
    _check(not hand.visible, "Hidden while defeated")
    me.get_node("Health").current = me.get_node("Health").maximum
    me.progression["equipment"]["weapon"] = ""
    await _frames(2)
    _check(not hand.visible and me._weapon_fx == null, "No weapon, nothing in hand")
    _check(SPARKLE.animates(3) and SPARKLE.animates(5) and not SPARKLE.animates(2), "Epic and better twinkle in the equipment window")
    dev.free_gear = false
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Weapon in hand checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
