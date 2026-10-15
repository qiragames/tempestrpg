extends SceneTree
## M5c citizen roles (user decisions): workers bring wood and stone, farmers tend three fields
## each, crafters at a workshop make trade goods, merchants at a market sell them into the
## treasury or lead a caravan to a town, guards at a watchtower shoot creatures in the
## settlement; jobs need room at their workplaces and fall idle when a workplace goes; the
## treasury pays out at the flag; saves (books), forgeries, the v28 -> v29 migration; the window.
const MAP := preload("res://scripts/world/world_map.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
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
        push_error("Could not place " + kind)
        return ""
    await _frames(1)
    return camp.state.nation.buildings[-1].id

func _job(index: int, job: String) -> bool:
    return session.apply_action(actor, "camp", {"operation": "job", "id": "%s:%s" % [camp.state.nation.citizens[index].id, job]})

func _document() -> Dictionary:
    var data: Dictionary = CODEC.capture_entities(world)
    data.merge({"version": STORE.VERSION, "world_id": "jobs", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    return data

func _run() -> void:
    session = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-jobs-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24750, dir.path_join("jobs.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    actor = world.get_local_player()
    camp = world.camp
    camp.state.founded = true
    camp.state.founder = "host"
    _stock(5)
    camp.state.essence = int(camp.state.essence) + 4
    camp.state.essence_offered = int(camp.state.essence_offered) + 4
    actor.global_position = camp.SITE + Vector2(0, 30)
    await _frames()
    var nation: Dictionary = camp.state.nation
    camp.complete("hut_1")
    camp.complete("storehouse_1")
    for kind in ["house", "house", "well", "banner"]:
        await _place(kind)
    _check(camp.rank_up(), "A village")
    for kind in ["big_house", "workshop", "market", "watchtower", "field", "field"]:
        await _place(kind)
    nation.food = 60
    nation.grown = int(nation.eaten) + 60
    for _i in range(10):
        camp._tick_nation(NATION.ARRIVAL_SECONDS)
    _check(camp.population() == 10 and nation.citizens.all(func(citizen): return citizen.job == ""), "Ten citizens, all idle")
    # --- Jobs and workplaces
    _check(_job(0, "worker") and _job(1, "worker"), "Two workers")
    _check(_job(2, "crafter") and _job(3, "crafter") and not _job(4, "crafter"), "A workshop holds two crafters")
    _check(_job(4, "merchant") and _job(5, "merchant"), "Two merchants at the market")
    _check(_job(6, "farmer") and _job(7, "guard"), "A farmer and a guard")
    _check(not session.apply_action(actor, "camp", {"operation": "job", "id": "c_1:king"}) and not session.apply_action(actor, "camp", {"operation": "job", "id": "c_999:worker"}), "Unknown jobs or citizens are refused")
    # --- A minute of work
    var wood: int = camp.state.wood
    var stone: int = camp.state.stone
    camp.state.nation.work = 0.0
    camp._tick_nation(NATION.WORK_SECONDS)
    _check(int(nation.produced.wood) == 1 and int(nation.produced.stone) == 1, "Workers brought 1 wood and 1 stone")
    _check(int(nation.crafted) == 2 and camp.state.wood == wood + 1 - 2 and camp.state.stone == stone + 1 - 2, "Crafters made 2 goods from 2 wood + 2 stone")
    _check(int(nation.sold) == 2 and int(nation.treasury) == 2 * NATION.GOOD_PRICE and int(nation.goods) == 0, "Merchants sold them: 60 Zeni in the treasury")
    _check(nation.fields.size() == 2 and nation.fields.values().all(func(plot): return plot.crop == NATION.FARMER_CROP), "The farmer planted carrots on both fields")
    var grown: int = int(nation.grown)
    camp._tick_nation(NATION.CROPS.carrot[1])
    _check(int(nation.grown) == grown + 2 * NATION.CROPS.carrot[2] and nation.fields.size() == 2 and nation.fields.values().all(func(plot): return plot.age < NATION.CROPS.carrot[1]), "…harvested them when ripe and planted again")
    # --- Caravan
    for citizen in nation.citizens:
        if citizen.job == "merchant":
            citizen.job = ""
    _job(4, "merchant")
    camp.state.nation.work = 0.0
    for _i in range(5):
        camp._tick_nation(NATION.WORK_SECONDS)
    var goods: int = int(nation.goods)
    _check(goods >= 5, "Goods piled up (%d)" % goods)
    var town: String = NATION.caravan_towns()[0][0]
    var terms: Array = NATION.caravan_terms(town, camp.SITE)
    var treasury: int = int(nation.treasury)
    _check(session.apply_action(actor, "camp", {"operation": "caravan", "id": "%s:5" % town}) and nation.caravan.to == town and int(nation.goods) == goods - 5 and nation.caravan.merchant == nation.citizens[4].id, "A caravan sets out with 5 goods, led by the merchant")
    _check(not session.apply_action(actor, "camp", {"operation": "caravan", "id": "%s:1" % town}) and not _job(4, "worker"), "One caravan at a time; its merchant keeps the job")
    camp.state.nation.work = 0.0
    camp._tick_nation(terms[0])
    _check(nation.caravan.to == "" and int(nation.treasury) >= treasury + 5 * int(terms[1]), "Back with %d Zeni per good" % terms[1])
    _check(not session.apply_action(actor, "camp", {"operation": "caravan", "id": "dome_city:1"}), "No caravans to the hidden realm")
    # --- Treasury
    var zeni: int = actor.zeni()
    var held: int = int(nation.treasury)
    _check(session.apply_action(actor, "camp", {"operation": "treasury", "id": "100"}) and actor.zeni() == zeni + 100 and int(nation.treasury) == held - 100, "Took 100 Zeni from the treasury at the flag")
    actor.global_position = camp.SITE + Vector2(400, 0)
    _check(not session.apply_action(actor, "camp", {"operation": "treasury", "id": "all"}), "…only at the flag")
    actor.global_position = camp.SITE + Vector2(0, 30)
    # --- Guards
    var tower: Dictionary = nation.buildings.filter(func(entry): return entry.kind == "watchtower")[0]
    var creature = GNASHER.instantiate()
    creature.entity_id = "jobs_gnasher"
    creature.position = NATION.foot(Vector2i(tower.tile[0], tower.tile[1])) + Vector2(30, 20)
    world.add_child(creature)
    world.wire_enemy(creature)
    creature.set_physics_process(false)
    await _frames(1)
    var hp: int = creature.get_node("Health").current
    for _i in range(3):
        camp._guard(NATION.GUARD_SECONDS)
    _check(creature.get_node("Health").current <= hp - 3 * NATION.GUARD_DAMAGE, "The guard shoots a creature inside the village")
    creature.queue_free()
    # --- Losing a workplace
    var workshop: String = nation.buildings.filter(func(entry): return entry.kind == "workshop")[0].id
    _check(session.apply_action(actor, "camp", {"operation": "demolish", "id": workshop}) and NATION.job_count(nation, "crafter") == 0, "Without the workshop the crafters fall idle")
    # --- Window
    var hud = world.get_node("HUD")
    hud.citizens_panel.open()
    await _frames(2)
    _check(hud.citizens_panel.is_open() and hud.citizens_panel._list.get_child_count() == camp.population() and hud.citizens_panel._summary.text.contains("Treasury"), "The citizens window lists everyone with their jobs, the treasury and goods")
    hud.citizens_panel.close_panel()
    # --- Saves
    var document := _document()
    _check(STORE.validate(document.duplicate(true)), "Jobs, goods, treasury and caravans save")
    var forgeries: Array = []
    var forged: Dictionary = document.duplicate(true)
    forged.camp.nation.treasury = int(forged.camp.nation.treasury) + 1000
    forgeries.append(STORE.validate(forged))
    forged = document.duplicate(true)
    forged.camp.nation.goods = int(forged.camp.nation.goods) + 5
    forgeries.append(STORE.validate(forged))
    forged = document.duplicate(true)
    for citizen in forged.camp.nation.citizens:
        citizen.job = "crafter"
    forgeries.append(STORE.validate(forged))
    forged = document.duplicate(true)
    forged.camp.nation.produced.wood = int(forged.camp.nation.produced.wood) + 10
    forgeries.append(STORE.validate(forged))
    _check(not forgeries.has(true), "Invented Zeni, goods, jobs without workplaces and unearned produce are rejected")
    var old: Dictionary = document.duplicate(true)
    old.version = 28
    for key in ["work", "produced", "goods", "crafted", "sold", "shipped", "treasury", "earned", "withdrawn", "caravan"]:
        old.camp.nation.erase(key)
    for citizen in old.camp.nation.citizens:
        citizen.erase("job")
    for resource in ["wood", "stone"]:
        old.camp[resource] = int(old.camp[resource]) - int(document.camp.nation.produced[resource])
    var migrated: Variant = STORE.migrate(old)
    _check(migrated is Dictionary and migrated.version == STORE.VERSION and migrated.camp.nation.citizens.all(func(citizen): return citizen.job == "") and int(migrated.camp.nation.treasury) == 0, "v28 worlds: idle citizens, no goods or treasury yet")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Job checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
