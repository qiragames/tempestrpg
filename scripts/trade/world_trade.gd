extends Node2D
## Merchants and the travelling merchant of one world (M4.5c; harbours are WorldHarbours). The host owns the stock
## and every transaction: clients only name a merchant and an entry (or a dock); the host checks
## distance, availability, Zeni and bag room, then moves the goods. State (stock per merchant,
## the traveller's schedule) is saved with the world and replicated in snapshots, so every peer
## draws the same shopkeepers and shop windows.
const CATALOGUE := preload("res://scripts/trade/trade_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
const AUTHORITY := preload("res://scripts/network/authority.gd")
const TRAVEL := preload("res://scripts/travel/travel_catalogue.gd")
## Camp staff stand beside their structures (camp-local offsets).
const STAFF_OFFSET := Vector2(0, 22)

var state: Dictionary = initial_state()
var world: Node
## Shopkeeper bodies by merchant id (presentation, rebuilt from state).
var _npcs: Dictionary = {}

static func initial_state() -> Dictionary:
    return {"merchants": {}, "traveller": {"visit": 0, "spot": 0, "arrive": 1800.0, "leave": 1800.0 + CATALOGUE.TRAVELLER_STAY}}

func _ready() -> void:
    name = "Trade"
    y_sort_enabled = true
    world = get_parent()

func session() -> Node:
    return get_node("/root/GameSession")

func world_time() -> float:
    return float(world.progression.get("world_time", 0.0)) if world != null else 0.0

## Whether a merchant is open for business right now.
func available(id: String) -> bool:
    var entry := CATALOGUE.merchant(id)
    if entry.is_empty():
        return false
    match entry[3]:
        "town":
            return true
        "trader":
            return world.camp.state.get("stall", false) and world.camp.state.get("staff", {}).get("trader", false)
        "smith":
            return world.camp.state.get("smithy", false) and world.camp.state.get("staff", {}).get("smith", false)
        "traveller":
            var now := world_time()
            return now >= float(state.traveller.arrive) and now < float(state.traveller.leave)
    return false

func merchant_position(id: String) -> Vector2:
    var entry := CATALOGUE.merchant(id)
    match entry[3]:
        "town":
            return CATALOGUE.town_merchant_position(entry)
        "trader":
            return world.camp.STRUCTURES.stall_1.site + STAFF_OFFSET
        "smith":
            return world.camp.STRUCTURES.smithy_1.site + STAFF_OFFSET
    return MAP.to_world(CATALOGUE.TRAVELLER_SPOTS[int(state.traveller.spot) % CATALOGUE.TRAVELLER_SPOTS.size()])

## The open merchant within reach of an actor ("" if none).
func nearest_merchant(actor: Node2D) -> String:
    var best := ""
    var distance := CATALOGUE.REACH + 0.01
    for entry in CATALOGUE.MERCHANTS:
        if not available(entry[0]):
            continue
        var current: float = actor.global_position.distance_to(merchant_position(entry[0]))
        if current < distance:
            best = entry[0]
            distance = current
    return best

## Current stock of a merchant (host: restocked when its cycle changed).
func stock(id: String) -> Array:
    _restock(id)
    return state.merchants.get(id, {}).get("stock", [])

func _cycle(id: String) -> int:
    if CATALOGUE.merchant(id)[3] == "traveller":
        return int(state.traveller.visit)
    return int(floor(world_time() / CATALOGUE.RESTOCK_SECONDS))

func _restock(id: String) -> void:
    if not AUTHORITY.can_mutate(self) or session().replica_world:
        return
    var cycle := _cycle(id)
    var current: Dictionary = state.merchants.get(id, {})
    if not current.is_empty() and int(current.cycle) == cycle:
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = hash("%s:%d:%d" % [id, cycle, int(world.get("world_seed") if world.get("world_seed") != null else 0)])
    state.merchants[id] = {"cycle": cycle, "stock": CATALOGUE.roll_stock(CATALOGUE.merchant(id), rng)}

## Host: buy one unit of a stock entry.
func buy(actor: Node2D, merchant_id: String, entry_id: String) -> bool:
    if not _can_trade(actor, merchant_id):
        return false
    var goods: Array = stock(merchant_id)
    var index := -1
    for i in range(goods.size()):
        if goods[i].id == entry_id:
            index = i
    if index < 0 or int(goods[index].count) <= 0:
        return _refuse(actor, "Sold out.")
    var entry: Dictionary = goods[index]
    if actor.zeni() < int(entry.price):
        return _refuse(actor, "Not enough Zeni (%d needed)." % int(entry.price))
    match entry.kind:
        "gear":
            if actor.gear.items.size() >= actor.GEAR.MAX_ITEMS:
                return _refuse(actor, "Gear bag full.")
            actor.add_item(entry.item.duplicate(true))
        "tool":
            # M4.5d: tools are never equipped; owning one improves its work from now on.
            var tool: Array = TRAVEL.parse_tool(entry.id)
            if int(actor.progression.get("tools", {}).get(tool[0], 0)) >= tool[1]:
                return _refuse(actor, "You already own an equal or better %s." % TRAVEL.TOOLS[tool[0]][0].to_lower())
            actor.progression.tools[tool[0]] = tool[1]
        "mount":
            var mount: String = entry.id.trim_prefix("mount_")
            if mount in actor.progression.get("mounts", []):
                return _refuse(actor, "You already own that mount.")
            actor.progression.mounts.append(mount)
        _:
            if actor.get_node("Inventory").add_material(entry.id, 1) != 1:
                return _refuse(actor, "No room in the bag.")
    actor.spend_zeni(int(entry.price))
    entry.count = int(entry.count) - 1
    session().notify_character(actor.character_id, "Bought %s for %d Zeni." % [describe(entry), int(entry.price)])
    session().queue_save()
    return true

## Host: sell one bag good/material ("bag") or an unequipped gear item ("gear").
func sell(actor: Node2D, merchant_id: String, kind: String, item_id: String) -> bool:
    if not _can_trade(actor, merchant_id):
        return false
    var merchant_kind: String = CATALOGUE.merchant(merchant_id)[3]
    var level: int = CATALOGUE.merchant(merchant_id)[5]
    if kind == "gear":
        if merchant_kind == "trader":
            return _refuse(actor, "The trader buys goods and materials, not gear.")
        var item: Dictionary = actor.item_by_id(item_id)
        if item.is_empty() or item_id in actor.progression.get("equipment", {}).values():
            return _refuse(actor, "Only unequipped gear can be sold.")
        var value := CATALOGUE.sell_price(CATALOGUE.gear_price(item, level))
        if not actor.remove_item(item_id):
            return false
        actor.gain_zeni(value, "sale")
        session().notify_character(actor.character_id, "Sold %s for %d Zeni." % [actor.GEAR.display_name(item), value])
        session().queue_save()
        return true
    if kind != "bag" or merchant_kind == "smith":
        return _refuse(actor, "The smith only buys gear.")
    var price := CATALOGUE.price(item_id)
    if price <= 0 or not actor.get_node("Inventory").discard(StringName(item_id), 1):
        return false
    var value := CATALOGUE.sell_price(price)
    actor.gain_zeni(value, "sale")
    session().notify_character(actor.character_id, "Sold 1 %s for %d Zeni." % [item_id.replace("_", " "), value])
    session().queue_save()
    return true

func _can_trade(actor: Node2D, merchant_id: String) -> bool:
    if not AUTHORITY.can_mutate(self) or session().replica_world or actor.get_node("Health").current <= 0:
        return false
    if not available(merchant_id) or actor.global_position.distance_to(merchant_position(merchant_id)) > CATALOGUE.REACH + 8.0:
        return false
    return true

func _refuse(actor: Node2D, message: String) -> bool:
    session().notify_character(actor.character_id, message)
    return false

static func describe(entry: Dictionary) -> String:
    match entry.kind:
        "gear":
            return preload("res://scripts/items/gear_catalogue.gd").display_name(entry.item)
        "material":
            return entry.id.replace("_", " ").capitalize()
        "tool":
            var tool: Array = TRAVEL.parse_tool(entry.id)
            return "%s %s" % [TRAVEL.TOOL_TIERS[tool[1]], TRAVEL.TOOLS[tool[0]][0]]
        "mount":
            return "Mount: %s" % TRAVEL.MOUNTS[entry.id.trim_prefix("mount_")][0]
    return CATALOGUE.good_info(entry.id)[0]

## Host: the travelling merchant's schedule (arrives at a random roadside spot, leaves after a
## while, comes back somewhere else much later; never announced or marked).
func _process(_delta: float) -> void:
    if world == null or not AUTHORITY.can_mutate(self) or session().replica_world:
        _sync_npcs()
        return
    var now := world_time()
    if now >= float(state.traveller.leave):
        var rng := RandomNumberGenerator.new()
        var visit := int(state.traveller.visit) + 1
        rng.seed = hash("traveller:%d" % visit)
        var arrive: float = float(state.traveller.leave) + rng.randf_range(CATALOGUE.TRAVELLER_GAP[0], CATALOGUE.TRAVELLER_GAP[1])
        state.traveller = {"visit": visit, "spot": rng.randi_range(0, CATALOGUE.TRAVELLER_SPOTS.size() - 1), "arrive": arrive, "leave": arrive + CATALOGUE.TRAVELLER_STAY}
    # Open merchants restock when their cycle turns (the stock is replicated to every peer).
    for entry in CATALOGUE.MERCHANTS:
        if available(entry[0]):
            _restock(entry[0])
    _sync_npcs()

## Shopkeeper bodies: one per open merchant (the traveller only while present).
func _sync_npcs() -> void:
    for entry in CATALOGUE.MERCHANTS:
        var open := available(entry[0])
        var npc: Node2D = _npcs.get(entry[0])
        if open and not is_instance_valid(npc):
            npc = Node2D.new()
            npc.name = entry[0]
            npc.set_meta("merchant", entry[0])
            var body := SPRITES.make(entry[2])
            npc.add_child(body)
            SPRITES.play(body, "idle_down")
            add_child(npc)
            _npcs[entry[0]] = npc
        elif not open and is_instance_valid(npc):
            npc.queue_free()
            _npcs.erase(entry[0])
        if is_instance_valid(npc):
            npc.position = merchant_position(entry[0])

func capture() -> Dictionary:
    return state.duplicate(true)

func restore(value: Dictionary) -> void:
    state = value.duplicate(true)
    _sync_npcs()

static func valid_state(value: Variant) -> bool:
    if not value is Dictionary or value.size() != 2 or not value.get("merchants") is Dictionary or not value.get("traveller") is Dictionary:
        return false
    for id in value.merchants:
        var entry: Variant = value.merchants[id]
        if CATALOGUE.merchant(String(id)).is_empty() or not entry is Dictionary or entry.size() != 2:
            return false
        if not CATALOGUE._whole(entry.get("cycle"), 0, 100000000) or not CATALOGUE.valid_stock(entry.get("stock")):
            return false
    var traveller: Dictionary = value.traveller
    if traveller.size() != 4 or not CATALOGUE._whole(traveller.get("visit"), 0, 100000000) or not CATALOGUE._whole(traveller.get("spot"), 0, CATALOGUE.TRAVELLER_SPOTS.size() - 1):
        return false
    for key in ["arrive", "leave"]:
        if not (traveller.get(key) is float or traveller.get(key) is int) or not is_finite(float(traveller[key])) or float(traveller[key]) < 0.0:
            return false
    return float(traveller.leave) >= float(traveller.arrive)
