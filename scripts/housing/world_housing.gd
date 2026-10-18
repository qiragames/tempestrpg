extends Node2D
## Housing (M16, user design 2026-10-18): every character can build their own house in the
## settlement ("Your House", build mode) and rent a room in a major city's inn. A house's door
## (F) leads into its interior; the owner furnishes it (F inside: buy and place furniture, take it
## away again) — some pieces help: a bed lets you rest (full HP and "Well rested": +10% XP for 20
## minutes), a trophy gives +3% Zeni from creatures, the wardrobe opens your settlement storage and
## the stove lets you cook. An inn room has a bed and room for FOUR decorations, and opens only in
## its city (at the town hall, like city storage). Friends may visit houses; only the owner
## furnishes. Interiors are rooms in an empty stretch of open sea (MAP.HOME_ZONE): while inside,
## a character collides only with the rooms' walls (layer 4). Host rules here (the "housing"
## intent); saved with the world (data.housing); drawn on every peer.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const STORAGE := preload("res://scripts/settlement/storage.gd")
const ART := "res://assets/game/housing/%s.png"
## Furniture: kind → [name, price, what it does ("" for decoration), allowed in an inn room].
const FURNITURE := {
    "bed": ["Bed", 400, "Rest here (F): full HP and Well rested (+10% XP for 20 min)", false],
    "bed_double": ["Double Bed", 900, "Rest here (F): full HP and Well rested (+10% XP for 20 min)", false],
    "table": ["Round Table", 150, "", false],
    "covered_table": ["Covered Table", 200, "", false],
    "long_table": ["Long Table", 250, "", false],
    "stool": ["Stool", 50, "", true],
    "bench": ["Bench", 100, "", false],
    "dresser": ["Dresser", 300, "", false],
    "wardrobe": ["Wardrobe", 500, "Opens your settlement storage (F)", false],
    "stove": ["Cooking Stove", 800, "Cook here as in a town", false],
    "plant_small": ["Small Plant", 40, "", true],
    "plant": ["Potted Plant", 60, "", true],
    "plant_tall": ["Tall Flowers", 80, "", true],
    "window": ["Curtained Window", 120, "", true],
    "chandelier": ["Chandelier", 350, "", true],
    "trophy_wolf": ["Wolf Trophy", 600, "+3% Zeni from creatures (one trophy counts)", true],
    "trophy_bear": ["Bear Trophy", 600, "+3% Zeni from creatures (one trophy counts)", true],
}
const HOUSE_SIZE := Vector2(224, 160)
const ROOM_SIZE := Vector2(144, 112)
const HOUSE_PIECES := 20
const ROOM_PIECES := 4
const SPACING := Vector2(300, 240)
const COLUMNS := 8
const DOOR_REACH := 24.0
const USE_REACH := 26.0
const ROOM_PRICE := 1500
const RESTED := [10.0, 1200.0]
const TROPHY_ZENI := 3
## Physics layer of the room walls (and the only thing characters inside collide with).
const WALL_LAYER := 8

var state: Dictionary = initial_state()
var world: Node
var _walls := {}
var _textures := {}
var _signature := ""

static func initial_state() -> Dictionary:
    return {"houses": {}, "rooms": {}, "next_house": 0, "next_room": 0}

func _ready() -> void:
    name = "Housing"
    world = get_parent()
    z_index = -1

func session() -> Node:
    return get_node("/root/GameSession")

func _host() -> bool:
    return AUTHORITY.can_mutate(self) and not session().replica_world

func _tell(id: String, message: String) -> void:
    session().notify_character(id, message)

## --- Geometry.
static func house_rect(slot: int) -> Rect2:
    var at := MAP.HOME_ZONE.position + Vector2(40 + (slot % COLUMNS) * SPACING.x, 40 + int(slot / COLUMNS) * SPACING.y)
    return Rect2(at, HOUSE_SIZE)

static func room_rect(slot: int) -> Rect2:
    var at := MAP.HOME_ZONE.position + Vector2(40 + (slot % COLUMNS) * SPACING.x, 40 + 2 * SPACING.y + int(slot / COLUMNS) * SPACING.y)
    return Rect2(at, ROOM_SIZE)

## The spot inside a room's door (bottom middle).
static func door_inside(rect: Rect2) -> Vector2:
    return Vector2(rect.get_center().x, rect.end.y - 14.0)

## --- Queries (every peer).
func house_of(character_id: String) -> Dictionary:
    return state.houses.get(character_id, {})

func room_of(character_id: String) -> Dictionary:
    return state.rooms.get(character_id, {})

func _building(id: String) -> Dictionary:
    var camp: Node = world.get("camp") if world != null else null
    if camp == null:
        return {}
    for entry in camp.state.nation.buildings:
        if entry.id == id:
            return entry
    return {}

## The front door of a character's house in the settlement (Vector2.INF when none).
func house_door(owner: String) -> Vector2:
    var building := _building(String(house_of(owner).get("building", "")))
    if building.is_empty():
        return Vector2.INF
    return NATION.foot(Vector2i(building.tile[0], building.tile[1])) + Vector2(0, 10)

## Whose interior a point is in: {"owner", "kind" ("house"/"room"), "rect"} or {}.
func interior_at(point: Vector2) -> Dictionary:
    if not MAP.HOME_ZONE.has_point(point):
        return {}
    for owner in state.houses:
        var rect := house_rect(int(state.houses[owner].slot))
        if rect.grow(4.0).has_point(point):
            return {"owner": owner, "kind": "house", "rect": rect}
    for owner in state.rooms:
        var rect := room_rect(int(state.rooms[owner].slot))
        if rect.grow(4.0).has_point(point):
            return {"owner": owner, "kind": "room", "rect": rect}
    return {}

## The placed pieces of an interior's owner ("house" or "room").
func pieces(owner: String, kind: String) -> Array:
    var entry: Dictionary = house_of(owner) if kind == "house" else room_of(owner)
    return entry.get("furniture", [])

## A piece of `kinds` within reach in the character's own interior (-1 when none).
func piece_near(actor: Node2D, kinds: Array) -> int:
    var inside := interior_at(actor.global_position)
    if inside.is_empty() or inside.owner != actor.character_id:
        return -1
    var list := pieces(inside.owner, inside.kind)
    for index in range(list.size()):
        if list[index].kind in kinds and actor.global_position.distance_to(Vector2(list[index].at[0], list[index].at[1])) <= USE_REACH:
            return index
    return -1

func has_trophy(character_id: String) -> bool:
    return pieces(character_id, "house").any(func(piece): return String(piece.kind).begins_with("trophy_")) or pieces(character_id, "room").any(func(piece): return String(piece.kind).begins_with("trophy_"))

## The title shown while inside ("" outside).
func title_for(viewer: String, point: Vector2) -> String:
    var inside := interior_at(point)
    if inside.is_empty():
        return ""
    if inside.kind == "room":
        return "INN ROOM · %s" % String(MAP.town(String(room_of(inside.owner).town))[1]).to_upper()
    return "YOUR HOUSE" if inside.owner == viewer else "%s'S HOUSE" % String(inside.owner).to_upper()

## --- Host operations.
## Why `actor` cannot build a house ("" when they can).
func build_problem(actor: Node) -> String:
    if actor == null:
        return "Only a character builds their own house."
    if not house_of(actor.character_id).is_empty():
        return "You have a house already."
    if int(state.next_house) >= COLUMNS * 2:
        return "No more houses fit this world."
    return ""

## A new "Your House" building was placed by `actor` (from FirstCamp.place).
func claim(actor: Node, building_id: String) -> void:
    if not _host() or actor == null:
        return
    state.houses[actor.character_id] = {"slot": int(state.next_house), "building": building_id, "furniture": []}
    state.next_house = int(state.next_house) + 1
    _tell(actor.character_id, "Your house stands! Its door (F) leads inside; F inside to furnish it.")
    session().queue_save()

func enter_house(actor: Node2D, owner: String) -> bool:
    if not _host() or house_of(owner).is_empty() or actor.global_position.distance_to(house_door(owner)) > DOOR_REACH:
        return false
    actor.global_position = door_inside(house_rect(int(house_of(owner).slot)))
    _set_inside(actor, true)
    return true

func rent_room(actor: Node2D, town_id: String) -> bool:
    if not _host() or not town_id in STORAGE.cities() or actor.global_position.distance_to(STORAGE.hall_position(town_id)) > STORAGE.REACH + 4.0:
        return false
    var current := room_of(actor.character_id)
    if not current.is_empty() and current.town == town_id:
        return false
    if not actor.spend_zeni(ROOM_PRICE):
        _tell(actor.character_id, "A room at the inn costs %d Zeni." % ROOM_PRICE)
        return false
    if current.is_empty() and int(state.next_room) >= COLUMNS * 2:
        _tell(actor.character_id, "The inns are full.")
        return false
    if current.is_empty():
        state.rooms[actor.character_id] = {"slot": int(state.next_room), "town": town_id, "furniture": []}
        state.next_room = int(state.next_room) + 1
    else:
        current.town = town_id
    _tell(actor.character_id, "Your inn room is in %s now (enter it at the town hall)." % MAP.town(town_id)[1])
    session().queue_save()
    return true

func enter_room(actor: Node2D) -> bool:
    var room := room_of(actor.character_id)
    if not _host() or room.is_empty() or actor.global_position.distance_to(STORAGE.hall_position(String(room.town))) > STORAGE.REACH + 4.0:
        return false
    actor.global_position = door_inside(room_rect(int(room.slot)))
    _set_inside(actor, true)
    return true

## Leave through the door: back in front of the house, or the inn's town hall.
func leave(actor: Node2D) -> bool:
    var inside := interior_at(actor.global_position)
    if not _host() or inside.is_empty() or actor.global_position.distance_to(door_inside(inside.rect)) > DOOR_REACH:
        return false
    var out: Vector2 = house_door(inside.owner) + Vector2(0, 6) if inside.kind == "house" else STORAGE.hall_position(String(room_of(inside.owner).town)) + Vector2(0, 10)
    if out == Vector2.INF:
        out = MAP.to_world(Vector2(MAP.to_tile(world.camp.SITE))) if world.get("camp") != null else Vector2.ZERO
    actor.global_position = out
    _set_inside(actor, false)
    if world.get("terrain") != null:
        world.terrain.ensure_props_at(out)
    return true

## Buy a piece and place it where the owner stands (in their own house or room).
func place(actor: Node2D, kind: String) -> bool:
    var inside := interior_at(actor.global_position)
    if not _host() or inside.is_empty() or inside.owner != actor.character_id or not FURNITURE.has(kind):
        return false
    var list := pieces(inside.owner, inside.kind)
    var room_kind: bool = inside.kind == "room"
    if room_kind and not bool(FURNITURE[kind][3]):
        _tell(actor.character_id, "That does not fit in an inn room (decorations only).")
        return false
    if list.size() >= (ROOM_PIECES if room_kind else HOUSE_PIECES):
        _tell(actor.character_id, "No room for more (%d pieces)." % (ROOM_PIECES if room_kind else HOUSE_PIECES))
        return false
    var at: Vector2 = (actor.global_position / 4.0).round() * 4.0
    if at.distance_to(door_inside(inside.rect)) < 20.0:
        _tell(actor.character_id, "Keep the door free.")
        return false
    if not actor.spend_zeni(int(FURNITURE[kind][1])):
        _tell(actor.character_id, "%s costs %d Zeni." % [FURNITURE[kind][0], int(FURNITURE[kind][1])])
        return false
    list.append({"kind": kind, "at": [at.x, at.y]})
    session().queue_save()
    return true

## Take a placed piece away again (its price comes back).
func remove(actor: Node2D, index: int) -> bool:
    var inside := interior_at(actor.global_position)
    if not _host() or inside.is_empty() or inside.owner != actor.character_id:
        return false
    var list := pieces(inside.owner, inside.kind)
    if index < 0 or index >= list.size():
        return false
    var kind: String = list[index].kind
    list.remove_at(index)
    actor.progression["zeni"] = int(actor.progression.get("zeni", 0)) + int(FURNITURE[kind][1])
    session().queue_save()
    return true

## Rest in your bed (an inn room always has one).
func rest(actor: Node2D) -> bool:
    if not _host():
        return false
    var inside := interior_at(actor.global_position)
    var in_inn: bool = not inside.is_empty() and inside.kind == "room" and inside.owner == actor.character_id and actor.global_position.distance_to(_inn_bed(inside.rect)) <= USE_REACH
    if piece_near(actor, ["bed", "bed_double"]) < 0 and not in_inn:
        return false
    var health: Node = actor.get_node("Health")
    health.current = health.maximum
    health.changed.emit(health.current, health.maximum)
    if not actor.elixirs.has("wisdom") or float(actor.elixirs.wisdom[0]) <= RESTED[0]:
        actor.elixirs["wisdom"] = [RESTED[0], maxf(RESTED[1], float(actor.elixirs.get("wisdom", [0.0, 0.0])[1]))]
    _tell(actor.character_id, "You rest. Well rested: +10% XP for 20 minutes.")
    return true

static func _inn_bed(rect: Rect2) -> Vector2:
    return rect.position + Vector2(24, 52)

## --- Every peer: walls, collisions inside, drawing.
func _set_inside(actor: Node, inside: bool) -> void:
    actor.collision_mask = WALL_LAYER if inside else 1

func _physics_process(_delta: float) -> void:
    if world == null:
        return
    for actor in get_tree().get_nodes_in_group("player"):
        if actor.get_parent() == world:
            var inside: bool = MAP.HOME_ZONE.has_point(actor.global_position)
            if (actor.collision_mask == WALL_LAYER) != inside:
                _set_inside(actor, inside)
    # Houses whose building was torn down are gone (with their furniture).
    if _host():
        for owner in state.houses.keys():
            if _building(String(state.houses[owner].building)).is_empty() and world.get("camp") != null and world.camp.state.founded:
                state.houses.erase(owner)
                _tell(owner, "Your house was torn down.")
    var signature := JSON.stringify([state.houses.keys().map(func(id): return state.houses[id].slot), state.rooms.keys().map(func(id): return state.rooms[id].slot)])
    if signature != _signature:
        _signature = signature
        _rebuild_walls()
    queue_redraw()

func _rebuild_walls() -> void:
    for key in _walls:
        if is_instance_valid(_walls[key]):
            _walls[key].queue_free()
    _walls.clear()
    var rects: Array = []
    for owner in state.houses:
        rects.append(house_rect(int(state.houses[owner].slot)))
    for owner in state.rooms:
        rects.append(room_rect(int(state.rooms[owner].slot)))
    for rect in rects:
        var body := StaticBody2D.new()
        body.collision_layer = WALL_LAYER
        body.collision_mask = 0
        # Top wall (deep, the wall face), sides and bottom.
        for box in [Rect2(rect.position, Vector2(rect.size.x, 40)), Rect2(rect.position, Vector2(6, rect.size.y)), Rect2(rect.position + Vector2(rect.size.x - 6, 0), Vector2(6, rect.size.y)), Rect2(rect.position + Vector2(0, rect.size.y - 6), Vector2(rect.size.x, 6))]:
            var shape := CollisionShape2D.new()
            var rectangle := RectangleShape2D.new()
            rectangle.size = box.size
            shape.shape = rectangle
            shape.position = box.get_center()
            body.add_child(shape)
        add_child(body)
        _walls[str(rect)] = body

func _texture(name: String) -> Texture2D:
    if not _textures.has(name):
        _textures[name] = load(ART % name)
    return _textures[name]

func _draw() -> void:
    var me: Node2D = world.get_local_player() if world != null and world.has_method("get_local_player") else null
    if me == null or not MAP.HOME_ZONE.grow(200.0).has_point(me.global_position):
        return
    # Darkness around the rooms (the sea is not visible from inside).
    draw_rect(Rect2(me.global_position - Vector2(700, 420), Vector2(1400, 840)), Color(0.05, 0.04, 0.06))
    for owner in state.houses:
        _draw_interior(house_rect(int(state.houses[owner].slot)), "floor_wood", state.houses[owner].furniture, false)
    for owner in state.rooms:
        _draw_interior(room_rect(int(state.rooms[owner].slot)), "floor_parquet", state.rooms[owner].furniture, true)

func _draw_interior(rect: Rect2, floor_tile: String, furniture: Array, inn: bool) -> void:
    if rect.get_center().distance_to(world.get_local_player().global_position) > 700.0:
        return
    var floor_texture := _texture(floor_tile)
    var x := rect.position.x
    while x < rect.end.x:
        var y := rect.position.y + 40.0
        while y < rect.end.y:
            draw_texture_rect_region(floor_texture, Rect2(Vector2(x, y), Vector2(minf(16.0, rect.end.x - x), minf(16.0, rect.end.y - y))), Rect2(Vector2.ZERO, Vector2(minf(16.0, rect.end.x - x), minf(16.0, rect.end.y - y))))
            y += 16.0
        x += 16.0
    var wall := _texture("wall_wood")
    x = rect.position.x
    while x < rect.end.x:
        var width := minf(16.0, rect.end.x - x)
        draw_texture_rect_region(wall, Rect2(Vector2(x, rect.position.y), Vector2(width, 40)), Rect2(Vector2.ZERO, Vector2(width, 40)))
        x += 16.0
    var frame := Color("2a1a12")
    draw_rect(Rect2(rect.position, Vector2(6, rect.size.y)), frame)
    draw_rect(Rect2(rect.position + Vector2(rect.size.x - 6, 0), Vector2(6, rect.size.y)), frame)
    draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 6), Vector2(rect.size.x, 6)), frame)
    draw_rect(rect, Color("140c08"), false, 2.0)
    # The door (a gap with a mat).
    var door := door_inside(rect)
    draw_rect(Rect2(door + Vector2(-12, 8), Vector2(24, 6)), Color("6b4a2b"))
    draw_rect(Rect2(door + Vector2(-10, 2), Vector2(20, 6)), Color("8a6440"))
    if inn:
        var bed := _texture("bed")
        draw_texture(bed, _inn_bed(rect) - bed.get_size() / 2.0)
    for piece in furniture:
        var texture := _texture(String(piece.kind))
        if texture != null:
            draw_texture(texture, Vector2(piece.at[0], piece.at[1]) - Vector2(texture.get_width() / 2.0, texture.get_height() - 4.0))

func capture() -> Dictionary:
    return state.duplicate(true)

func restore(value: Dictionary) -> void:
    if value.get("houses") is Dictionary:
        state = value.duplicate(true)

## Saves: houses and rooms of this world's characters, slots, furniture inside their rooms.
static func valid_state(value: Variant, players: Dictionary = {}) -> bool:
    if not value is Dictionary or value.size() != 4 or not value.get("houses") is Dictionary or not value.get("rooms") is Dictionary:
        return false
    for key in ["next_house", "next_room"]:
        if not (value.get(key) is int or value.get(key) is float) or int(value[key]) < 0 or int(value[key]) > COLUMNS * 2:
            return false
    var slots := {}
    for owner in value.houses:
        var house: Variant = value.houses[owner]
        if not owner is String or (not players.is_empty() and not players.has(owner)) or not house is Dictionary or house.size() != 3 or not house.get("building") is String:
            return false
        if not (house.get("slot") is int or house.get("slot") is float) or int(house.slot) < 0 or int(house.slot) >= int(value.next_house) or slots.has("h%d" % int(house.slot)):
            return false
        slots["h%d" % int(house.slot)] = true
        if not _valid_pieces(house.get("furniture"), house_rect(int(house.slot)), HOUSE_PIECES, false):
            return false
    for owner in value.rooms:
        var room: Variant = value.rooms[owner]
        if not owner is String or (not players.is_empty() and not players.has(owner)) or not room is Dictionary or room.size() != 3 or not room.get("town") in STORAGE.cities():
            return false
        if not (room.get("slot") is int or room.get("slot") is float) or int(room.slot) < 0 or int(room.slot) >= int(value.next_room) or slots.has("r%d" % int(room.slot)):
            return false
        slots["r%d" % int(room.slot)] = true
        if not _valid_pieces(room.get("furniture"), room_rect(int(room.slot)), ROOM_PIECES, true):
            return false
    return true

static func _valid_pieces(list: Variant, rect: Rect2, most: int, inn: bool) -> bool:
    if not list is Array or list.size() > most:
        return false
    for piece in list:
        if not piece is Dictionary or piece.size() != 2 or not FURNITURE.has(piece.get("kind")) or (inn and not bool(FURNITURE[piece.kind][3])):
            return false
        var at: Variant = piece.get("at")
        if not at is Array or at.size() != 2 or not rect.grow(4.0).has_point(Vector2(float(at[0]), float(at[1]))):
            return false
    return true
