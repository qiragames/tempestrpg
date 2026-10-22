extends Node
## Trading between players (M11c, user request): two characters near each other open a trade, each
## puts gear (not worn), bag items and Zeni on their side, and when both say Ready the host swaps
## everything at once — after checking both still own it and both have room. Any change to an
## offer clears both Ready marks; walking apart, leaving or a reload ends the trade (nothing moves).
## Host-authoritative; the state reaches every peer with the snapshots and is never saved.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
## How close two characters must stand to start a trade, and how far apart ends it.
const START_REACH := 160.0
const END_REACH := 320.0
const REQUEST_SECONDS := 60.0
const MAX_LINES := 24

var state: Dictionary = initial_state()
var world: Node
var _next := 1

static func initial_state() -> Dictionary:
    return {"trades": {}, "requests": {}}

func _ready() -> void:
    name = "Exchange"
    world = get_parent()

func session() -> Node:
    return get_node("/root/GameSession")

func capture() -> Dictionary:
    return state.duplicate(true)

func restore(value: Dictionary) -> void:
    state = value.duplicate(true)

static func empty_offer() -> Dictionary:
    return {"gear": [], "goods": {}, "zeni": 0}

## The trade a character is in ("" for none).
func trade_of(id: String) -> String:
    for trade_id in state.trades:
        var trade: Dictionary = state.trades[trade_id]
        if trade.a == id or trade.b == id:
            return trade_id
    return ""

func partner(trade_id: String, id: String) -> String:
    var trade: Dictionary = state.trades.get(trade_id, {})
    return "" if trade.is_empty() else (trade.b if trade.a == id else trade.a)

func _actor(id: String) -> Node2D:
    return world.player_by_id(id) if world != null and world.has_method("player_by_id") else null

func _notify(id: String, message: String) -> void:
    session().notify_character(id, message)

## --- Host operations (the "exchange" intent).
func request(actor: Node2D, who: String) -> bool:
    var other := _actor(who)
    if not AUTHORITY.can_mutate(actor) or other == null or other == actor or not trade_of(actor.character_id).is_empty() or not trade_of(who).is_empty():
        return false
    if actor.global_position.distance_to(other.global_position) > START_REACH:
        _notify(actor.character_id, "Stand next to %s to trade." % who.left(16))
        return false
    state.requests[who] = {"from": actor.character_id, "until": _now() + REQUEST_SECONDS}
    _notify(who, "%s wants to trade with you (P: accept or decline)." % preload("res://scripts/progression/character_names.gd").display(actor.progression))
    _notify(actor.character_id, "Trade request sent.")
    return true

func accept(actor: Node2D) -> bool:
    var asked: Dictionary = state.requests.get(actor.character_id, {})
    if not AUTHORITY.can_mutate(actor) or asked.is_empty():
        return false
    state.requests.erase(actor.character_id)
    var other := _actor(String(asked.from))
    if other == null or float(asked.until) < _now() or not trade_of(other.character_id).is_empty() or not trade_of(actor.character_id).is_empty() or actor.global_position.distance_to(other.global_position) > START_REACH:
        _notify(actor.character_id, "That trade request is no longer open.")
        return false
    var trade_id := "trade_%d" % _next
    _next += 1
    state.trades[trade_id] = {"a": other.character_id, "b": actor.character_id, "offer": {other.character_id: empty_offer(), actor.character_id: empty_offer()}, "ready": {other.character_id: false, actor.character_id: false}}
    return true

func decline(actor: Node2D) -> bool:
    var asked: Dictionary = state.requests.get(actor.character_id, {})
    if not AUTHORITY.can_mutate(actor) or asked.is_empty():
        return false
    state.requests.erase(actor.character_id)
    _notify(String(asked.from), "%s declined the trade." % preload("res://scripts/progression/character_names.gd").display(actor.progression))
    return true

## Replace your side's offer: {"gear": [item ids], "goods": {id: count}, "zeni": amount}.
func offer(actor: Node2D, wanted: Dictionary) -> bool:
    var trade_id := trade_of(actor.character_id)
    if not AUTHORITY.can_mutate(actor) or trade_id.is_empty() or not valid_offer(actor, wanted):
        return false
    var trade: Dictionary = state.trades[trade_id]
    trade.offer[actor.character_id] = {"gear": wanted.gear.duplicate(), "goods": wanted.goods.duplicate(), "zeni": int(wanted.zeni)}
    for id in trade.ready:
        trade.ready[id] = false
    return true

## Whether a character can give this offer: owned, unworn gear; goods in the bag; enough Zeni.
static func valid_offer(actor: Node, wanted: Variant) -> bool:
    if not wanted is Dictionary or wanted.size() != 3 or not wanted.get("gear") is Array or not wanted.get("goods") is Dictionary or not (wanted.get("zeni") is int or wanted.get("zeni") is float):
        return false
    if wanted.gear.size() + wanted.goods.size() > MAX_LINES or int(wanted.zeni) < 0 or int(wanted.zeni) != float(wanted.zeni) or int(wanted.zeni) > int(actor.progression.get("zeni", 0)):
        return false
    var worn: Array = actor.progression.get("equipment", {}).values()
    var seen := {}
    for id in wanted.gear:
        if not id is String or seen.has(id) or actor.item_by_id(id).is_empty() or id in worn:
            return false
        seen[id] = true
    var bag: Node = actor.get_node("Inventory")
    for good in wanted.goods:
        var count: Variant = wanted.goods[good]
        if not good is String or not (count is int or count is float) or int(count) <= 0 or int(count) != float(count) or bag.count_of(good) < int(count):
            return false
    return true

func mark_ready(actor: Node2D, value: bool) -> bool:
    var trade_id := trade_of(actor.character_id)
    if not AUTHORITY.can_mutate(actor) or trade_id.is_empty():
        return false
    var trade: Dictionary = state.trades[trade_id]
    trade.ready[actor.character_id] = value
    if bool(trade.ready[trade.a]) and bool(trade.ready[trade.b]):
        _complete(trade_id)
    return true

func cancel(actor: Node2D) -> bool:
    var trade_id := trade_of(actor.character_id)
    if not AUTHORITY.can_mutate(actor) or trade_id.is_empty():
        return false
    _end(trade_id, "%s cancelled the trade." % preload("res://scripts/progression/character_names.gd").display(actor.progression))
    return true

func _end(trade_id: String, message: String) -> void:
    var trade: Dictionary = state.trades.get(trade_id, {})
    state.trades.erase(trade_id)
    for id in [trade.get("a", ""), trade.get("b", "")]:
        if not String(id).is_empty():
            _notify(id, message)

## Both ready: check again, then move everything at once (or nothing).
func _complete(trade_id: String) -> void:
    var trade: Dictionary = state.trades[trade_id]
    var a := _actor(trade.a)
    var b := _actor(trade.b)
    if a == null or b == null:
        _end(trade_id, "The trade ended: your partner is gone.")
        return
    var give_a: Dictionary = trade.offer[trade.a]
    var give_b: Dictionary = trade.offer[trade.b]
    if not valid_offer(a, give_a) or not valid_offer(b, give_b):
        _end(trade_id, "The trade failed: something offered is no longer there.")
        return
    if not _room(a, give_a, give_b) or not _room(b, give_b, give_a):
        for id in trade.ready:
            trade.ready[id] = false
        for actor in [a, b]:
            _notify(actor.character_id, "Not enough room in a bag or the gear stash for this trade.")
        return
    var items_a: Array = give_a.gear.map(func(id): return a.item_by_id(id).duplicate(true))
    var items_b: Array = give_b.gear.map(func(id): return b.item_by_id(id).duplicate(true))
    for item in items_a:
        a.remove_item(item.id)
    for item in items_b:
        b.remove_item(item.id)
    for item in items_a:
        b.add_item(item)
    for item in items_b:
        a.add_item(item)
    for good in give_a.goods:
        a.get_node("Inventory").discard(StringName(good), int(give_a.goods[good]))
        b.get_node("Inventory").add_material(good, int(give_a.goods[good]))
    for good in give_b.goods:
        b.get_node("Inventory").discard(StringName(good), int(give_b.goods[good]))
        a.get_node("Inventory").add_material(good, int(give_b.goods[good]))
    if int(give_a.zeni) > 0 and a.spend_zeni(int(give_a.zeni)):
        b.progression["zeni"] = mini(TRADE.MAX_ZENI, int(b.progression.get("zeni", 0)) + int(give_a.zeni))
    if int(give_b.zeni) > 0 and b.spend_zeni(int(give_b.zeni)):
        a.progression["zeni"] = mini(TRADE.MAX_ZENI, int(a.progression.get("zeni", 0)) + int(give_b.zeni))
    state.trades.erase(trade_id)
    for actor in [a, b]:
        _notify(actor.character_id, "Trade complete!")
    session().queue_save()

## Whether a character has room for what comes in after what goes out leaves.
func _room(actor: Node, giving: Dictionary, getting: Dictionary) -> bool:
    if actor.gear.items.size() - giving.gear.size() + getting.gear.size() > GEAR.MAX_ITEMS:
        return false
    var bag: Node = actor.get_node("Inventory")
    var units: int = bag.total_units()
    for good in giving.goods:
        units -= int(giving.goods[good])
    for good in getting.goods:
        units += int(getting.goods[good])
    return units <= bag.capacity and int(actor.progression.get("zeni", 0)) - int(giving.zeni) + int(getting.zeni) <= TRADE.MAX_ZENI

func _now() -> float:
    return float(world.progression.get("world_time", 0.0)) if world != null else 0.0

## Host: trades end when partners walk apart or leave; old requests expire.
func _process(_delta: float) -> void:
    if world == null or session().replica_world:
        return
    for trade_id in state.trades.keys():
        var trade: Dictionary = state.trades[trade_id]
        var a := _actor(trade.a)
        var b := _actor(trade.b)
        if a == null or b == null:
            _end(trade_id, "The trade ended: your partner left.")
        elif a.global_position.distance_to(b.global_position) > END_REACH:
            _end(trade_id, "The trade ended: you walked too far apart.")
    for who in state.requests.keys():
        if float(state.requests[who].until) < _now() or _actor(who) == null:
            state.requests.erase(who)
