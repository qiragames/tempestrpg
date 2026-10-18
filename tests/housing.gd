extends SceneTree
## Housing (M16): building your own house (one per character), going in and out through the door
## (inside, only the room's walls collide; no weather), furnishing it (price, room limit, the door
## stays free, taking pieces away returns the price), the bed (full HP, Well rested), the trophy
## (+3% Zeni), the stove (cook like in a town), visitors (enter, but not furnish), inn rooms in a
## major city (rent, enter at the town hall, decorations only, four at most), the title inside,
## saves and their checks.
const HOUSING := preload("res://scripts/housing/world_housing.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const STORAGE := preload("res://scripts/settlement/storage.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const DAY_NIGHT := preload("res://scripts/world/day_night.gd")
var world: Node2D
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

func _friend(id: String, at: Vector2) -> CharacterBody2D:
    var other = load("res://scenes/player/player.tscn").instantiate()
    other.character_id = id
    other.local_controlled = false
    other.position = at
    world.add_child(other)
    return other

func _run() -> void:
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-housing-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24836, dir.path_join("housing.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var housing: Node = world.housing
    var camp: Node = world.camp
    var camp_before: Dictionary = camp.state.duplicate(true)
    camp.state.founded = true
    camp.state.founder = "host"
    camp.state.wood = 200
    camp.state.stone = 200
    me.progression["zeni"] = 20000
    # Building the house.
    var centre: Vector2i = MAP.to_tile(camp.SITE)
    var tile := Vector2i(-9999, -9999)
    for ring in range(3, 9):
        if tile.x != -9999:
            break
        for dy in range(-ring, ring + 1):
            if tile.x != -9999:
                break
            for dx in range(-ring, ring + 1):
                var candidate := centre + Vector2i(dx, dy)
                me.global_position = NATION.foot(candidate) + Vector2(0, 12)
                if maxi(absi(dx), absi(dy)) == ring and camp.place_problem(me, "home", candidate).is_empty() and camp.place(me, "home", candidate):
                    tile = candidate
                    break
    _check(tile.x != -9999 and not housing.house_of("host").is_empty(), "Your House is built in the settlement")
    _check(not camp.place_problem(me, "home", centre + Vector2i(8, 8)).is_empty(), "...one per character")
    # In through the door.
    me.global_position = housing.house_door("host")
    _check(session.apply_action(me, "housing", {"operation": "enter", "id": "host"}) and MAP.HOME_ZONE.has_point(me.global_position), "In through the door")
    await _frames(2)
    _check(me.collision_mask == HOUSING.WALL_LAYER and MAP.region_name(me.global_position) == "Indoors" and DAY_NIGHT.weather(MAP.region_name(me.global_position), 0.0) == "clear", "Inside: only the walls collide, no weather")
    var rect: Rect2 = HOUSING.house_rect(int(housing.house_of("host").slot))
    var hud: CanvasLayer = world.get_node("HUD")
    await _frames(2)
    _check(hud.get_node("Title").text == "YOUR HOUSE", "The title says YOUR HOUSE")
    # Furnishing.
    _check(not session.apply_action(me, "housing", {"operation": "place", "id": "bed"}), "The door stays free")
    me.global_position = rect.position + Vector2(40, 70)
    var zeni: int = int(me.progression.zeni)
    _check(session.apply_action(me, "housing", {"operation": "place", "id": "bed"}) and int(me.progression.zeni) == zeni - int(HOUSING.FURNITURE.bed[1]) and housing.pieces("host", "house").size() == 1, "A bed bought and placed")
    me.get_node("Health").current = 5
    _check(session.apply_action(me, "housing", {"operation": "rest"}) and me.get_node("Health").current == me.get_node("Health").maximum and me.elixir("wisdom") >= 10.0, "Resting: full HP and Well rested")
    me.global_position = rect.position + Vector2(120, 70)
    _check(housing.place(me, "stove") and me.craft_station("cooking") == "town", "The stove cooks like a town")
    me.global_position = rect.position + Vector2(170, 60)
    _check(housing.place(me, "trophy_wolf") and housing.has_trophy("host"), "A wolf trophy on the wall")
    var before: int = int(me.progression.zeni)
    me.gain_zeni(100, "defeat")
    _check(int(me.progression.zeni) - before == 103, "The trophy: +3% Zeni from creatures")
    zeni = int(me.progression.zeni)
    _check(session.apply_action(me, "housing", {"operation": "remove", "id": "2"}) and int(me.progression.zeni) == zeni + int(HOUSING.FURNITURE.trophy_wolf[1]) and housing.pieces("host", "house").size() == 2, "Taking a piece away returns its price")
    # A visitor.
    var ann := _friend("ann", housing.house_door("host"))
    await _frames(1)
    _check(housing.enter_house(ann, "host") and not housing.place(ann, "plant"), "Friends visit, but do not furnish")
    ann.global_position = HOUSING.door_inside(rect)
    _check(housing.leave(ann) and not MAP.HOME_ZONE.has_point(ann.global_position), "...and leave through the door")
    # Out again.
    me.global_position = HOUSING.door_inside(rect)
    _check(session.apply_action(me, "housing", {"operation": "leave"}) and me.global_position.distance_to(housing.house_door("host")) < 20.0, "Out through the door, in front of the house")
    await _frames(2)
    _check(me.collision_mask == 1, "Outside, the world collides again")
    # An inn room.
    me.global_position = STORAGE.hall_position("brookhaven")
    zeni = int(me.progression.zeni)
    _check(session.apply_action(me, "housing", {"operation": "rent", "id": "brookhaven"}) and int(me.progression.zeni) == zeni - HOUSING.ROOM_PRICE, "An inn room rented in Brookhaven")
    _check(session.apply_action(me, "housing", {"operation": "enter_room"}) and housing.interior_at(me.global_position).get("kind", "") == "room", "Up to the inn room")
    var room: Rect2 = HOUSING.room_rect(int(housing.room_of("host").slot))
    me.global_position = room.position + Vector2(90, 60)
    _check(not housing.place(me, "bed"), "Inn rooms take decorations only")
    var placed := 0
    for kind in ["plant", "plant_small", "window", "chandelier", "plant_tall"]:
        if housing.place(me, kind):
            placed += 1
    _check(placed == HOUSING.ROOM_PIECES, "Four decorations at most")
    me.global_position = HOUSING._inn_bed(room)
    me.get_node("Health").current = 3
    _check(housing.rest(me) and me.get_node("Health").current == me.get_node("Health").maximum, "The inn's bed")
    me.global_position = HOUSING.door_inside(room)
    _check(housing.leave(me) and me.global_position.distance_to(STORAGE.hall_position("brookhaven")) < 20.0, "Back at the town hall")
    # Saves (the camp was founded by hand: its real state comes back first).
    camp.state = camp_before
    ann.queue_free()
    await _frames(1)
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("housing.json")))
    _check(raw.housing.houses.has("host") and raw.housing.houses.host.furniture.size() == 2 and raw.housing.rooms.host.furniture.size() == 4 and STORE.validate(raw), "The house and the room are saved")
    var bad: Dictionary = raw.duplicate(true)
    bad.housing.houses.host.furniture[0].at = [0.0, 0.0]
    _check(not STORE.validate(bad), "Furniture outside its room is rejected")
    var old: Dictionary = raw.duplicate(true)
    old.erase("housing")
    old.version = 40
    var migrated: Variant = STORE.migrate(old)
    _check(migrated is Dictionary and migrated.housing.houses.is_empty() and int(migrated.version) == STORE.VERSION, "v40 worlds start without houses")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Housing checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
