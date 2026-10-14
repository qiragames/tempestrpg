extends Node
## Parties (M4.6, user decisions): up to MAX_SIZE characters, invited from the party window; the
## leader removes members, anyone leaves. Party members get bonus XP for fighting together, split
## Zeni from kills evenly, see each other's HP/Magicules and map markers, sail together on an
## owner's ship, revive each other before the respawn, and make leveling spots respawn faster.
## No friendly fire (there never was any). Host-authoritative; state replicated and saved.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const MAX_SIZE := 4
const INVITE_SECONDS := 120.0
## "Nearby" for the XP bonus and the Zeni split: about two screens.
const NEAR := 640.0
const BONUS_PER_MEMBER := 0.1
const REVIVE_REACH := 32.0
const REVIVE_HP_SHARE := 0.35
## Leveling-spot respawns while two or more party members fight there.
const SPOT_PARTY_FACTOR := 0.5
const SPOT_PARTY_RADIUS := 220.0

var state: Dictionary = initial_state()
var world: Node

static func initial_state() -> Dictionary:
    return {"parties": {}, "invites": {}}

func _ready() -> void:
    name = "Party"
    world = get_parent()

func session() -> Node:
    return get_node("/root/GameSession")

func world_time() -> float:
    return float(world.progression.get("world_time", 0.0)) if world != null else 0.0

## The party a character belongs to ("" when none).
func party_of(character_id: String) -> String:
    for id in state.parties:
        if character_id in state.parties[id].members:
            return id
    return ""

## Fellow members (including the character itself) — just the character when in no party.
func members(character_id: String) -> Array:
    var party := party_of(character_id)
    return state.parties[party].members.duplicate() if not party.is_empty() else [character_id]

func same_party(a: String, b: String) -> bool:
    var party := party_of(a)
    return not party.is_empty() and party == party_of(b)

func leader(character_id: String) -> String:
    var party := party_of(character_id)
    return state.parties[party].leader if not party.is_empty() else ""

## Party members present, alive and within `radius` of a point.
func members_near(character_id: String, at: Vector2, radius: float = NEAR) -> Array:
    var found: Array = []
    for id in members(character_id):
        var actor: Node = world.player_by_id(id)
        if actor != null and actor.get_node("Health").current > 0 and actor.global_position.distance_to(at) <= radius:
            found.append(actor)
    return found

func _host() -> bool:
    return AUTHORITY.can_mutate(self) and not session().replica_world

func _tell(id: String, message: String) -> void:
    session().notify_character(id, message)

## Host: invite an online character into your party (creating it if needed).
func invite(actor: Node, guest_id: String) -> bool:
    if not _host() or guest_id == actor.character_id:
        return false
    var guest: Node = world.player_by_id(guest_id)
    if guest == null:
        return false
    if not party_of(guest_id).is_empty():
        _tell(actor.character_id, "%s is already in a party." % guest_id)
        return false
    if members(actor.character_id).size() >= MAX_SIZE:
        _tell(actor.character_id, "A party holds %d characters." % MAX_SIZE)
        return false
    if not party_of(actor.character_id).is_empty() and leader(actor.character_id) != actor.character_id:
        _tell(actor.character_id, "Only the party leader invites.")
        return false
    state.invites[guest_id] = {"from": actor.character_id, "until": world_time() + INVITE_SECONDS}
    _tell(guest_id, "%s invites you to their party (P to answer)." % actor.character_id)
    _tell(actor.character_id, "Invited %s to the party." % guest_id)
    return true

func accept(guest: Node) -> bool:
    var invite: Dictionary = state.invites.get(guest.character_id, {})
    if not _host() or invite.is_empty() or float(invite.until) < world_time():
        return false
    state.invites.erase(guest.character_id)
    if not party_of(guest.character_id).is_empty():
        return false
    var host_id: String = invite.from
    var party := party_of(host_id)
    if party.is_empty():
        party = "party_" + host_id
        state.parties[party] = {"leader": host_id, "members": [host_id]}
    if state.parties[party].members.size() >= MAX_SIZE:
        _tell(guest.character_id, "That party is full.")
        return false
    state.parties[party].members.append(guest.character_id)
    for id in state.parties[party].members:
        _tell(id, "%s joined the party." % guest.character_id)
    session().queue_save()
    return true

func decline(guest: Node) -> bool:
    if not _host() or not state.invites.has(guest.character_id):
        return false
    var from: String = state.invites[guest.character_id].from
    state.invites.erase(guest.character_id)
    _tell(from, "%s declined the invitation." % guest.character_id)
    return true

## Host: leave your party (the next member leads; a party of one dissolves).
func leave(actor: Node) -> bool:
    if not _host():
        return false
    return _remove(actor.character_id, "%s left the party.")

## Host: the leader removes a member.
func kick(actor: Node, member_id: String) -> bool:
    if not _host() or member_id == actor.character_id or leader(actor.character_id) != actor.character_id or not same_party(actor.character_id, member_id):
        return false
    _tell(member_id, "You were removed from the party.")
    return _remove(member_id, "%s was removed from the party.")

func _remove(member_id: String, message: String) -> bool:
    var party := party_of(member_id)
    if party.is_empty():
        return false
    var entry: Dictionary = state.parties[party]
    entry.members.erase(member_id)
    for id in entry.members:
        _tell(id, message % member_id)
    if entry.members.size() <= 1:
        state.parties.erase(party)
    elif entry.leader == member_id:
        entry.leader = entry.members[0]
    session().queue_save()
    return true

## Host: revive a defeated party member standing next to you, before their respawn.
func revive(actor: Node, target_id: String) -> bool:
    if not _host() or actor.get_node("Health").current <= 0 or not same_party(actor.character_id, target_id):
        return false
    var target: Node = world.player_by_id(target_id)
    if target == null or target.get_node("Health").current > 0 or target.death_left <= 0.0 or target.global_position.distance_to(actor.global_position) > REVIVE_REACH:
        return false
    var health: Node = target.get_node("Health")
    health.current = maxi(1, int(round(health.maximum * REVIVE_HP_SHARE)))
    health.immunity_left = 1.0
    health.changed.emit(health.current, health.maximum)
    target.death_left = 0.0
    target.get_node("Magicules").enabled = true
    for id in members(target_id):
        _tell(id, "%s revived %s." % [actor.character_id, target_id])
    session().queue_save()
    return true

## A defeated party member next to an actor ("" if none) — for F.
func revivable_near(actor: Node) -> String:
    for id in members(actor.character_id):
        var other: Node = world.player_by_id(id)
        if other != null and other != actor and other.get_node("Health").current <= 0 and other.death_left > 0.0 and other.global_position.distance_to(actor.global_position) <= REVIVE_REACH:
            return id
    return ""

## XP bonus for a character fighting near party members (+10% per other member nearby).
func xp_factor(character_id: String, at: Vector2) -> float:
    if party_of(character_id).is_empty():
        return 1.0
    return 1.0 + BONUS_PER_MEMBER * maxf(0.0, members_near(character_id, at).size() - 1)

## Leveling spots respawn faster while two or more members of one party fight there.
func spot_factor(at: Vector2) -> float:
    for id in state.parties:
        var near := 0
        for member in state.parties[id].members:
            var actor: Node = world.player_by_id(member)
            if actor != null and actor.get_node("Health").current > 0 and actor.global_position.distance_to(at) <= SPOT_PARTY_RADIUS:
                near += 1
        if near >= 2:
            return SPOT_PARTY_FACTOR
    return 1.0

func _process(_delta: float) -> void:
    if world == null or not _host():
        return
    var now := world_time()
    for id in state.invites.keys():
        if float(state.invites[id].until) < now:
            state.invites.erase(id)

func capture() -> Dictionary:
    return state.duplicate(true)

func restore(value: Dictionary) -> void:
    state = value.duplicate(true)

static func valid_state(value: Variant) -> bool:
    if not value is Dictionary or value.size() != 2 or not value.get("parties") is Dictionary or not value.get("invites") is Dictionary:
        return false
    var seen := {}
    for id in value.parties:
        var entry: Variant = value.parties[id]
        if not id is String or not entry is Dictionary or entry.size() != 2 or not entry.get("leader") is String or not entry.get("members") is Array:
            return false
        if entry.members.size() < 2 or entry.members.size() > MAX_SIZE or not entry.leader in entry.members:
            return false
        for member in entry.members:
            if not member is String or seen.has(member):
                return false
            seen[member] = true
    for id in value.invites:
        var invite: Variant = value.invites[id]
        if not invite is Dictionary or invite.size() != 2 or not invite.get("from") is String or not (invite.get("until") is float or invite.get("until") is int):
            return false
    return true
