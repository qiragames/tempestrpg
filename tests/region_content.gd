extends SceneTree
## Region content (M4.5b): creatures, deposits and chests in the archipelago's regions — placed on
## reachable land in their regions, spawned with stable IDs, gathered into the camp stock, the
## keep/crater chests' better odds, respawning, saving, and the v20 migration of older worlds.
const MAP := preload("res://scripts/world/world_map.gd")
const REGION := preload("res://scripts/world/region_content.gd")
const CAMP := preload("res://scripts/settlement/first_camp.gd")
const LAYOUT := preload("res://scripts/world/world_layout.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
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

func _document(world: Node2D, actor: Node2D) -> Dictionary:
    var data: Dictionary = CODEC.capture_entities(world)
    data.merge({"version": STORE.VERSION, "world_id": "region_test", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    return data

func _run() -> void:
    # Exact XP and gathered amounts: no double early XP, no starter tools (see tests/sve_fixes.gd).
    preload("res://scripts/player/player.gd").starter_kit = false
    preload("res://scripts/player/player.gd").early_double_xp = false
    # --- Placement
    var reach := _reachable(MAP.to_tile(LAYOUT.SPAWN))
    var expected_region := {"thornwood": MAP.Region.THORNWOOD, "crater": MAP.Region.CINDER_CRATER, "lakeshore": -1, "meadow": MAP.Region.VERDANT, "beach": MAP.Region.VERDANT, "keep": MAP.Region.MIRROR_LAKE, "harrowmere": MAP.Region.HARROWMERE,
        # M4.5c regions: creatures by kind, chests by name.
        "frost": MAP.Region.FROSTPEAK, "snow": MAP.Region.FROSTPEAK, "glacier": MAP.Region.FROSTPEAK,
        "dune": MAP.Region.SUNSCORCH, "sand": MAP.Region.SUNSCORCH, "dunes": MAP.Region.SUNSCORCH,
        "amber": MAP.Region.AMBERVALE, "burrow": MAP.Region.AMBERVALE,
        "bog": MAP.Region.MIREWOOD, "mirecap": MAP.Region.MIREWOOD, "marsh": MAP.Region.MIREWOOD,
        "bamboo": MAP.Region.SAKURA_VALE, "paper": MAP.Region.SAKURA_VALE, "shrine": MAP.Region.SAKURA_VALE,
        "ember": MAP.Region.EMBERREACH, "salamander": MAP.Region.EMBERREACH, "volcano": MAP.Region.EMBERREACH,
        # M4.7 the Ki Realm.
        "raptor": MAP.Region.KI_REALM, "tyrant": MAP.Region.KI_REALM, "gi": MAP.Region.KI_REALM, "monkey": MAP.Region.KI_REALM,
        "android": MAP.Region.KI_REALM, "bio": MAP.Region.KI_REALM, "demon": MAP.Region.KI_REALM, "ki": MAP.Region.KI_REALM}
    var placed_ok := true
    var spots: Array = []
    for entry in REGION.CREATURES:
        spots.append([entry[0], entry[2]])
    for entry in REGION.DEPOSITS + REGION.CHESTS:
        spots.append([entry[0], entry[1]])
    for spot in spots:
        var tile := Vector2i(spot[1])
        var area: String = spot[0].trim_prefix("chest_").trim_prefix("wood_").trim_prefix("stone_").get_slice("_", 0)
        var region: int = MAP.region_at(REGION.at(spot[1]))
        var wanted: int = expected_region.get(area, -2)
        if MAP.solid(tile.x, tile.y) or reach[MAP.tile_index(tile.x, tile.y)] == 0 or (wanted >= 0 and region != wanted) or region in [MAP.Region.CLEARING, MAP.Region.SEA]:
            placed_ok = false
            push_error("Badly placed: %s at %s (region %d)" % [spot[0], spot[1], region])
    _check(placed_ok, "Every region creature, deposit and chest stands on reachable land in its own region")
    _check(REGION.CREATURES.all(func(entry): return MAP.region_at(REGION.at(entry[2])) != MAP.Region.HARROWMERE), "Harrowmere stays peaceful (no creatures)")
    var ids := {}
    for id in REGION.creature_ids() + LAYOUT.CREATURE_IDS:
        ids[id] = true
    _check(ids.size() == REGION.all_creatures().size() + LAYOUT.CREATURE_IDS.size() and REGION.CREATURES.size() >= 12, "%d region and leveling-spot creatures with unique stable IDs" % REGION.all_creatures().size())
    var crater_elite := REGION.CREATURES.filter(func(entry): return entry[0].begins_with("crater_")).all(func(entry): return entry[3] == 2)
    var meadow_easy := REGION.CREATURES.filter(func(entry): return entry[0].begins_with("meadow_gnasher_1") or entry[0].begins_with("beach_")).all(func(entry): return entry[3] == 0)
    _check(crater_elite and meadow_easy, "Danger grows with the region: easy meadows and beach, elite Cinder Crater")
    # --- Tables
    var deposits := REGION.deposits()
    _check(deposits.size() == 6 and deposits.values().all(func(deposit): return deposit.outlying) and LAYOUT.generate(0).deposits.has("stone_crater_1") and LAYOUT.generate(4242).deposits.has("wood_thornwood_1"), "Six region deposits (outlying) are part of every world's camp table")
    var positions_ok := true
    for entry in REGION.DEPOSITS:
        positions_ok = positions_ok and CAMP.DEPOSITS[entry[0]].position == REGION.at(entry[1])
    _check(positions_ok, "The camp table's region positions match their tiles")
    _check(LAYOUT.ALL_CHEST_IDS == LAYOUT.CHEST_IDS + REGION.chest_ids(), "Region chests extend the chest list")
    # --- In the world
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    var spawned_ok := true
    for entry in REGION.CREATURES:
        var creature = world.entity_by_id(entry[0])
        spawned_ok = spawned_ok and creature != null and creature.kind == entry[1] and creature.difficulty == entry[3] and creature.home == REGION.at(entry[2]) and creature.get_node("Health").maximum == creature.scaled_health(entry[3], REGION.level_of(entry[0], entry[3]))
    _check(spawned_ok, "Each region creature spawns at its home with its kind and difficulty")
    _check(world.layout.chests.size() == LAYOUT.CHEST_IDS.size() + REGION.chests().size() and REGION.chests().size() == REGION.CHESTS.size() + 5 and world.camp.sites.has("stone_crater_1"), "The world knows the region chests (and the five dungeon chests) and deposits")
    # Gather a region deposit into the shared stock.
    world.camp.state.founded = true
    world.camp.state.founder = actor.character_id
    actor.position = world.camp.sites.stone_crater_1.position
    var stone_before: int = world.camp.state.stone
    _check(world.camp.transact(actor, "gather", "stone_crater_1") and world.camp.state.stone == stone_before + 12 and world.camp.state.deposits.stone_crater_1 == 0, "Explorers gather Cinder Crater stone into the camp stock")
    var ally = world.get_node("GoblinAlly")
    _check(not REGION.deposits().has(ally._next_deposit()), "Allied workers never walk off to region deposits")
    # Rich chest at the keep.
    actor.position = REGION.at(REGION.CHESTS[1][1])
    world.loot_rng.seed = 5
    _check(world.nearest_chest(actor) == "chest_keep" and world.open_chest(actor, "chest_keep"), "The keep's chest opens on the islet")
    # The item pops out beside the chest (SVE feedback), claimed by the opener.
    var popped: Array = get_nodes_in_group("gear_pickups").filter(func(node): return node.owner_id == actor.character_id)
    var keep_item: Dictionary = popped.back().item if not popped.is_empty() else {"rarity": -1}
    _check(int(keep_item.rarity) >= 2 and "chest_keep" in actor.progression.chests, "The keep's chest gives Rare or better (trial odds) and is remembered")
    var rich_ok := true
    for seed in range(40):
        world.loot_rng.seed = seed
        rich_ok = rich_ok and int(world.SOURCES.roll_trial(world.loot_rng).rarity) >= 2
    _check(rich_ok, "Rich chests never roll Common or Uncommon")
    # Defeat → respawn schedule at its home.
    var crater = world.entity_by_id("crater_thornback_1")
    crater.get_node("Health").take_damage(999)
    await _frames(2)
    _check(world.respawner.scheduled("crater_thornback_1"), "Defeated region creatures respawn like the clearing's")
    # Save round trip.
    var document := _document(world, actor)
    _check(STORE.validate(document), "A world with region content saves and validates")
    var saved_ids: Array = document.enemies.map(func(enemy): return enemy.id)
    _check(REGION.creature_ids().all(func(id): return id in saved_ids), "Every region creature is saved")
    # --- v20 migration: an older (v19) world gets the region content.
    var old := document.duplicate(true)
    old.version = 19
    for id in REGION.deposits():
        old.camp.deposits.erase(id)
    old.camp.stone = 0
    old.enemies = old.enemies.filter(func(enemy): return not enemy.id in REGION.creature_ids())
    old.respawns = old.respawns.filter(func(entry): return not entry.id in REGION.creature_ids())
    for state in old.players.values():
        state.progression.chests = []
    var migrated: Variant = STORE.migrate(old)
    _check(migrated is Dictionary and migrated.version == STORE.VERSION and STORE.validate(migrated), "A v19 world migrates to v20 and validates")
    _check(migrated.camp.deposits.stone_crater_1 == 12 and migrated.camp.deposits.size() == CAMP.DEPOSITS.size(), "Migrated worlds get untouched region deposits")
    var migrated_ids: Array = migrated.enemies.map(func(enemy): return enemy.id)
    _check(REGION.creature_ids().all(func(id): return id in migrated_ids) and migrated.enemies.filter(func(enemy): return enemy.id == "crater_gnasher_1")[0].hp == 204, "Migrated worlds get fresh region creatures at full health (level 12 Elite: 204 HP)")
    var applied: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    world.queue_free()
    root.add_child(applied)
    await _frames()
    CODEC.apply_entities(applied, migrated, false)
    await _frames()
    _check(applied.entity_by_id("thornwood_gnasher_3") != null and applied.entity_by_id("thornwood_gnasher_3").difficulty == 2, "Loading the migrated world restores the region creatures")
    applied.queue_free()
    await _frames()
    print("Region content checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
