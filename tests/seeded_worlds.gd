extends SceneTree
## Seeded worlds (16d): determinism, the reference map, placement rules and reachability over many
## seeds, save validation/migration, and a hosted world laid out, saved and reloaded from its seed.
const LAYOUT := preload("res://scripts/world/world_layout.gd")
const CAMP := preload("res://scripts/settlement/first_camp.gd")
const TRIAL := preload("res://scripts/trials/proving_trial.gd")
const REGISTRY := preload("res://scripts/menu/world_registry.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const SEEDS := 200
const CELL := 8.0
const PLAYER_RADIUS := 6.0
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

## Every collision rectangle of a layout (pond, rocks, tree trunks), as the world builds them.
func _obstacles(layout: Dictionary) -> Array:
    var rects: Array = [LAYOUT.POND]
    rects.append_array(layout.rocks)
    for tree in layout.trees:
        rects.append(Rect2(tree + Vector2(-6, 4), Vector2(12, 12)))
    return rects

## Flood fill on an 8 px grid from the spawn; a cell is open when the player circle fits at its centre.
func _reachable(layout: Dictionary) -> Dictionary:
    var width := int(LAYOUT.WORLD.size.x / CELL)
    var height := int(LAYOUT.WORLD.size.y / CELL)
    var blocked: Array = []
    var rects: Array = _obstacles(layout)
    for y in range(height):
        for x in range(width):
            var centre := Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
            var hit := not LAYOUT.WORLD.grow(-PLAYER_RADIUS).has_point(centre)
            for rect in rects:
                hit = hit or rect.grow(PLAYER_RADIUS).has_point(centre)
            blocked.append(hit)
    var seen: Dictionary = {}
    var start := Vector2i(int(LAYOUT.SPAWN.x / CELL), int(LAYOUT.SPAWN.y / CELL))
    var queue: Array = [start]
    seen[start] = true
    while not queue.is_empty():
        var cell: Vector2i = queue.pop_back()
        for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            var next: Vector2i = cell + step
            if next.x >= 0 and next.y >= 0 and next.x < width and next.y < height and not seen.has(next) and not blocked[next.y * width + next.x]:
                seen[next] = true
                queue.append(next)
    return seen

## True when the player can stand within `distance` of the point.
func _can_reach(seen: Dictionary, point: Vector2, distance: float) -> bool:
    var reach := int(ceil(distance / CELL))
    var base := Vector2i(int(point.x / CELL), int(point.y / CELL))
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            var cell := base + Vector2i(dx, dy)
            if seen.has(cell) and Vector2((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL).distance_to(point) <= distance:
                return true
    return false

func _inside(point: Vector2) -> bool:
    return LAYOUT.WORLD.grow(-24).has_point(point) and not LAYOUT.POND.grow(8).has_point(point)

func _run() -> void:
    # --- Determinism and the reference map
    var reference := LAYOUT.generate(0)
    _check(reference.deposits == CAMP.DEPOSITS and reference.stone == TRIAL.STONE and reference.trees.size() == 8 and reference.rocks.size() == 2, "Seed 0 is the hand-made reference map")
    _check(reference.creatures.gnasher_1.position == Vector2(620, 360) and reference.ally == Vector2(220, 360), "Reference creatures and ally keep their classic spots")
    var same := true
    for seed in [1, 42, 1234, 99999, REGISTRY.MAX_SEED, REGISTRY.parse_seed("goblin camp")]:
        same = same and LAYOUT.generate(seed) == LAYOUT.generate(seed)
    _check(same, "Same seed gives the same layout")
    var stones: Dictionary = {}
    var allies: Dictionary = {}
    var difficulties: Dictionary = {}
    var tree_counts: Dictionary = {}
    var distinct: Dictionary = {}
    # --- Placement rules and reachability over many seeds
    var problems: Dictionary = {"ids": [], "amounts": [], "budget": [], "near": [], "inside": [], "creatures": [], "spacing": [], "decor": [], "reach": [], "trial": []}
    for seed in range(1, SEEDS + 1):
        var layout := LAYOUT.generate(seed)
        distinct[str(layout.deposits.wood_3.position) + str(layout.creatures.gnasher_1.position)] = true
        stones[layout.stone] = true
        allies[layout.ally] = true
        tree_counts[layout.trees.size()] = true
        for id in layout.creatures:
            difficulties["%s:%d" % [id, layout.creatures[id].difficulty]] = true
        if layout.deposits.keys() != CAMP.DEPOSITS.keys() or layout.creatures.keys() != LAYOUT.CREATURE_IDS:
            problems.ids.append(seed)
        var totals := {"wood": 0, "stone": 0}
        for id in CAMP.SEEDED_DEPOSITS:
            var deposit: Dictionary = layout.deposits[id]
            totals[deposit.resource] += deposit.amount
            if deposit.resource != CAMP.DEPOSITS[id].resource or deposit.outlying != CAMP.DEPOSITS[id].outlying or (not deposit.outlying and deposit.amount != CAMP.DEPOSITS[id].amount) or (deposit.outlying and (deposit.amount < 8 or deposit.amount > 12)):
                problems.amounts.append(seed)
            if not _inside(deposit.position):
                problems.inside.append(seed)
            if not deposit.outlying and (deposit.position.distance_to(CAMP.SITE) > 80 or not LAYOUT._clear_of_structures(deposit.position, 12.0)):
                problems.near.append(seed)
            if deposit.outlying and deposit.position.distance_to(CAMP.SITE) < 220:
                problems.near.append(seed)
        # Every structure must stay affordable from deposits alone (essence comes from offerings);
        # the fixed region deposits (M4.5b) are in every world and refill, so they count too.
        for id in CAMP.DEPOSITS:
            if not id in CAMP.SEEDED_DEPOSITS:
                totals[layout.deposits[id].resource] += layout.deposits[id].amount
        var needed := {"wood": 0, "stone": 0}
        for id in CAMP.STRUCTURES:
            for resource in needed:
                needed[resource] += CAMP.STRUCTURES[id].cost.get(resource, 0)
        if totals.wood < needed.wood or totals.stone < needed.stone:
            problems.budget.append(seed)
        for id in layout.creatures:
            var creature: Dictionary = layout.creatures[id]
            if not _inside(creature.position) or creature.position.distance_to(CAMP.SITE) < 190 or creature.position.distance_to(layout.stone) < 230 or creature.difficulty < 0 or creature.difficulty > 2:
                problems.creatures.append(seed)
            if (id == "gnasher_1" and creature.difficulty == 2) or (id == "thornback_1" and creature.difficulty == 0):
                problems.creatures.append(seed)
            for other in layout.creatures:
                if other != id and creature.position.distance_to(layout.creatures[other].position) < 90:
                    problems.spacing.append(seed)
        for rect in _obstacles(layout).slice(1):
            var bad: bool = rect.grow(6).has_point(LAYOUT.SPAWN) or rect.grow(10).has_point(CAMP.SITE) or rect.intersects(LAYOUT.ROADS[0]) or rect.intersects(LAYOUT.ROADS[1]) or rect.grow(20).has_point(layout.stone)
            for id in CAMP.SEEDED_DEPOSITS:
                bad = bad or rect.grow(12).has_point(layout.deposits[id].position)
            for id in CAMP.STRUCTURES:
                bad = bad or rect.intersects(Rect2(CAMP.STRUCTURES[id].site - CAMP.STRUCTURES[id].size / 2, CAMP.STRUCTURES[id].size))
            if bad:
                problems.decor.append(seed)
        for offset in TRIAL.SPAWNS:
            for rect in _obstacles(layout):
                if rect.grow(10).has_point(layout.stone + offset) or not _inside(layout.stone + offset):
                    problems.trial.append(seed)
        var seen := _reachable(layout)
        var targets: Array = [CAMP.SITE, layout.stone, layout.ally]
        for id in CAMP.SEEDED_DEPOSITS:
            targets.append(layout.deposits[id].position)
        for id in layout.creatures:
            targets.append(layout.creatures[id].position)
        for offset in TRIAL.SPAWNS:
            targets.append(layout.stone + offset)
        for target in targets:
            if not _can_reach(seen, target, 20.0):
                problems.reach.append([seed, target])
                break
    _check(problems.ids.is_empty(), "%d seeds keep the stable deposit and creature IDs %s" % [SEEDS, problems.ids.slice(0, 5)])
    _check(problems.amounts.is_empty(), "Deposits keep their resource and role; camp piles 8, outlying 8–12 %s" % [problems.amounts.slice(0, 5)])
    _check(problems.budget.is_empty(), "Every seed has enough wood and stone for all buildings %s" % [problems.budget.slice(0, 5)])
    _check(problems.near.is_empty(), "Camp deposits ring the camp clear of building sites; outlying ones are out in the wilds %s" % [problems.near.slice(0, 5)])
    _check(problems.inside.is_empty(), "Deposits stay inside the map and out of the pond %s" % [problems.inside.slice(0, 5)])
    _check(problems.creatures.is_empty(), "Creatures avoid the camp and trial stone; first Gnasher never Elite, Thornback never Easy %s" % [problems.creatures.slice(0, 5)])
    _check(problems.spacing.is_empty(), "Creatures are spread apart %s" % [problems.spacing.slice(0, 5)])
    _check(problems.decor.is_empty(), "Trees and rocks stay off roads, the camp, buildings, deposits and the trial stone %s" % [problems.decor.slice(0, 5)])
    _check(problems.trial.is_empty(), "Trial creatures always spawn on open ground %s" % [problems.trial.slice(0, 5)])
    _check(problems.reach.is_empty(), "From the spawn every deposit, creature, the camp, the ally and the trial are reachable on foot %s" % [problems.reach.slice(0, 3)])
    _check(distinct.size() > SEEDS * 0.9, "Seeds produce different worlds (%d distinct of %d)" % [distinct.size(), SEEDS])
    _check(stones.size() == LAYOUT.STONE_SPOTS.size() and allies.size() == LAYOUT.ALLY_SPOTS.size(), "The trial stone and ally start use every candidate spot")
    _check(difficulties.has("gnasher_1:0") and difficulties.has("gnasher_2:2") and difficulties.has("thornback_1:2") and tree_counts.size() >= 3, "Creature difficulty and decoration counts vary")
    # --- Seed parsing and labels
    var zero := false
    for index in range(500):
        zero = zero or REGISTRY.parse_seed("") == 0
    _check(not zero and REGISTRY.parse_seed("0") == 0, "Random seeds are never the reference map; typing 0 chooses it")
    var meta := REGISTRY.new_meta("Seeded", 777)
    _check(meta.seeded and LAYOUT.seed_of(meta) == 777 and LAYOUT.describe(meta) == "seed 777", "New worlds are laid out from their seed")
    _check(LAYOUT.seed_of({"seed": 777, "seeded": false}) == 0 and LAYOUT.describe({"seed": 777, "seeded": false}) == "original map", "Unseeded (older) worlds keep the original map")
    # --- A world laid out from its seed, hosted, saved and reloaded
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-seeds-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var path := dir.path_join("seeded.json")
    var world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(world.layout.seed == 0 and world.camp.sites == CAMP.DEPOSITS and world.trial.stone == TRIAL.STONE, "An unhosted world shows the reference map")
    _check(session.start_host(24620, path, false, meta) == OK, "Solo world hosted with seed 777")
    await _frames()
    var expected := LAYOUT.generate(777)
    # The world adds the fixed region chests (M4.5b) after the seeded three.
    expected.chests = expected.chests + preload("res://scripts/world/region_content.gd").chests()
    var placed := true
    for id in expected.creatures:
        var enemy: Node2D = world.entity_by_id(id)
        placed = placed and enemy.position == expected.creatures[id].position and enemy.home == enemy.position and enemy.difficulty == expected.creatures[id].difficulty and enemy.get_node("Health").maximum == enemy.TIER_STATS[enemy.difficulty].health and enemy.get_node("Health").current == enemy.get_node("Health").maximum
    _check(placed, "Fresh world places creatures at their seeded spots with seeded difficulty and full health")
    _check(world.entity_by_id(LAYOUT.ALLY_ID).position == expected.ally and world.trial.stone == expected.stone and world.camp.sites == expected.deposits, "Ally, trial stone and deposits follow the seed")
    _check(world.camp.state == CAMP.initial_state(expected.deposits), "Fresh camp has the seed's deposit amounts")
    _check(world.get_node("Decorations").get_child_count() == expected.rocks.size() + expected.trees.size() and world.layout.trees == expected.trees, "Trees and rocks are built (with collisions) from the seed")
    var saved: Dictionary = STORE.load_world(path)
    _check(saved.ok and saved.data.meta.seed == 777 and saved.data.meta.seeded == true, "Save stores the seed and that the world is seeded")
    # Harvest an outlying pile on the host so the reload restores progress, not a fresh layout.
    world.camp.state.founded = true
    world.camp.state.founder = "host"
    world.camp.harvest("wood_3")
    var moved: Node2D = world.entity_by_id("gnasher_2")
    moved.position += Vector2(10, 0)
    var moved_to: Vector2 = moved.position
    _check(session.save_world() == OK, "Seeded world with progress saves")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24620, path, false) == OK, "Seeded world reloads")
    # Checked before any physics frame: the creature's AI would start walking it home.
    _check(world.entity_by_id("gnasher_2").position == moved_to, "Reload keeps saved creature positions instead of re-placing them")
    await _frames()
    _check(world.layout == expected and world.camp.sites == expected.deposits and world.trial.stone == expected.stone, "Reload rebuilds the same layout from the saved seed")
    _check(world.camp.state.deposits.wood_3 == 0 and world.camp.state.wood == expected.deposits.wood_3.amount, "Reload keeps harvested deposits and stock")
    session.stop_session(false)
    # --- Validation against the seed's deposits, and migration of older worlds
    var data: Dictionary = STORE.load_world(path).data
    var richer := ""
    for id in LAYOUT.OUTLYING_IDS:
        if expected.deposits[id].amount != CAMP.DEPOSITS[id].amount and data.camp.deposits[id] != 0:
            richer = id
    if not richer.is_empty():
        var forged := data.duplicate(true)
        forged.camp.deposits[richer] = CAMP.DEPOSITS[richer].amount
        _check(not STORE.validate(forged), "Deposit amounts that do not match the seed are rejected")
    else:
        _check(true, "Seed 777 has no untouched richer pile to forge (skipped)")
    var unseeded := data.duplicate(true)
    unseeded.meta.erase("seeded")
    _check(not STORE.validate(unseeded), "v13 meta must say whether the world is seeded")
    var legacy := data.duplicate(true)
    legacy.version = 12
    legacy.meta.erase("seeded")
    legacy.camp = CAMP.initial_state()
    var migrated: Variant = STORE.migrate(legacy)
    _check(migrated is Dictionary and migrated.version == STORE.VERSION and migrated.meta.seeded == false and migrated.meta.seed == 777 and STORE.validate(migrated), "v12 worlds migrate to the original map and keep their seed")
    _check(LAYOUT.seed_of(migrated.meta) == 0, "Migrated worlds are laid out like they were saved")
    var listed: Array = REGISTRY.list(dir)
    _check(listed.size() == 1 and listed[0].map == "seed 777", "Save slot shows the seed")
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Seeded world checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
