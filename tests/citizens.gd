extends SceneTree
## M5b citizens, housing and food (user decisions): fields to plant and harvest (F), food in the
## nation's store, newcomers moving into free homes while there is food, daily meals, hunger and
## leaving, homes lost when a house is torn down, citizens walking about, the town's population
## requirement; saves (food books, homes), forgeries and the v27 -> v28 migration.
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

func _stock(rounds: int) -> void:
    for _round in range(rounds):
        for id in camp.sites:
            if camp.state.deposits[id] > 0:
                camp.harvest(id)
        camp._refill(camp.REFILL_SECONDS + 1.0)

func _spot(kind: String) -> Vector2i:
    var centre: Vector2i = MAP.to_tile(camp.SITE)
    for ring in range(2, 22):
        for dy in range(-ring, ring + 1):
            for dx in range(-ring, ring + 1):
                if maxi(absi(dx), absi(dy)) == ring and camp.place_problem(null, kind, centre + Vector2i(dx, dy)).is_empty():
                    return centre + Vector2i(dx, dy)
    return Vector2i(9999, 9999)

func _place(kind: String) -> String:
    var tile := _spot(kind)
    if tile.x == 9999 or not camp.place(null, kind, tile):
        return ""
    await _frames(1)
    return camp.state.nation.buildings[-1].id

func _document() -> Dictionary:
    var data: Dictionary = CODEC.capture_entities(world)
    data.merge({"version": STORE.VERSION, "world_id": "citizens", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    return data

func _run() -> void:
    session = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-citizens-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24740, dir.path_join("citizens.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    actor = world.get_local_player()
    camp = world.camp
    camp.state.founded = true
    camp.state.founder = "host"
    _stock(3)
    actor.global_position = camp.SITE + Vector2(0, 30)
    await _frames()
    var nation: Dictionary = camp.state.nation
    # --- Fields
    var field := await _place("field")
    _check(not field.is_empty() and world.get_node_or_null("Building_" + field) != null and world.get_node("Building_" + field).get_child_count() == 1, "A field placed (no collision: you can walk on it)")
    var entry: Dictionary = NATION.building(nation, field)
    var field_area := NATION.footprint("field", Vector2i(entry.tile[0], entry.tile[1]))
    actor.global_position = field_area.get_center()
    await _frames(1)
    _check(camp.nearest_field(actor) == field, "Standing on the field")
    _check(session.apply_action(actor, "camp", {"operation": "plant", "id": "%s:wheat" % field}) and camp.field_growth(field) == 0.0, "Wheat planted")
    _check(not session.apply_action(actor, "camp", {"operation": "plant", "id": "%s:carrot" % field}) and not session.apply_action(actor, "camp", {"operation": "plant", "id": "%s:gold" % field}), "One crop per field; unknown crops refused")
    _check(not session.apply_action(actor, "camp", {"operation": "harvest", "id": field}), "Not ripe yet")
    camp._tick_nation(NATION.CROPS.wheat[1])
    _check(camp.field_growth(field) == 1.0 and session.apply_action(actor, "camp", {"operation": "harvest", "id": field}) and camp.food() == NATION.CROPS.wheat[2] and int(nation.grown) == NATION.CROPS.wheat[2] and not nation.fields.has(field), "Ripe wheat harvested: 4 food in the store; the field is bare again")
    actor.global_position = camp.SITE + Vector2(0, 30)
    await _frames(1)
    _check(not camp.plant(actor, field, "wheat"), "You must stand at the field to plant")
    # --- Citizens
    _check(NATION.housing(nation, camp.state) == 0 and NATION.free_home(nation, camp.state).is_empty(), "No homes yet")
    camp.complete("hut_1")
    _check(NATION.housing(nation, camp.state) == NATION.CAMP_HUT_HOMES, "The Goblin Hut houses two")
    camp._tick_nation(NATION.ARRIVAL_SECONDS)
    _check(camp.population() == 1 and nation.citizens[0].home == NATION.CAMP_HUT, "A newcomer moved into the hut (there was food)")
    nation.food = 1
    nation.eaten = int(nation.grown) - 1
    camp._tick_nation(NATION.ARRIVAL_SECONDS)
    _check(camp.population() == 1, "No newcomer while the store cannot feed one more")
    nation.food = 40
    nation.grown = int(nation.eaten) + 40
    var house := await _place("house")
    for _i in range(4):
        camp._tick_nation(NATION.ARRIVAL_SECONDS)
    _check(camp.population() == 4 and NATION.free_home(nation, camp.state).is_empty(), "Homes fill up: the hut (2) and a house (2)")
    await _frames(3)
    _check(get_nodes_in_group("citizens").size() == 4, "Citizens walk around their homes")
    # --- Meals and hunger
    nation.day = 0.0
    var food_before: int = camp.food()
    camp._tick_nation(NATION.DAY_SECONDS)
    _check(camp.food() == food_before - 4 and int(nation.hunger) == 0, "A day: four citizens ate four food")
    nation.eaten = int(nation.eaten) + camp.food()
    nation.food = 0
    camp._tick_nation(NATION.DAY_SECONDS)
    _check(int(nation.hunger) == 1 and camp.population() == 4, "A hungry day")
    camp._tick_nation(NATION.DAY_SECONDS)
    _check(camp.population() == 3, "Two hungry days: someone left")
    # --- A house torn down
    nation.food = 30
    nation.grown = int(nation.eaten) + 30
    actor.global_position = camp.SITE + Vector2(0, 30)
    _check(session.apply_action(actor, "camp", {"operation": "demolish", "id": house}) and camp.population() == 2 and nation.citizens.all(func(citizen): return citizen.home == NATION.CAMP_HUT), "Without the house only the hut's two stay")
    await _frames(3)
    _check(get_nodes_in_group("citizens").filter(func(node): return not node.is_queued_for_deletion()).size() == 2, "…and only two walk about")
    # --- The town needs people
    var town: Dictionary = NATION.initial_state()
    town.tier = 1
    for index in range(10):
        town.buildings.append({"id": "b_%d" % (index + 1), "kind": ["town_hall", "watchtower", "house"][mini(index, 2)], "tile": [index * 5, 0]})
    town.citizens = [{"id": "c_1", "name": "A", "home": "b_3", "look": 0}]
    _check(NATION.tier_problem(town, {"wood": 999, "stone": 999, "essence": 99}).contains("6 citizens"), "A town needs six citizens")
    # --- Window
    var hud = world.get_node("HUD")
    hud.nation_panel.open()
    await _frames(1)
    _check(hud.nation_panel._tier.text.contains("Population 2 / 2") and hud.nation_panel._tier.text.contains("food 30"), "The nation window shows population, homes and food")
    hud.nation_panel.close_panel()
    # --- Saves
    var document := _document()
    _check(STORE.validate(document.duplicate(true)), "Citizens, fields and food save")
    var forgeries: Array = []
    var forged: Dictionary = document.duplicate(true)
    forged.camp.nation.food = 999
    forgeries.append(STORE.validate(forged))
    forged = document.duplicate(true)
    forged.camp.nation.citizens.append({"id": "c_1", "name": "Copy", "home": NATION.CAMP_HUT, "look": 0})
    forgeries.append(STORE.validate(forged))
    forged = document.duplicate(true)
    forged.camp.nation.citizens.append({"id": "c_%d" % int(nation.next_citizen), "name": "Ghost", "home": "b_404", "look": 0})
    forged.camp.nation.next_citizen = int(nation.next_citizen) + 1
    forgeries.append(STORE.validate(forged))
    forged = document.duplicate(true)
    forged.camp.nation.fields["b_404"] = {"crop": "wheat", "age": 0.0}
    forgeries.append(STORE.validate(forged))
    _check(not forgeries.has(true), "Invented food, doubled or homeless citizens and crops without a field are rejected")
    var old: Dictionary = document.duplicate(true)
    old.version = 27
    for key in ["citizens", "next_citizen", "fields", "food", "grown", "eaten", "day", "arrival", "hunger"]:
        old.camp.nation.erase(key)
    var migrated: Variant = STORE.migrate(old)
    _check(migrated is Dictionary and migrated.version == STORE.VERSION and migrated.camp.nation.citizens == [] and int(migrated.camp.nation.food) == 0 and STORE.validate(migrated), "v27 worlds: no citizens, fields or food yet")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Citizen checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
