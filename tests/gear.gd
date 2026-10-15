extends SceneTree
## Gear foundation (step 17e): catalogue, rolled items, validation, equip/unequip/swap with stat
## effects, passives (swift, wellspring, keen, lifesteal, thorns), defense, actives on G, race
## re-application, host intents, the equipment window, saves, forged items and v17→v18 migration.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
var checks := 0
var failures := 0
var world: Node2D
var rng := RandomNumberGenerator.new()
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
## A fixed item for exact assertions (validated like a rolled one).
func _item(base: String, rarity: int, stats: Dictionary, passives: Array = [], active: String = "") -> Dictionary:
    return {"id": "item_" + Crypto.new().generate_random_bytes(8).hex_encode(), "base": base, "rarity": rarity, "stats": stats, "passives": passives, "active": active}
func _creature(id: String, at: Vector2) -> Node2D:
    var enemy = GNASHER.instantiate()
    enemy.entity_id = id
    enemy.position = at
    world.add_child(enemy)
    enemy.set_physics_process(false)
    return enemy

func _run() -> void:
    rng.seed = 1717
    # --- Catalogue and rolls
    var kinds := {}
    for base in GEAR.BASES:
        kinds[GEAR.BASES[base].slot] = true
    _check(GEAR.SLOTS.size() == 7 and kinds.keys().size() == 6 and GEAR.RARITIES.size() == 6 and GEAR.BASES.size() > 700, "Seven slots (weapon, head, body, hands, feet, two accessories), six rarities (Mythic), hundreds of bases for every slot kind")
    var all_valid := true
    var shapes := true
    for base in GEAR.BASES:
        for rarity in range(int(GEAR.BASES[base].get("min_rarity", 0)), GEAR.RARITIES.size()):
            for attempt in range(20 if GEAR.CLASSIC.has(base) else 2):
                var item: Dictionary = GEAR.roll(base, rarity, rng)
                all_valid = all_valid and GEAR.valid_item(item)
                shapes = shapes and item.passives.size() == GEAR.PASSIVE_COUNT[rarity] and (item.active.is_empty() == (rarity < 3))
    _check(all_valid, "Rolled items across every base and rarity validate")
    _check(shapes, "Passives from Rare (two on Legendary); one active only on Epic and Legendary")
    _check(GEAR.stat_range("padded_vest", "hp", 4) == [13.0, 26.0] and GEAR.stat_range("scale_mail", "speed", 4) == [-6.0, -3.0], "Higher rarities scale bonuses, never penalties")
    var forged := [
        _item("padded_vest", 0, {"hp": 30}),
        _item("padded_vest", 0, {"hp": 8, "strike": 1}),
        _item("padded_vest", 2, {"hp": 10}),
        _item("padded_vest", 2, {"hp": 10}, ["keen", "keen"]),
        _item("padded_vest", 1, {"hp": 10}, [], "barrier"),
        _item("padded_vest", 3, {"hp": 10}, ["keen"], "teleport"),
        _item("dragon_crown", 0, {"hp": 5}),
        _item("spirit_amulet", 0, {"regen": 0.33}),
    ]
    _check(forged.all(func(item): return not GEAR.valid_item(item)), "Rejected: stat above range, extra stat, missing passive, duplicate passive, active below Epic, unknown active, unknown base, off-step value")
    # --- Equip / unequip with stat effects
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    actor.position = Vector2(100, 600)
    var health = actor.get_node("Health")
    var pool = actor.get_node("Magicules")
    var vest := _item("padded_vest", 0, {"hp": 10})
    var helm := _item("iron_helm", 2, {"hp": 12, "defense": 2}, ["thorns"])
    var boots := _item("travel_boots", 2, {"speed": 6}, ["swift"])
    var ring := _item("copper_ring", 3, {"magicules": 12}, ["wellspring"], "surge")
    var amulet := _item("spirit_amulet", 4, {"regen": 0.8}, ["keen", "lifesteal"], "barrier")
    var gloves := _item("leather_gloves", 1, {"strike": 2})
    for item in [vest, helm, boots, ring, amulet, gloves]:
        actor.add_item(item)
    _check(actor.gear.items.size() == 6 and not actor.add_item(vest), "Items are added once (stable IDs)")
    health.current = 20
    pool._current = 10.0
    for _cycle in range(3):
        actor.equip(vest.id, "body")
        actor.unequip("body")
        actor.equip(ring.id, "accessory_1")
        actor.unequip("accessory_1")
    _check(health.current == 20, "Repeated gear equip/unequip does not heal HP")
    _check(is_equal_approx(pool.current, 10.0), "Repeated gear equip/unequip does not restore Magicules")
    health.current = health.maximum
    pool._current = pool.maximum
    _check(not actor.equip(vest.id, "head") and not actor.equip(ring.id, "body") and not actor.equip("item_missing", "body"), "Items only fit their slot; unknown items cannot be equipped")
    var hp: int = health.maximum
    var mp: float = pool.maximum
    var regen: float = pool.regeneration_per_second
    _check(actor.equip(vest.id, "body") and health.maximum == hp + 10 and health.current == hp, "Equipping +10 HP raises capacity without refilling current HP")
    _check(actor.equip(helm.id, "head") and health.maximum == hp + 22 and health.armor == 2, "A helm adds HP and defense")
    _check(actor.equip(ring.id, "accessory_1") and actor.equip(amulet.id, "accessory_2") and pool.maximum == mp + 12 and is_equal_approx(pool.regeneration_per_second, regen + 0.5 + 0.8), "Two accessories: Magicules, regeneration and the Wellspring passive")
    var speed: float = actor.current_speed()
    _check(actor.equip(boots.id, "feet") and is_equal_approx(actor.current_speed(), speed + 11.0), "Boots and the Swift passive: +11 move speed")
    _check(actor.equip(ring.id, "accessory_2") and actor.progression.equipment.get("accessory_2") == ring.id and not actor.progression.equipment.has("accessory_1") and is_equal_approx(pool.regeneration_per_second, regen + 0.5), "Moving an item between accessory slots swaps the other back to the bag")
    actor.equip(amulet.id, "accessory_1")
    _check(actor.unequip("head") and health.maximum == hp + 10 and health.armor == 0 and health.current <= health.maximum, "Unequipping removes the bonus again")
    actor.equip(helm.id, "head")
    # --- Combat effects
    health.immunity_left = 0.0
    var before: int = health.current
    var biter := _creature("g_biter", actor.position + Vector2(40, 0))
    health.take_damage(12, biter)
    _check(health.current == before - 10, "Defense 2: a 12-damage bite costs 10 HP")
    _check(biter.get_node("Health").current == biter.get_node("Health").maximum - 3, "Thorns: the attacker takes 3 damage back")
    health.immunity_left = 0.0
    health.take_damage(2, biter)
    _check(health.current == before - 11, "A hit always deals at least 1 damage")
    actor.equip(gloves.id, "hands")
    actor.get_node("SkillBook").record_analysis(&"forest_gnasher")
    actor.activate_skill("rending_bite")
    var target := _creature("g_target", actor.position + Vector2(0, 18))
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    pool._current = pool.maximum
    var hurt: int = health.current
    actor.get_node("MeleeAttack").attack(Vector2.DOWN)
    _check(target.get_node("Health").current == 30 - 14 and health.current == hurt + 1, "Gloves +2 strike (Slime 12 + 2 = 14 damage) and Lifesteal heals 1 HP per hit")
    var second := _creature("g_second", actor.position + Vector2(0, 18))
    second.get_node("Health").maximum = 200
    second.get_node("Health").current = 200
    target.queue_free()
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    actor.get_node("MeleeAttack").attack_skill(Vector2.DOWN, &"rending_bite")
    _check(second.get_node("Health").current == 200 - 51, "Keen: Rending Bite deals 51 instead of 46")
    second.queue_free()
    # --- Actives on G
    pool._current = 10.0
    health.immunity_left = 0.0
    _check(actor.use_gear_active() and actor.gear.cooldowns.keys() == [amulet.id] and health.immunity_left >= 2.0 and pool.current == 10.0, "G uses the first ready active in slot order: the amulet's Barrier (2 s invulnerability)")
    _check(actor.use_gear_active() and actor.gear.cooldowns.has(ring.id) and pool.current == 40.0, "The next G uses the ring's Mana Surge (+30 Magicules)")
    _check(not actor.use_gear_active(), "With every active on cooldown nothing happens")
    actor._process(GEAR.ACTIVES.barrier.cooldown + 0.1)
    _check(not actor.gear.cooldowns.has(amulet.id) and actor.gear.cooldowns.has(ring.id), "Cooldowns run out separately")
    # --- Race and tree recalculation keep gear bonuses
    var with_gear: int = health.maximum
    actor.choose_race("Slime")
    _check(health.maximum == with_gear, "Re-applying race stats keeps equipped gear bonuses")
    # --- Host intents and client guard
    var session: Node = root.get_node("GameSession")
    var rejected: int = session.rejected_requests
    _check(session.apply_action(actor, "gear", {"operation": "unequip", "slot": "hands"}) and not actor.progression.equipment.has("hands"), "The host applies an unequip intent")
    _check(session.apply_action(actor, "gear", {"operation": "equip", "id": gloves.id, "slot": "hands"}) and actor.progression.equipment.hands == gloves.id, "The host applies an equip intent")
    session.apply_action(actor, "gear", {"operation": "equip", "id": gloves.id})
    session.apply_action(actor, "gear", {"operation": "craft", "id": gloves.id, "slot": "hands"})
    session.apply_action(actor, "gear", {"operation": "use", "extra": 1})
    _check(session.rejected_requests == rejected + 3, "Malformed gear intents are rejected")
    session.replica_world = true
    _check(not actor.unequip("hands") and not actor.use_gear_active() and not actor.add_item(GEAR.roll("cloth_hood", 0, rng)), "Clients cannot change gear locally")
    session.replica_world = false
    # --- The equipment window
    var hud = world.get_node("HUD")
    hud.open_inventory()
    await _frames(1)
    var equipment_button: Button = null
    for child in hud._modal.get_children():
        if child is Button and child.text == "Equipment":
            equipment_button = child
    equipment_button.pressed.emit()
    await _frames(1)
    var panel = hud.gear_panel
    _check(panel.visible and not hud._modal.visible and paused, "The bag's Equipment button opens the equipment window")
    var worn_count: int = actor.progression.equipment.size()
    var in_grid: int = panel._grid.filter(func(cell): return not cell.item_id.is_empty()).size()
    _check(panel._slot_cells.head.item_id == helm.id and in_grid + worn_count == 6, "The helm is in the head slot; the grid shows every other owned item")
    panel.dropped({"item": helm.id, "from": "head"}, "")
    await _frames(1)
    _check(not actor.progression.equipment.has("head"), "Dragging a worn item to the grid takes it off")
    panel._selected = helm.id
    panel.refresh()
    panel._equip.pressed.emit()
    await _frames(1)
    _check(actor.progression.equipment.get("head") == helm.id and panel._details.text.contains("Passive: Creatures that hit you take 3 damage"), "Equip puts the selected item on; details list stats and passives")
    panel.close()
    await _frames(1)
    _check(not panel.visible and not paused, "Closing resumes")
    # --- Saves
    var dir := OS.get_temp_dir().path_join("tempestrpg-gear-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var path := dir.path_join("gear.json")
    var expected_max: int = health.maximum
    var expected_equipment: Dictionary = actor.progression.equipment.duplicate()
    _check(session.start_host(24680, path, false, {"name": "Gear", "seed": 0, "created": 1, "last_played": 1}) == OK and session.save_world() == OK, "World with gear saves")
    var saved: Dictionary = STORE.load_world(path)
    _check(saved.ok and saved.data.version == STORE.VERSION and saved.data.players.host.gear.items.size() == 6 and saved.data.players.host.progression.equipment == expected_equipment, "Items, equipment and cooldowns are saved")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24680, path, false) == OK, "Gear world reloads")
    var reloaded = world.get_local_player()
    _check(reloaded.get_node("Health").maximum == expected_max and reloaded.get_node("Health").armor == 2 and reloaded.gear_passive("thorns") and reloaded.gear.cooldowns.has(ring.id), "Reload restores stats, defense, passives and the running cooldown")
    session.stop_session(false)
    var data: Dictionary = saved.data
    var bad := []
    var doc: Dictionary
    doc = data.duplicate(true); doc.players.host.gear.items[0].stats.hp = 999; bad.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.equipment["head"] = gloves.id; bad.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.equipment["feet"] = "item_nothere"; bad.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.equipment["accessory_1"] = ring.id; doc.players.host.progression.equipment["accessory_2"] = ring.id; bad.append(doc)
    doc = data.duplicate(true); doc.players.host.gear.items.append(doc.players.host.gear.items[0].duplicate(true)); bad.append(doc)
    doc = data.duplicate(true); doc.players.host.gear.cooldowns[vest.id] = 5.0; bad.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.equipment["weapon"] = vest.id; bad.append(doc)
    doc = data.duplicate(true); doc.players.host.erase("gear"); bad.append(doc)
    var rejected_all := true
    for index in range(bad.size()):
        if STORE.validate(bad[index]):
            rejected_all = false
            push_error("Forged gear case %d was accepted" % index)
    _check(rejected_all, "Rejected: stat out of range, wrong slot, unowned item, item worn twice, duplicate item ID, cooldown without active, unknown slot, missing gear")
    var legacy: Dictionary = data.duplicate(true)
    legacy.version = 17
    legacy.players.host.erase("gear")
    legacy.players.host.progression.equipment = {}
    var migrated: Variant = STORE.migrate(legacy)
    _check(migrated is Dictionary and STORE.validate(migrated) and migrated.players.host.gear == {"items": [], "cooldowns": {}}, "v17 characters migrate with no gear")
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Gear checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
