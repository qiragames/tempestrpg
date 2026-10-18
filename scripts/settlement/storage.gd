extends Node2D
## Storage (user request, after 1.0): two kinds of storage for bag items and gear.
##   Settlement storage: Vaults you place in your village (build mode). Each character has their
##     own compartment; every Vault adds room. Opened at any Vault — or at the town hall of any
##     major city.
##   City storage: bought once in a major city (at its town hall) and opened only in that city.
## Kept per character in progression.storage {"home": box, "city": {town id: box}} with a box
## {"gear": [items], "goods": {id: count}}; it belongs to its world (it does not travel with a
## character brought into a friend's world). Host-authoritative ("storage" intent); the boxes
## reach every peer with the character's progression.
const MAP := preload("res://scripts/world/world_map.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const AUTHORITY := preload("res://scripts/network/authority.gd")

## Room per Vault (units of bag items, pieces of gear) and in a city box.
const VAULT_UNITS := 150
const VAULT_GEAR := 20
const CITY_UNITS := 100
const CITY_GEAR := 15
const CITY_PRICE := 2500
const REACH := 34.0
const MAX_VAULTS := 6

var world: Node2D

func _init(owner_world: Node2D = null) -> void:
    world = owner_world
    name = "Storage"
    z_index = 4

func session() -> Node:
    return get_node("/root/GameSession")

static func empty_box() -> Dictionary:
    return {"gear": [], "goods": {}}

## Major cities (towns, not villages) — each has a town hall.
static func cities() -> Array:
    return MAP.TOWNS.filter(func(town): return town[4] == "town").map(func(town): return town[0])

## Where a city's town hall can be used (in front of its door).
static func hall_position(town_id: String) -> Vector2:
    var town: Array = MAP.town(town_id)
    return MAP.to_world(Vector2(town[3]) + Vector2(0, -6.5)) + Vector2(8, 22)

func vaults() -> Array:
    var camp: Node = world.get("camp") if world != null else null
    if camp == null or not camp.state.founded:
        return []
    return camp.state.nation.buildings.filter(func(entry): return entry.kind == "vault")

## Room in a character's settlement storage (by the Vaults standing) or a city box.
func room(where: String) -> Array:
    if where == "home":
        var count: int = vaults().size()
        return [VAULT_UNITS * count, VAULT_GEAR * count]
    return [CITY_UNITS, CITY_GEAR]

static func box(progression: Dictionary, where: String) -> Dictionary:
    var all: Variant = progression.get("storage")
    if not all is Dictionary:
        return {}
    if where == "home":
        return all.get("home", {}) if all.get("home") is Dictionary else {}
    var city: Variant = all.get("city", {})
    return city.get(where, {}) if city is Dictionary and city.get(where) is Dictionary else {}

static func owns_city(progression: Dictionary, town_id: String) -> bool:
    return not box(progression, town_id).is_empty()

static func units(stored: Dictionary) -> int:
    var total := 0
    for good in stored.get("goods", {}):
        total += int(stored.goods[good])
    return total

## Which storages a character can open where they stand: ["home"] and/or a city id.
func reachable(actor: Node2D) -> Array:
    var found: Array = []
    # M16: the wardrobe in your house opens your settlement storage.
    var housing: Node = world.get("housing") if world != null else null
    if housing != null and not vaults().is_empty() and housing.piece_near(actor, ["wardrobe"]) >= 0:
        found.append("home")
    for entry in vaults():
        if not "home" in found and actor.global_position.distance_to(NATION.foot(Vector2i(entry.tile[0], entry.tile[1]))) <= REACH + 10.0:
            found.append("home")
            break
    for town_id in cities():
        if actor.global_position.distance_to(hall_position(town_id)) <= REACH:
            if not "home" in found and not vaults().is_empty():
                found.append("home")
            found.append(town_id)
    return found

func _ensure(actor: Node, where: String) -> Dictionary:
    if not actor.progression.get("storage") is Dictionary:
        actor.progression["storage"] = {"home": empty_box(), "city": {}}
    var all: Dictionary = actor.progression.storage
    if where == "home":
        if not all.get("home") is Dictionary:
            all["home"] = empty_box()
        return all.home
    if not all.get("city") is Dictionary:
        all["city"] = {}
    return all.city.get(where, {})

## --- Host operations.
func buy(actor: Node2D, town_id: String) -> bool:
    if not AUTHORITY.can_mutate(actor) or not town_id in cities() or owns_city(actor.progression, town_id) or actor.global_position.distance_to(hall_position(town_id)) > REACH + 4.0:
        return false
    if not actor.spend_zeni(CITY_PRICE):
        session().notify_character(actor.character_id, "City storage in %s costs %d Zeni." % [MAP.town(town_id)[1], CITY_PRICE])
        return false
    _ensure(actor, "home")
    actor.progression.storage.city[town_id] = empty_box()
    session().notify_character(actor.character_id, "You rent storage in %s (only usable here)." % MAP.town(town_id)[1])
    session().queue_save()
    return true

## Put a gear piece (unworn) or `count` of a bag item into a storage you stand at.
func put(actor: Node2D, where: String, item: String, count: int) -> bool:
    if not AUTHORITY.can_mutate(actor) or not where in reachable(actor):
        return false
    if where != "home" and not owns_city(actor.progression, where):
        return false
    var stored := _ensure(actor, where)
    var space: Array = room(where)
    var piece: Dictionary = actor.item_by_id(item)
    if not piece.is_empty():
        if stored.gear.size() >= int(space[1]) or not actor.remove_item(item):
            session().notify_character(actor.character_id, "No room for more gear here." if stored.gear.size() >= int(space[1]) else "Take it off first.")
            return false
        stored.gear.append(piece)
    else:
        var bag: Node = actor.get_node("Inventory")
        count = mini(count, bag.count_of(item))
        count = mini(count, int(space[0]) - units(stored))
        if count <= 0 or not bag.discard(StringName(item), count):
            if units(stored) >= int(space[0]):
                session().notify_character(actor.character_id, "This storage is full.")
            return false
        stored.goods[item] = int(stored.goods.get(item, 0)) + count
    session().queue_save()
    return true

## Take a gear piece or `count` of a bag item back out.
func take(actor: Node2D, where: String, item: String, count: int) -> bool:
    if not AUTHORITY.can_mutate(actor) or not where in reachable(actor):
        return false
    var stored := box(actor.progression, where)
    if stored.is_empty():
        return false
    for index in range(stored.gear.size()):
        if stored.gear[index].id == item:
            if not actor.add_item(stored.gear[index]):
                session().notify_character(actor.character_id, "Your gear bag is full.")
                return false
            stored.gear.remove_at(index)
            session().queue_save()
            return true
    var have: int = int(stored.goods.get(item, 0))
    count = mini(count, have)
    if count <= 0:
        return false
    var added: int = actor.get_node("Inventory").add_material(item, count)
    if added <= 0:
        session().notify_character(actor.character_id, "Your bag is full.")
        return false
    if have - added <= 0:
        stored.goods.erase(item)
    else:
        stored.goods[item] = have - added
    session().queue_save()
    return true

## Saves: boxes of known shape, real goods, valid gear, cities that exist, within plain limits.
static func valid(progression: Dictionary) -> bool:
    if not progression.has("storage"):
        return true
    var all: Variant = progression.storage
    if not all is Dictionary or not all.get("home") is Dictionary or not all.get("city") is Dictionary or all.size() != 2:
        return false
    if not _valid_box(all.home, VAULT_UNITS * MAX_VAULTS, VAULT_GEAR * MAX_VAULTS):
        return false
    for town_id in all.city:
        if not town_id in cities() or not _valid_box(all.city[town_id], CITY_UNITS, CITY_GEAR):
            return false
    return true

static func _valid_box(stored: Variant, max_units: int, max_gear: int) -> bool:
    if not stored is Dictionary or stored.size() != 2 or not stored.get("gear") is Array or not stored.get("goods") is Dictionary:
        return false
    if stored.gear.size() > max_gear or not stored.gear.all(func(piece): return GEAR.valid_item(piece)):
        return false
    var total := 0
    for good in stored.goods:
        var count: Variant = stored.goods[good]
        if not good is String or not TRADE.bag_item(good) or not (count is int or count is float) or int(count) <= 0 or int(count) != float(count):
            return false
        total += int(count)
    return total <= max_units

## Every peer: a small storage sign at each major city's town hall.
func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var me: Node2D = world.get_local_player() if world != null and world.has_method("get_local_player") else null
    if me == null:
        return
    var font := ThemeDB.fallback_font
    for town_id in cities():
        var at := hall_position(town_id)
        if at.distance_to(me.global_position) > 500.0:
            continue
        # A little chest on a post: "Storage".
        draw_rect(Rect2(at + Vector2(-7, -8), Vector2(14, 9)), Color("6a4a2a"))
        draw_rect(Rect2(at + Vector2(-7, -8), Vector2(14, 3)), Color("8a6a40"))
        draw_rect(Rect2(at + Vector2(-1.5, -6), Vector2(3, 4)), Color("e0c060"))
        draw_string(font, at + Vector2(-20, -12), "Storage", HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(1, 0.92, 0.7, 0.95))
