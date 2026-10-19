extends SceneTree
## Step 24a systems (user decisions): damage credit (≥10% → full XP, absorbing, loot by rank),
## owned drops with a claim window, creature HP scaling for groups, creature levels and naming
## cost, death (5 s respawn at camp/spawn, 10% XP of the level span, the bag as a pile that never
## expires), hidden leveling spots (discovery, 3× faster respawns), refilling region deposits,
## minimap, saves and the v20 → v21 migration.
const REGION := preload("res://scripts/world/region_content.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const LAYOUT := preload("res://scripts/world/world_layout.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const CLAIM := preload("res://scripts/pickups/claim.gd")
const CAMP := preload("res://scripts/settlement/first_camp.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
var checks := 0
var failures := 0
var world: Node2D
var session: Node
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
func _creature(difficulty: int, at: Vector2) -> Node2D:
    serial += 1
    var enemy = GNASHER.instantiate()
    enemy.entity_id = "bal_%d" % serial
    enemy.difficulty = difficulty
    enemy.position = at
    world.add_child(enemy)
    world.wire_enemy(enemy)
    enemy.set_physics_process(false)
    return enemy
func _character(id: String, at: Vector2) -> CharacterBody2D:
    var other = load("res://scenes/player/player.tscn").instantiate()
    other.character_id = id
    other.local_controlled = false
    other.position = at
    world.add_child(other)
    return other
func _reachable(start: Vector2i) -> PackedByteArray:
    var seen := PackedByteArray()
    seen.resize(MAP.COLS * MAP.ROWS)
    # On foot from the start and from every ferry pier (M4.5c: the ferry lands).
    var queue: Array = [start]
    for ferry in MAP.HARBOURS:
        queue.append(Vector2i(ferry[2]))
    # M4.7: the secret hermit's door into the Ki Realm.
    queue.append(Vector2i(preload("res://scripts/realm/realm_catalogue.gd").ARRIVAL_TILE))
    for tile in queue:
        seen[MAP.tile_index(tile.x, tile.y)] = 1
    var head := 0
    while head < queue.size():
        var tile: Vector2i = queue[head]
        head += 1
        for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            var next: Vector2i = tile + step
            if not MAP.in_grid(next):
                continue
            var index := MAP.tile_index(next.x, next.y)
            if seen[index] == 0 and not MAP.solid(next.x, next.y):
                seen[index] = 1
                queue.append(next)
    return seen

func _run() -> void:
    # Exact XP and gathered amounts: no double early XP, no starter tools (see tests/sve_fixes.gd).
    preload("res://scripts/player/player.gd").starter_kit = false
    preload("res://scripts/player/player.gd").early_double_xp = false
    session = root.get_node("GameSession")
    # --- Leveling spots: placement and respawn speed
    var reach := _reachable(MAP.to_tile(LAYOUT.SPAWN))
    var spots_ok := REGION.SPOTS.size() == 30
    for entry in REGION.spot_creatures():
        var tile := Vector2i(entry[2])
        spots_ok = spots_ok and not MAP.solid(tile.x, tile.y) and reach[MAP.tile_index(tile.x, tile.y)] == 1 and MAP.region_at(REGION.at(entry[2])) != MAP.Region.CLEARING
    var per_region := {}
    for spot in REGION.SPOTS:
        var area: String = spot[0].get_slice("_", 1)
        per_region[area] = int(per_region.get(area, 0)) + 1
    spots_ok = spots_ok and MAP.region_at(REGION.at(REGION.SPOTS[2][2])) == MAP.Region.THORNWOOD and MAP.region_at(REGION.at(REGION.SPOTS[6][2])) == MAP.Region.CINDER_CRATER
    _check(spots_ok and per_region.size() == 14 and per_region.keys().all(func(area): return per_region[area] == (4 if area == "ki" else 2)), "Thirty hidden leveling spots: two per creature region, four in the big Ki Realm, on reachable land")
    _check(REGION.respawn_seconds("gnasher_1", 0) == 45.0 and REGION.respawn_seconds("x", 1) == 90.0 and REGION.respawn_seconds("x", 2) == 180.0 and REGION.respawn_seconds("spot_crater_a_1", 2) == 60.0, "Respawn by tier 45/90/180 s; leveling-spot creatures three times faster")
    # --- Creature levels and naming cost
    var ally_script = load("res://scripts/allies/goblin_ally.gd")
    _check(REGION.level_of("crater_gnasher_1", 2) == 12 and REGION.level_of("gnasher_1", 1) == 2 and REGION.level_of("spot_thornwood_a_2", 1) == 7, "Creatures have levels by place (clearing by tier)")
    _check(is_equal_approx(ally_script.naming_share(1), 0.375) and is_equal_approx(ally_script.naming_share(12), 0.65) and is_equal_approx(ally_script.naming_share(40), 0.9), "Naming costs 35% + 2.5% per monster level, at most 90%")
    # --- Hosted world for death rules
    var dir := OS.get_temp_dir().path_join("tempestrpg-balance-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24680, dir.path_join("balance.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    world.get_node("GoblinAlly").set_physics_process(false)
    var actor = world.get_local_player()
    var rival := _character("rival", Vector2(140, 560))
    var third := _character("third", Vector2(150, 560))
    # --- Damage credit: XP for ≥10%, Magicules split by share, the item to the top damage dealer
    actor.position = Vector2(120, 560)
    var elite := _creature(2, Vector2(130, 560))
    elite.get_node("Health").take_damage(44, actor)
    elite.get_node("Health").immunity_left = 0.0
    elite.get_node("Health").take_damage(12, rival)
    elite.get_node("Health").immunity_left = 0.0
    var before := {"me": int(actor.progression.experience), "rival": int(rival.progression.experience), "third": int(third.progression.experience)}
    var ranked: Array = elite.qualifying()
    _check(ranked.size() == 2 and ranked[0][0] == actor.character_id and is_equal_approx(ranked[0][1], 44.0 / 56.0), "Damage shares are tracked per character, most damage first")
    elite.get_node("Health").take_damage(4, third)
    await _frames(2)
    _check(int(actor.progression.experience) == before.me + LEVELING.DEFEAT_XP[2] and int(rival.progression.experience) == before.rival + LEVELING.DEFEAT_XP[2] and int(third.progression.experience) == before.third, "Full XP for every character with ≥10% of the damage; the last 4 of 60 (6.7%) gets none")
    var drops: Array = get_nodes_in_group("magicule_pickups").filter(func(pickup): return pickup.entity_id.begins_with("drop_" + elite.entity_id))
    var mine: Array = drops.filter(func(pickup): return pickup.owner_id == actor.character_id)
    var theirs: Array = drops.filter(func(pickup): return pickup.owner_id == "rival")
    var shares_total: float = (44.0 + 12.0) / 60.0
    _check(drops.size() == 2 and mine.size() == 1 and theirs.size() == 1 and is_equal_approx(mine[0].amount, 32.0 * (44.0 / 60.0) / shares_total) and is_equal_approx(theirs[0].amount, 32.0 * (12.0 / 60.0) / shares_total), "The Magicule drop is split among the qualifying characters by damage share")
    _check(not elite.may_absorb("third") and elite.may_absorb("rival") and elite.may_absorb(actor.character_id), "Only characters with ≥10% of the damage may absorb")
    # Gear: one roll, to the top damage dealer.
    var owned_item := false
    for attempt in range(40):
        var target := _creature(2, Vector2(200 + attempt, 620))
        world.loot_rng.seed = attempt
        target.get_node("Health").take_damage(40, rival)
        target.get_node("Health").immunity_left = 0.0
        target.get_node("Health").take_damage(30, actor)
        await _frames(1)
        var loot: Array = get_nodes_in_group("gear_pickups").filter(func(pickup): return pickup.position.distance_to(target.position) < 30.0)
        if not loot.is_empty():
            owned_item = loot.all(func(pickup): return pickup.owner_id == "rival" and pickup.claim_until > CLAIM.world_time(world))
            break
    _check(owned_item, "A dropped item belongs to the top damage dealer for the claim window")
    # Claim window.
    var claimed: Node2D = theirs[0]
    _check(not CLAIM.can_take(world, claimed.owner_id, claimed.claim_until, actor.character_id) and CLAIM.can_take(world, claimed.owner_id, claimed.claim_until, "rival"), "Owned drops: the owner only, during the claim window")
    world.progression.world_time = claimed.claim_until + 1.0
    _check(CLAIM.can_take(world, claimed.owner_id, claimed.claim_until, actor.character_id), "After 5 minutes anyone may take them")
    # --- Group HP scaling
    var scaled := _creature(1, Vector2(140, 580))
    scaled._scale_for_group()
    _check(scaled.get_node("Health").maximum == int(round(30 * 1.5)) and scaled.get_node("Health").current == scaled.get_node("Health").maximum, "+25% HP per extra character nearby when a fight starts (3 characters: 45 HP)")
    scaled._group_scaled = false
    scaled.get_node("Health").current -= 1
    scaled._scale_for_group()
    _check(scaled.get_node("Health").maximum == 45, "A hurt creature is not rescaled")
    for helper in [rival, third]:
        world.remove_child(helper)
        helper.queue_free()
    # --- Death: XP loss, the bag as a pile, respawn after 5 s
    LEVELING.grant(actor, LEVELING.xp_for_level(4) - int(actor.progression.experience) + 1000)
    var xp_before: int = int(actor.progression.experience)
    var span: int = LEVELING.xp_for_level(5) - LEVELING.xp_for_level(4)
    actor.get_node("Inventory").add_specimen(load("res://data/specimens/forest_gnasher.tres"))
    actor.get_node("Inventory").add_specimen(load("res://data/specimens/forest_gnasher.tres"))
    var rng := RandomNumberGenerator.new()
    rng.seed = 4
    var worn: Dictionary = preload("res://scripts/items/gear_sources.gd").roll_chest(rng)
    var spare: Dictionary = preload("res://scripts/items/gear_sources.gd").roll_chest(rng)
    # Loot popped out earlier may have landed under the character: start from an empty gear bag.
    actor.gear.items = []
    actor.progression.equipment = {}
    actor.add_item(worn)
    actor.add_item(spare)
    var kind: String = preload("res://scripts/items/gear_catalogue.gd").BASES[worn.base].slot
    # A random chest piece may ask for a class or level (M12b); this check is about death piles (the rules stay off for the rest of the run).
    var classes := preload("res://scripts/progression/class_catalogue.gd")
    classes.enforced = false
    actor.equip(worn.id, "accessory_1" if kind == "accessory" else kind)
    actor.position = Vector2(700, 360)
    var fell_at: Vector2 = actor.position
    actor.get_node("Health").take_damage(9999)
    await _frames(2)
    _check(actor.progression.experience == xp_before - int(floor(span * 0.1)) and actor.progression.level == 4, "Defeat costs 10% of the level's XP span, never a level")
    var piles: Array = get_nodes_in_group("item_piles")
    _check(piles.size() == 1 and piles[0].owner_id == actor.character_id and piles[0].materials.get("gnasher_essence", 0) == 2 and piles[0].items.size() == 1 and piles[0].items[0].id == spare.id and piles[0].position == fell_at, "The bag (materials, unequipped gear) drops as your pile where you fell")
    _check(actor.get_node("Inventory").total_units() == 0 and actor.gear.items.size() == 1 and actor.gear.items[0].id == worn.id, "Equipped gear stays with you")
    _check(actor.death_left > actor.RESPAWN_DELAY - 0.5 and actor.death_left < actor.RESPAWN_DELAY and world.get_node("HUD")._respawn_label.visible, "A 5 s respawn countdown starts and is shown")
    actor._process(4.0)
    _check(actor.get_node("Health").current == 0, "No respawn before 5 s")
    actor._process(1.1)
    _check(actor.get_node("Health").current == actor.get_node("Health").maximum and actor.position == LAYOUT.SPAWN and is_equal_approx(actor.get_node("Magicules").current, actor.get_node("Magicules").maximum), "Respawned at the spawn (camp not founded) with full HP and Magicules")
    # Second defeat: a second pile; the first stays.
    actor.get_node("Inventory").add_specimen(load("res://data/specimens/thornback_gnasher.tres"))
    actor.position = Vector2(760, 360)
    actor.get_node("Health").immunity_left = 0.0
    actor.get_node("Health").take_damage(9999)
    await _frames(2)
    _check(get_nodes_in_group("item_piles").size() == 2, "Dying again adds a second pile; the first stays")
    # Founded camp: respawn at the camp flag.
    var state: Dictionary = world.camp.state.duplicate(true)
    state.founded = true
    state.founder = actor.character_id
    world.camp.restore(state)
    actor.death_left = 0.01
    actor._process(0.1)
    _check(actor.position == world.camp.SITE + Vector2(0, 26), "With a founded camp you respawn at the camp flag")
    # Recover the first pile (the second, 60 px away, stays — even right after a far respawn).
    var first_pile: Node2D = piles[0]
    actor.position = first_pile.position
    await _frames(3)
    _check((not is_instance_valid(first_pile) or first_pile.is_queued_for_deletion()) and get_nodes_in_group("item_piles").size() == 1, "Walking over your pile recovers it; the other pile stays")
    _check(actor.get_node("Inventory").entries().any(func(entry): return String(entry.id) == "gnasher_essence" and entry.count == 2) and actor.item_by_id(spare.id).size() > 0, "Materials and gear come back")
    # --- Hidden leveling spot discovery
    var spot: Array = REGION.SPOTS[0]
    actor.position = REGION.at(spot[2])
    await _frames(2)
    _check(spot[0] in actor.progression.get("spots", []), "Coming close discovers a hidden leveling spot")
    # --- Region deposit refill
    actor.position = world.camp.sites.wood_meadow_1.position
    var wood_before: int = world.camp.state.wood
    _check(world.camp.transact(actor, "gather", "wood_meadow_1") and world.camp.state.refill_left.has("wood_meadow_1") and not world.camp.state.refill_left.has("wood_1"), "Gathering a region deposit starts its 15-minute refill")
    world.camp._refill(CAMP.REFILL_SECONDS)
    _check(world.camp.state.deposits.wood_meadow_1 == 10 and world.camp.state.refills.wood_meadow_1 == 1 and world.camp.state.wood == wood_before + 10, "After 15 minutes the deposit is full again")
    _check(world.camp.transact(actor, "gather", "wood_meadow_1") and CAMP.valid_state(world.camp.state, {actor.character_id: true, "host": true}, world.camp.sites), "Refilled deposits keep the camp stock check consistent")
    # --- Saves
    var document: Dictionary = CODEC.capture_entities(world)
    document.merge({"version": STORE.VERSION, "world_id": "balance_test", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    _check(STORE.validate(document) and document.piles.size() >= 1 and document.pickups.all(func(entry): return entry.has("owner")), "Piles, owners and refills save and validate")
    var bad := document.duplicate(true)
    bad.piles[0].materials = {"gnasher_essence": 0}
    _check(not STORE.validate(bad), "Corrupt piles are rejected")
    var old := document.duplicate(true)
    old.version = 20
    old.erase("piles")
    old.camp.erase("refills")
    old.camp.erase("refill_left")
    for list in [old.loot, old.pickups]:
        for entry in list:
            entry.erase("owner")
            entry.erase("claim_until")
    old.enemies = old.enemies.filter(func(enemy): return not REGION.is_spot_creature(enemy.id))
    old.respawns = old.respawns.filter(func(entry): return not REGION.is_spot_creature(entry.id))
    old.camp.deposits.wood_meadow_1 = 10
    old.camp.wood = old.camp.wood - 20
    var migrated: Variant = STORE.migrate(old)
    _check(migrated is Dictionary and migrated.version == STORE.VERSION and STORE.validate(migrated) and migrated.piles.is_empty() and migrated.enemies.any(func(enemy): return enemy.id == "spot_crater_b_3"), "v20 worlds migrate to v21 (no piles, no owners, leveling-spot creatures added)")
    # --- Minimap
    var hud = world.get_node("HUD")
    _check(hud.minimap != null and hud.minimap.is_visible_in_tree() and hud.minimap.texture().get_size() == Vector2(MAP.COLS, MAP.ROWS) and Rect2(hud.minimap.position, hud.minimap.size).end.x <= 640, "The round minimap sits top right with the world map's terrain")
    session.quit_to_title()
    await _frames(3)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Balance system checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
