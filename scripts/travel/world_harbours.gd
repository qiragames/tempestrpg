extends Node2D
## Harbours of one world (M4.5d, user decisions): ferry tickets (one trip to one harbour) and
## passes (unlimited trips for an hour of world time), your own ship (endgame, bought from a
## shipwright, summoned at any harbour, docked there for everyone to see) and its crew (owners
## invite characters standing near them; up to CREW_MAX characters sail together). Travel is by
## map: pick a harbour, the voyage plays, you arrive. Everything is decided on the host; clients
## name a harbour, a destination or a character. Invitations and crews are replicated (and saved,
## though they expire); tickets live in bags, passes and ships in each character's progression.
const TRAVEL := preload("res://scripts/travel/travel_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
const AUTHORITY := preload("res://scripts/network/authority.gd")
const HARBOUR_REACH := 56.0

var state: Dictionary = initial_state()
var world: Node
var _npcs: Dictionary = {}
var _ships: Dictionary = {}

static func initial_state() -> Dictionary:
    return {"invites": {}, "crews": {}}

func _ready() -> void:
    name = "Harbours"
    y_sort_enabled = true
    world = get_parent()
    for entry in MAP.HARBOURS:
        _npc("ferryman_" + entry[0], "ferryman", MAP.ferryman_position(entry[0]))
        if entry[4]:
            _npc("shipwright_" + entry[0], "shipwright", MAP.ferryman_position(entry[0]) + Vector2(0, 22))

func _npc(id: String, sprite: String, at: Vector2) -> void:
    var npc := Node2D.new()
    npc.name = id
    npc.position = at
    var body := SPRITES.make(sprite)
    npc.add_child(body)
    SPRITES.play(body, "idle_down")
    add_child(npc)
    _npcs[id] = npc

func session() -> Node:
    return get_node("/root/GameSession")

func world_time() -> float:
    return float(world.progression.get("world_time", 0.0)) if world != null else 0.0

static func ship_of(actor: Node) -> Dictionary:
    return actor.progression.get("ship", {"owned": false, "at": ""})

func owns_ship(actor: Node) -> bool:
    return bool(ship_of(actor).get("owned", false))

func has_pass(actor: Node) -> bool:
    return float(actor.progression.get("ferry_pass_until", 0.0)) > world_time()

## The harbour an actor stands at ("" if none): on its pier or beside its ferryman.
func nearest_harbour(actor: Node2D) -> String:
    for entry in MAP.HARBOURS:
        if actor.global_position.distance_to(MAP.dock_position(entry[0])) <= HARBOUR_REACH or actor.global_position.distance_to(MAP.ferryman_position(entry[0])) <= HARBOUR_REACH:
            return entry[0]
    return ""

func _ready_to_act(actor: Node2D, harbour: String) -> bool:
    return AUTHORITY.can_mutate(self) and not session().replica_world and actor.get_node("Health").current > 0 and not harbour.is_empty() and nearest_harbour(actor) == harbour

func _refuse(actor: Node2D, message: String) -> bool:
    session().notify_character(actor.character_id, message)
    return false

## Host: buy a single ticket from `here` to `destination` (a bag good).
func buy_ticket(actor: Node2D, here: String, destination: String) -> bool:
    if not _ready_to_act(actor, here) or MAP.harbour(destination).is_empty() or destination == here:
        return false
    var fare := TRAVEL.fare(here, destination)
    if actor.zeni() < fare:
        return _refuse(actor, "A ticket to %s costs %d Zeni." % [MAP.harbour(destination)[1], fare])
    if actor.get_node("Inventory").add_material(TRAVEL.ticket_id(destination), 1) != 1:
        return _refuse(actor, "No room in the bag for the ticket.")
    actor.spend_zeni(fare)
    session().notify_character(actor.character_id, "Bought a ferry ticket to %s (%d Zeni)." % [MAP.harbour(destination)[1], fare])
    session().queue_save()
    return true

## Host: buy (or extend) a ferry pass: unlimited trips for an hour of world time.
func buy_pass(actor: Node2D, here: String) -> bool:
    if not _ready_to_act(actor, here):
        return false
    if actor.zeni() < TRAVEL.PASS_PRICE:
        return _refuse(actor, "A ferry pass costs %d Zeni." % TRAVEL.PASS_PRICE)
    actor.spend_zeni(TRAVEL.PASS_PRICE)
    actor.progression["ferry_pass_until"] = maxf(world_time(), float(actor.progression.get("ferry_pass_until", 0.0))) + TRAVEL.PASS_SECONDS
    session().notify_character(actor.character_id, "Ferry pass: unlimited trips for the next hour (%d Zeni)." % TRAVEL.PASS_PRICE)
    session().queue_save()
    return true

## Host: buy your own ship from this harbour's shipwright (endgame, price only).
func buy_ship(actor: Node2D, here: String) -> bool:
    if not _ready_to_act(actor, here) or not MAP.harbour(here)[4]:
        return false
    if owns_ship(actor):
        return _refuse(actor, "You already own a ship.")
    if actor.zeni() < TRAVEL.SHIP_PRICE:
        return _refuse(actor, "A ship costs %d Zeni." % TRAVEL.SHIP_PRICE)
    actor.spend_zeni(TRAVEL.SHIP_PRICE)
    actor.progression["ship"] = {"owned": true, "at": here}
    session().notify_character(actor.character_id, "Your own ship! It lies at %s; summon it at any harbour, sail anywhere and take friends along." % MAP.harbour(here)[1])
    session().queue_save()
    return true

## Host: bring your ship to the harbour you stand at.
func summon(actor: Node2D, here: String) -> bool:
    if not _ready_to_act(actor, here) or not owns_ship(actor):
        return false
    actor.progression["ship"] = {"owned": true, "at": here}
    session().queue_save()
    return true

## Host: an owner whose ship lies here invites a character standing nearby aboard.
func invite(owner: Node2D, here: String, guest_id: String) -> bool:
    if not _ready_to_act(owner, here) or not owns_ship(owner) or ship_of(owner).at != here:
        return false
    var guest: Node = world.player_by_id(guest_id)
    if guest == null or guest == owner or guest.global_position.distance_to(owner.global_position) > TRAVEL.CREW_RADIUS:
        return _refuse(owner, "Invite characters standing next to you at the harbour.")
    if crew_of(owner.character_id).size() >= TRAVEL.CREW_MAX - 1:
        return _refuse(owner, "Your ship takes %d characters in all." % TRAVEL.CREW_MAX)
    state.invites[guest_id] = {"owner": owner.character_id, "until": world_time() + TRAVEL.INVITE_SECONDS}
    session().notify_character(guest_id, "%s invites you aboard their ship. Open the harbour (F) to accept." % owner.character_id)
    session().notify_character(owner.character_id, "Invited %s aboard." % guest_id)
    return true

## Host: accept the invitation you hold.
func accept(guest: Node2D) -> bool:
    var invite: Dictionary = state.invites.get(guest.character_id, {})
    if invite.is_empty() or float(invite.until) < world_time():
        return false
    var owner: Node = world.player_by_id(invite.owner)
    if owner == null or guest.global_position.distance_to(owner.global_position) > TRAVEL.CREW_RADIUS * 1.5 or crew_of(invite.owner).size() >= TRAVEL.CREW_MAX - 1:
        return _refuse(guest, "The ship cannot take you now.")
    state.invites.erase(guest.character_id)
    leave_crew(guest)
    state.crews[invite.owner] = crew_of(invite.owner) + [guest.character_id]
    session().notify_character(invite.owner, "%s is aboard." % guest.character_id)
    session().notify_character(guest.character_id, "You are aboard %s's ship; it sails when they choose a harbour." % invite.owner)
    return true

func leave_crew(actor: Node) -> void:
    for owner in state.crews.keys():
        state.crews[owner] = crew_of(owner).filter(func(id): return id != actor.character_id)
        if state.crews[owner].is_empty():
            state.crews.erase(owner)

func crew_of(owner_id: String) -> Array:
    return state.crews.get(owner_id, []).duplicate()

## Host: travel from the harbour you stand at to `destination` — on your own ship (with its crew),
## on a pass, or with a ticket for that harbour.
func sail(actor: Node2D, here: String, destination: String) -> bool:
    if not _ready_to_act(actor, here) or MAP.harbour(destination).is_empty() or destination == here:
        return false
    var voyagers: Array = [actor]
    if owns_ship(actor) and ship_of(actor).at == here:
        # M4.6: party members count as crew automatically.
        var party: Node = world.get("party")
        var aboard: Array = crew_of(actor.character_id)
        if party != null:
            for id in party.members(actor.character_id):
                if id != actor.character_id and not id in aboard:
                    aboard.append(id)
        for id in aboard.slice(0, TRAVEL.CREW_MAX - 1):
            var member: Node = world.player_by_id(id)
            if member != null and member.get_node("Health").current > 0 and member.global_position.distance_to(actor.global_position) <= TRAVEL.CREW_RADIUS * 1.5:
                voyagers.append(member)
        actor.progression["ship"] = {"owned": true, "at": destination}
    elif has_pass(actor):
        pass
    elif actor.get_node("Inventory").count_of(TRAVEL.ticket_id(destination)) > 0:
        actor.get_node("Inventory").discard(StringName(TRAVEL.ticket_id(destination)), 1)
    else:
        return _refuse(actor, "You need a ticket to %s, a ferry pass or your own ship." % MAP.harbour(destination)[1])
    for index in range(voyagers.size()):
        var voyager: Node2D = voyagers[index]
        voyager.global_position = MAP.dock_position(destination) + Vector2((index % 2) * 12 - 6, int(index / 2) * 10)
        voyager.velocity = Vector2.ZERO
        session().notify_character(voyager.character_id, "Sailed to %s." % MAP.harbour(destination)[1])
    if world.has_node("WorldTerrain"):
        world.get_node("WorldTerrain").ensure_props_at(MAP.dock_position(destination))
    session().queue_save()
    return true

func _process(_delta: float) -> void:
    if world != null and AUTHORITY.can_mutate(self) and not session().replica_world:
        var now := world_time()
        for id in state.invites.keys():
            if float(state.invites[id].until) < now:
                state.invites.erase(id)
    _sync_ships()

## Docked ships: one per owner present in the world, at its harbour's berth.
func _sync_ships() -> void:
    var wanted := {}
    var per_harbour := {}
    for actor in get_tree().get_nodes_in_group("player"):
        if actor.get_parent() != world or not owns_ship(actor) or ship_of(actor).get("at", "").is_empty():
            continue
        var at: String = ship_of(actor).at
        var index: int = per_harbour.get(at, 0)
        per_harbour[at] = index + 1
        wanted[actor.character_id] = MAP.berth_position(at) + Vector2(0, index * 30)
    for owner in _ships.keys():
        if not wanted.has(owner):
            _ships[owner].queue_free()
            _ships.erase(owner)
    for owner in wanted:
        if not _ships.has(owner):
            var ship := Node2D.new()
            ship.name = "Ship_" + owner
            var hull := Sprite2D.new()
            hull.texture = load("res://assets/game/world/boat.png")
            hull.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            hull.offset = Vector2(0, -16)
            ship.add_child(hull)
            var sail := Sprite2D.new()
            sail.texture = load("res://assets/game/world/sail.png")
            sail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            sail.offset = Vector2(4, -42)
            ship.add_child(sail)
            var label := Label.new()
            label.text = "%s's ship" % owner
            label.add_theme_font_size_override("font_size", 8)
            label.position = Vector2(-30, -70)
            ship.add_child(label)
            add_child(ship)
            _ships[owner] = ship
        _ships[owner].position = wanted[owner]

func capture() -> Dictionary:
    return state.duplicate(true)

func restore(value: Dictionary) -> void:
    state = value.duplicate(true)

static func valid_state(value: Variant) -> bool:
    if not value is Dictionary or value.size() != 2 or not value.get("invites") is Dictionary or not value.get("crews") is Dictionary:
        return false
    for id in value.invites:
        var entry: Variant = value.invites[id]
        if not entry is Dictionary or entry.size() != 2 or not entry.get("owner") is String or not (entry.get("until") is float or entry.get("until") is int):
            return false
    for owner in value.crews:
        var crew: Variant = value.crews[owner]
        if not crew is Array or crew.size() > TRAVEL.CREW_MAX - 1 or crew.any(func(id): return not id is String):
            return false
    return true

## Validation of a character's travel state (progression): ship and pass.
static func valid_progression(progression: Dictionary) -> bool:
    var ship: Variant = progression.get("ship")
    if not ship is Dictionary or ship.size() != 2 or not ship.get("owned") is bool or not ship.get("at") is String:
        return false
    if ship.owned and MAP.harbour(ship.at).is_empty():
        return false
    if not ship.owned and not ship.at.is_empty():
        return false
    var until: Variant = progression.get("ferry_pass_until")
    return (until is float or until is int) and is_finite(float(until)) and float(until) >= 0.0
