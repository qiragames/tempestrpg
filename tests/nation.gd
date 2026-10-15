extends SceneTree
## M5a nation building (user decisions): buildings placed freely on the tile grid inside the
## settlement's ring (not on water, other buildings, deposits, trees or people), paid from the
## camp stock; camp → village → town with requirements and a growing ring; a named nation with a
## banner chosen by the founder; demolishing; saves (books stay balanced), forgeries and the
## v26 -> v27 migration; the nation window and the build mode.
const MAP := preload("res://scripts/world/world_map.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
var checks := 0
var failures := 0
var world: Node2D
var session: Node
var actor: CharacterBody2D
var camp: Node2D

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

## Fill the camp stock from the region deposits (they refill), keeping the books honest.
func _stock(rounds: int) -> void:
    for _round in range(rounds):
        for id in camp.sites:
            if camp.state.deposits[id] > 0:
                camp.harvest(id)
        camp._refill(camp.REFILL_SECONDS + 1.0)

## The nearest free tile for a building around the flag (searched in rings).
func _spot(kind: String) -> Vector2i:
    var centre: Vector2i = MAP.to_tile(camp.SITE)
    for ring in range(2, 22):
        for dy in range(-ring, ring + 1):
            for dx in range(-ring, ring + 1):
                if maxi(absi(dx), absi(dy)) != ring:
                    continue
                var tile := centre + Vector2i(dx, dy)
                if camp.place_problem(actor, kind, tile).is_empty():
                    return tile
    return Vector2i(9999, 9999)

func _place(kind: String) -> bool:
    var tile := _spot(kind)
    if tile.x == 9999:
        return false
    var placed: bool = session.apply_action(actor, "camp", {"operation": "place", "id": "%s@%d,%d" % [kind, tile.x, tile.y]})
    await _frames(1)
    return placed

func _document() -> Dictionary:
    var data: Dictionary = CODEC.capture_entities(world)
    data.merge({"version": STORE.VERSION, "world_id": "nation", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    return data

func _run() -> void:
    session = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-nation-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24730, dir.path_join("nation.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    actor = world.get_local_player()
    camp = world.camp
    actor.global_position = camp.SITE + Vector2(0, 30)
    await _frames()
    var near := MAP.to_tile(camp.SITE) + Vector2i(0, 5)
    _check(not camp.place_problem(actor, "house", near).is_empty() and not session.apply_action(actor, "camp", {"operation": "place", "id": "house@%d,%d" % [near.x, near.y]}), "Nothing is built before the camp is founded")
    camp.state.founded = true
    camp.state.founder = "host"
    _stock(3)
    await _frames()
    # --- Placing
    var wood: int = camp.state.wood
    _check(await _place("house") and camp.state.nation.buildings.size() == 1 and camp.state.wood == wood - 10 and int(camp.state.nation.spent.wood) == 10, "A house placed on a free tile (10 wood, 4 stone from the stock)")
    var first: Dictionary = camp.state.nation.buildings[0]
    var first_tile := Vector2i(first.tile[0], first.tile[1])
    var node: Node = world.get_node_or_null("Building_" + first.id)
    _check(node != null and node is StaticBody2D and node.position == NATION.foot(first_tile), "The house stands in the world with a collision box")
    _check(not camp.place_problem(actor, "well", first_tile).is_empty(), "No building on top of another")
    var far := MAP.to_tile(camp.SITE) + Vector2i(12, 0)
    _check(camp.place_problem(actor, "well", far).begins_with("Outside"), "A camp only builds inside its ring")
    _check(camp.place_problem(actor, "big_house", _spot("house")).contains("village"), "Large houses need a village")
    var deposit_tile := MAP.to_tile(camp.sites.wood_1.position)
    _check(not camp.place_problem(actor, "well", deposit_tile).is_empty(), "Deposits stay free")
    var water := Vector2i(-380, -240)
    _check(not camp.clear_problem(NATION.footprint("well", water)).is_empty(), "Not on water")
    actor.global_position = camp.SITE + Vector2(600, 0)
    _check(camp.place_problem(actor, "well", _spot("well")).is_empty() == false, "You must stand near where you build")
    actor.global_position = camp.SITE + Vector2(0, 30)
    var saved_stone: int = camp.state.stone
    var well_spot := _spot("well")
    camp.state.stone = 0
    _check(camp.place_problem(actor, "well", well_spot).contains("costs"), "The stock must pay for it")
    camp.state.stone = saved_stone
    _check(not session.apply_action(actor, "camp", {"operation": "place", "id": "house@abc"}) and not session.apply_action(actor, "camp", {"operation": "place", "id": "castle@1,1"}), "Malformed or unknown buildings are refused")
    # --- Village
    _check(NATION.tier_problem(camp.state.nation, camp.state).contains("Goblin Hut"), "A village needs the hut and storehouse")
    camp.complete("hut_1")
    camp.complete("storehouse_1")
    _check(await _place("house") and await _place("well"), "A second house and a well")
    _check(NATION.tier_problem(camp.state.nation, camp.state).contains("4 placed"), "A village needs four buildings")
    _check(await _place("banner"), "A banner placed")
    _check(NATION.tier_problem(camp.state.nation, camp.state).is_empty(), "Ready to become a village")
    actor.global_position = camp.SITE + Vector2(0, 30)
    await _frames()
    var before_wood: int = camp.state.wood
    _check(session.apply_action(actor, "camp", {"operation": "rank", "id": "next"}) and camp.tier() == 1 and camp.state.wood == before_wood - 30, "Ranked up: the camp is a village (30 wood, 20 stone)")
    _check(NATION.radius(1) > NATION.radius(0) and not camp.place_problem(null, "well", far).begins_with("Outside"), "A village builds further out")
    # Essence for the hall comes from offerings (kept in the books).
    camp.state.essence = int(camp.state.essence) + 4
    camp.state.essence_offered = int(camp.state.essence_offered) + 4
    _stock(2)
    _check(await _place("town_hall") and not (await _place("town_hall")), "One town hall per nation")
    # --- Demolish
    var count: int = camp.state.nation.buildings.size()
    var target: String = camp.state.nation.buildings.filter(func(entry): return entry.kind == "banner")[0].id
    var spent_wood: int = int(camp.state.nation.spent.wood)
    _check(session.apply_action(actor, "camp", {"operation": "demolish", "id": target}) and camp.state.nation.buildings.size() == count - 1 and int(camp.state.nation.spent.wood) == spent_wood, "Tearing down a building (its materials are lost)")
    await _frames(1)
    _check(world.get_node_or_null("Building_" + target) == null, "…and it is gone from the world")
    # --- Name and banner
    _check(session.apply_action(actor, "camp", {"operation": "name", "id": "  Tempest\u0007 Federation  "}) and camp.state.nation.name == "Tempest Federation", "The founder names the nation (cleaned)")
    _check(session.apply_action(actor, "camp", {"operation": "banner", "id": "1,3"}) and camp.state.nation.color == 1 and camp.state.nation.emblem == 3, "…and picks a blue banner with a flame")
    _check(not session.apply_action(actor, "camp", {"operation": "banner", "id": "99,0"}), "Unknown banner colours are refused")
    var friend = load("res://scenes/player/player.tscn").instantiate()
    friend.character_id = "friend"
    friend.local_controlled = false
    friend.position = actor.position + Vector2(10, 0)
    world.add_child(friend)
    await _frames(1)
    _check(not camp.transact(friend, "name", "Goblin Land") and camp.state.nation.name == "Tempest Federation", "Only the founder renames the nation")
    friend.queue_free()
    await _frames(1)
    var hud = world.get_node("HUD")
    actor.global_position = camp.SITE + Vector2(0, 30)
    await _frames(2)
    _check(hud.get_node("Title").text == "TEMPEST FEDERATION", "The HUD names your nation inside its ring")
    # --- Window and build mode
    hud.nation_panel.open()
    await _frames(1)
    _check(hud.nation_panel.is_open() and hud.menu_open() and hud.nation_panel._title.text.begins_with("TEMPEST FEDERATION"), "N opens the nation window")
    hud.nation_panel.start_mode("house")
    var spot := _spot("house")
    hud.nation_panel.aim(NATION.foot(spot) - Vector2(0, 4))
    var built: int = camp.state.nation.buildings.size()
    hud.nation_panel.confirm()
    await _frames(1)
    _check(camp.state.nation.buildings.size() == built + 1 and not hud.nation_panel.window().visible, "Build mode: a house where the mouse points")
    hud.nation_panel.stop_mode()
    _check(not hud.nation_panel.is_open(), "Right click / Esc leaves the build mode")
    # --- Saves
    var document := _document()
    _check(STORE.validate(document.duplicate(true)), "The nation saves and the camp's books balance")
    var forgeries: Array = []
    var forged: Dictionary = document.duplicate(true)
    forged.camp.nation.buildings.append({"id": "b_1", "kind": "house", "tile": [0, 0]})
    forgeries.append(STORE.validate(forged))
    forged = document.duplicate(true)
    forged.camp.nation.tier = 0
    forgeries.append(STORE.validate(forged))
    forged = document.duplicate(true)
    forged.camp.nation.spent.wood = 0
    forgeries.append(STORE.validate(forged))
    forged = document.duplicate(true)
    forged.camp.wood = int(forged.camp.wood) + 50
    forgeries.append(STORE.validate(forged))
    forged = document.duplicate(true)
    forged.camp.nation.name = "x".repeat(40)
    forgeries.append(STORE.validate(forged))
    _check(not forgeries.has(true), "Doubled buildings, buildings above the tier, unpaid buildings, extra stock and long names are rejected")
    var legacy: Dictionary = STORE.migrate(document.duplicate(true))
    var old: Dictionary = document.duplicate(true)
    old.version = 26
    for resource in NATION.RESOURCES:
        old.camp[resource] = int(old.camp[resource]) + int(old.camp.nation.spent[resource])
    old.camp.erase("nation")
    var migrated: Variant = STORE.migrate(old)
    _check(legacy is Dictionary and migrated is Dictionary and migrated.version == STORE.VERSION and migrated.camp.nation == NATION.initial_state() and STORE.validate(migrated), "v26 worlds: no nation yet")
    # Restoring rebuilds the buildings (as on a client).
    var state: Dictionary = camp.state.duplicate(true)
    camp.restore(state)
    await _frames(1)
    var standing := 0
    for entry in camp.state.nation.buildings:
        standing += 1 if world.get_node_or_null("Building_" + entry.id) != null else 0
    _check(standing == camp.state.nation.buildings.size(), "Restored nations stand again")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Nation checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
