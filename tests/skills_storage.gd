extends SceneTree
## Complete acquisition/use loop plus bag UI and pause/resource transactions.

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)

func _frames(count: int) -> void:
    for _i in range(count):
        await physics_frame
        await process_frame

func _input(action: StringName) -> void:
    var event := InputEventAction.new()
    event.action = action
    event.pressed = true
    Input.parse_input_event(event)
    event = InputEventAction.new()
    event.action = action
    event.pressed = false
    Input.parse_input_event(event)

func _run() -> void:
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var player = world.get_node("Player")
    var enemy = world.get_node("ForestGnasher")
    var second = world.get_node("SecondGnasher")
    enemy.set_physics_process(false)
    second.set_physics_process(false)
    var pool = player.get_node("Magicules")
    pool.regeneration_per_second = 0.0
    var book = player.get_node("SkillBook")
    var bag = player.get_node("Inventory")
    var melee = player.get_node("MeleeAttack")
    var absorption = player.get_node("Absorption")
    var hud = world.get_node("HUD")
    await _frames(3)
    for action in ["inventory", "skill_1", "skill_2", "skill_3"]:
        _check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "Missing UI/skill binding: " + action)
    _check(book.skill_at_slot(0) == null and book.skill_at_slot(-1) == null and book.skill_at_slot(3) == null, "Unassigned/out-of-range slots must not expose skills")
    _check(not melee.attack_skill(Vector2.RIGHT, &"rending_bite") and pool.current == 100.0, "Unlearned skills must not execute or spend resources")
    _check(hud._slots[0].disabled and bag.total_units() == 0, "Hotbar and storage must start empty")

    player.position = Vector2(480, 340)
    player.facing = Vector2.RIGHT
    enemy.position = Vector2(510, 340)
    await _frames(3)
    for _i in range(3):
        _input(&"attack")
        await _frames(26)
    _check(enemy.get_node("Health").current == 0, "Real attack inputs must defeat the first enemy")
    _input(&"absorb")
    await _frames(75)
    _check(not is_instance_valid(enemy) and book.knows(&"rending_bite"), "Real absorb input must complete analysis and acquisition")
    _check(bag.total_units() == 1 and bag.entries()[0].id == &"gnasher_essence", "Completed analysis must retain one essence material")
    _check(book.skill_at_slot(0).id == &"rending_bite" and not hud._slots[0].disabled, "Acquired skill must auto-equip to the first hotbar slot")
    _check(hud._slots[0].text.contains("Rending Bite") and hud._log.text.contains("acquired"), "HUD must show the learned skill and acquisition event")

    second.position = Vector2(504, 340)
    await _frames(3)
    var before: float = pool.current
    _input(&"skill_1")
    await _frames(2)
    _check(second.get_node("Health").current == 10, "Skill input must deal 20 damage to the second enemy")
    _check(is_equal_approx(pool.current, before - 12.0), "Acquired skill must charge its 12-Magicule cost")
    _check(melee.cooldown_left > 0.7 and hud._slots[0].disabled, "Skill must start its 0.8-second cooldown and disable its hotbar button")
    _input(&"attack")
    _input(&"skill_1")
    await _frames(1)
    _check(is_equal_approx(pool.current, before - 12.0) and second.get_node("Health").current == 10, "Shared attack cooldown must prevent basic/skill spam without extra spending")
    _input(&"skill_2")
    await _frames(1)
    _check(is_equal_approx(pool.current, before - 12.0), "An empty slot must not charge resources")

    second.set_physics_process(true)
    pool.regeneration_per_second = 6.0
    _input(&"inventory")
    # Injected input is dispatched by the next frame; snapshot after it is handled.
    await _frames(2)
    var cooldown_before: float = melee.cooldown_left
    var position_before: Vector2 = second.position
    var reserve_before: float = pool.current
    await _frames(120)
    _check(paused and hud.get_node("InventoryPanel").visible, "I must open a paused inventory overlay")
    _check(second.position.is_equal_approx(position_before) and is_equal_approx(melee.cooldown_left, cooldown_before) and is_equal_approx(pool.current, reserve_before), "Inventory pause must freeze enemy AI, attack cooldown, and regeneration")
    _check(hud._items.item_count == 1 and hud._details.text.contains("Gnasher Essence"), "Inventory must show a selectable stack and real material details")
    _check(hud._close.has_focus(), "Opening inventory must focus its close control")
    _input(&"ui_cancel")
    await _frames(2)
    _check(not paused and not hud.get_node("InventoryPanel").visible, "Escape must close inventory and resume gameplay")
    second.set_physics_process(false)
    pool.regeneration_per_second = 0.0
    await _frames(50)
    _check(not hud._slots[0].disabled and melee.cooldown_left == 0.0, "Skill must become available after unpaused cooldown recovery")

    var copied_entries: Array = bag.entries()
    copied_entries[0].count = 999
    _check(bag.total_units() == 1, "UI inventory snapshots must not mutate the underlying stack")
    _check(not bag.discard(&"missing") and not bag.discard(&"gnasher_essence", -1) and not bag.discard(&"gnasher_essence", 2), "Invalid discards must preserve contents")
    _input(&"inventory")
    await _frames(2)
    hud._discard.pressed.emit()
    _check(bag.total_units() == 0 and hud._items.item_count == 0 and hud._discard.disabled, "Discard UI must remove one material and refresh selection")
    _check(book.knows(&"rending_bite"), "Discarding material must not erase learned knowledge")
    hud.close_inventory()

    var specimen: Resource = load("res://data/specimens/forest_gnasher.tres")
    for _i in range(bag.capacity):
        bag.add_specimen(specimen)
    _check(bag.total_units() == 20 and not bag.can_store() and not bag.add_specimen(specimen), "Storage capacity must be enforced")
    second.position = player.position + Vector2(24, 0)
    await _frames(3)
    melee.attack(Vector2.RIGHT)
    await _frames(3)
    reserve_before = pool.current
    _check(not absorption.attempt_absorb() and pool.current == reserve_before and is_instance_valid(second), "Full storage must block absorption before cost or consumption")
    bag.discard(&"gnasher_essence")
    _check(absorption.attempt_absorb(), "Discarding one material must free room for analysis")
    bag.add_specimen(specimen)
    await _frames(75)
    _check(not absorption.active and is_instance_valid(second) and bag.total_units() == 20, "Capacity filled during analysis must cancel without consuming the corpse or overflowing storage")
    bag.discard(&"gnasher_essence")
    absorption.attempt_absorb()
    await _frames(10)
    var time_before: float = absorption.time_left
    hud.open_inventory()
    await _frames(90)
    _check(absorption.active and is_equal_approx(absorption.time_left, time_before), "Inventory must pause a pending analysis channel")
    hud.close_inventory()
    await _frames(75)
    _check(not is_instance_valid(second) and bag.total_units() == 20 and book.all_skills().size() == 1, "Resuming must complete analysis, stack one essence, and preserve unique skill knowledge")

    pool.try_spend(pool.current)
    await _frames(2)
    _check(hud._slots[0].disabled and not melee.attack_skill(Vector2.RIGHT, &"rending_bite"), "Insufficient reserves must disable the hotbar and reject skill use")
    _input(&"restart")
    await _frames(3)
    _check(current_scene.get_node("Player/Inventory").total_units() == 0 and current_scene.get_node("Player/SkillBook").all_skills().is_empty(), "Restart must reset bag and learned skills until save/load exists")
    print("Skills/storage checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
