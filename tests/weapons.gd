extends SceneTree
## Weapons (step 17f): the weapon slot, four types with their own attack shape and timing (sword
## arc, spear line, scythe sweep, bow shot with range and line of sight), rarity-scaled damage,
## race and gear bonuses on top, HUD line, saves and validation.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
const AT := Vector2(150, 580)
var checks := 0
var failures := 0
var world: Node2D
var actor: Node2D
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
func _weapon(base: String, damage: int, rarity: int = 0) -> Dictionary:
    return {"id": "item_w" + Crypto.new().generate_random_bytes(6).hex_encode(), "base": base, "rarity": rarity, "stats": {"damage": damage}, "passives": [] if rarity < 2 else (["lifesteal"] if rarity < 4 else ["lifesteal", "keen"]), "active": "" if rarity < 3 else "barrier"}
## Place creatures at offsets from the actor, swing once facing right, return the damage each took.
func _swing(offsets: Array, wait: int = 0) -> Array:
    var creatures: Array = []
    for offset in offsets:
        serial += 1
        var enemy = GNASHER.instantiate()
        enemy.entity_id = "w_target_%d" % serial
        enemy.position = AT + offset
        world.add_child(enemy)
        enemy.set_physics_process(false)
        creatures.append(enemy)
    await _frames(2)
    actor.position = AT
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    actor.get_node("Magicules")._current = actor.get_node("Magicules").maximum
    actor.get_node("MeleeAttack").attack(Vector2.RIGHT)
    # Arrows fly (24a): give them time to arrive.
    if wait > 0:
        await _frames(wait)
    var result: Array = creatures.map(func(enemy): return 30 - enemy.get_node("Health").current)
    for enemy in creatures:
        world.remove_child(enemy)
        enemy.queue_free()
    return result

func _run() -> void:
    # --- Catalogue
    var types := {}
    var valid := true
    var rng := RandomNumberGenerator.new()
    rng.seed = 99
    for base in GEAR.BASES:
        if GEAR.BASES[base].slot == "weapon":
            types[GEAR.BASES[base].weapon] = true
            for rarity in range(int(GEAR.BASES[base].get("min_rarity", 0)), GEAR.RARITIES.size()):
                valid = valid and GEAR.valid_item(GEAR.roll(base, rarity, rng))
    _check(types.keys().size() == 5 and types.has("dagger") and types.has("sword") and types.has("spear") and types.has("scythe") and types.has("bow"), "Five weapon types: dagger, sword, spear, scythe, bow")
    _check(valid and GEAR.SLOTS.has("weapon"), "Rolled weapons of every rarity validate; there is a weapon slot")
    _check(GEAR.stat_range("iron_sword", "damage", 4) == [26.0, 33.0], "Rarity scales weapon damage (Legendary sword 26–33)")
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    actor = world.get_local_player()
    var melee = actor.get_node("MeleeAttack")
    var sword := _weapon("iron_sword", 14)
    var spear := _weapon("ash_spear", 15)
    var scythe := _weapon("field_scythe", 18)
    var bow := _weapon("hunting_bow", 10)
    for item in [sword, spear, scythe, bow]:
        actor.add_item(item)
    _check(not actor.equip(sword.id, "head") and not actor.equip(_weapon("iron_sword", 14).id, "weapon"), "Weapons only go in the weapon slot; only owned weapons can be equipped")
    # --- Unarmed baseline
    var hits: Array = await _swing([Vector2(18, 0), Vector2(50, 0)])
    _check(hits == [12, 0] and is_equal_approx(melee.cooldown_left, 0.4), "Unarmed (Slime, 24b): 12 damage close in, 0.4 s")
    # --- Sword: balanced arc
    actor.equip(sword.id, "weapon")
    hits = await _swing([Vector2(30, 0), Vector2(20, 14), Vector2(-20, 0)])
    _check(hits == [14, 14, 0] and is_equal_approx(melee.cooldown_left, 0.45), "Sword: 14 damage in a front arc (reaches 30 px), nothing behind, 0.45 s")
    # --- Spear: long thrust through a line
    actor.equip(spear.id, "weapon")
    hits = await _swing([Vector2(22, 0), Vector2(48, 0), Vector2(40, 22)])
    _check(hits == [15, 15, 0] and is_equal_approx(melee.cooldown_left, 0.55), "Spear: 15 damage to everything in a narrow line up to ~56 px, not to the side, 0.55 s")
    # --- Scythe: wide sweep
    actor.equip(scythe.id, "weapon")
    hits = await _swing([Vector2(20, 0), Vector2(4, 26), Vector2(4, -26), Vector2(-30, 0)])
    _check(hits == [18, 18, 18, 0] and is_equal_approx(melee.cooldown_left, 0.75), "Scythe: 18 damage in a wide sweep including both sides, not behind, 0.75 s")
    # --- Bow: ranged, first creature, line of sight
    actor.equip(bow.id, "weapon")
    hits = await _swing([Vector2(150, 0)])
    _check(hits == [0] and get_nodes_in_group("enemies").size() >= 0, "Bow: the arrow has not arrived in the same frame (it flies)")
    hits = await _swing([Vector2(150, 0)], 40)
    _check(hits == [10] and melee.cooldown_left < 0.6, "Bow: the arrow hits for 10 damage at 150 px after flying")
    hits = await _swing([Vector2(80, 0), Vector2(140, 0)], 40)
    _check(hits == [10, 0], "Bow: only the first creature in line is hit")
    hits = await _swing([Vector2(230, 0)], 50)
    _check(hits == [0], "Bow: nothing beyond 200 px")
    world._add_obstacle(Rect2(AT + Vector2(60, -12), Vector2(6, 24)))
    hits = await _swing([Vector2(120, 0)], 40)
    _check(hits == [0] and melee.shot_end.x < 70, "Bow: terrain stops the shot")
    # --- Bonuses stack on the weapon
    actor.equip(sword.id, "weapon")
    actor.choose_race("Human")
    hits = await _swing([Vector2(30, 0)])
    _check(hits == [14] and is_equal_approx(melee.cooldown_left, 0.45 * 0.75), "Weapons keep their own damage for every race (sword 14); Humans recover 25%% faster")
    var gloves := {"id": "item_wgloves000001", "base": "leather_gloves", "rarity": 0, "stats": {"strike": 2}, "passives": [], "active": ""}
    actor.add_item(gloves)
    actor.equip(gloves.id, "hands")
    hits = await _swing([Vector2(30, 0)])
    _check(hits == [16], "Gloves' strike bonus adds to the weapon (14 + 2)")
    var legendary := _weapon("iron_sword", 30, 4)
    actor.add_item(legendary)
    actor.equip(legendary.id, "weapon")
    actor.get_node("Health").current = 50
    hits = await _swing([Vector2(30, 0)])
    _check(hits == [30] and actor.get_node("Health").current == 51, "A Legendary sword hits for its rolled damage (capped by the creature's 30 HP) and its Lifesteal heals")
    await _frames(1)
    _check(world.get_node("HUD").get_node("StrikeCost").text.begins_with("Sword: 30 dmg"), "The HUD shows the equipped weapon and its damage")
    # --- Saves
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-weapons-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var path := dir.path_join("weapons.json")
    _check(session.start_host(24690, path, false, {"name": "Weapons", "seed": 0, "created": 1, "last_played": 1}, "Human") == OK and session.save_world() == OK, "World with weapons saves")
    var saved: Dictionary = STORE.load_world(path)
    _check(saved.ok and saved.data.players.host.progression.equipment.get("weapon") == legendary.id, "The equipped weapon is saved")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24690, path, false) == OK and world.get_local_player().equipped_weapon().get("id") == legendary.id, "Reload keeps the weapon equipped")
    session.stop_session(false)
    var bad: Dictionary = saved.data.duplicate(true)
    bad.players.host.progression.equipment["head"] = sword.id
    var strong: Dictionary = saved.data.duplicate(true)
    for item in strong.players.host.gear.items:
        if item.id == sword.id:
            item.stats.damage = 99
    _check(not STORE.validate(bad) and not STORE.validate(strong), "Rejected: a weapon in an armor slot, weapon damage outside its rarity's range")
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Weapon checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
