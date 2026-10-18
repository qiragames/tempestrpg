extends Node2D
## Guilds (M14a, user design 2026-10-18): several guilds can live in one world (saved with it). A
## guild has a name, a short tag shown above its members' heads, an emblem and ranks — the leader,
## officers and members. Founding costs Zeni; the leader and officers invite characters online in
## this world; the leader promotes, demotes, hands over the lead or disbands; officers remove
## members, the leader anyone. Bank, level, perks, weekly quests and the guild hall follow in M14b
## (their fields exist already). Host rules here (the "guild" intent); drawn on every peer.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const ACH := preload("res://scripts/progression/achievements.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const FOUND_PRICE := 1000
const MAX_MEMBERS := 20
const INVITE_SECONDS := 120.0
const NAME_MIN := 3
const NAME_MAX := 20
const TAG_MIN := 2
const TAG_MAX := 4
const BANK_SLOTS := 40
const RANKS := ["leader", "officer", "member"]

var state: Dictionary = initial_state()
var world: Node

static func initial_state() -> Dictionary:
    return {"guilds": {}, "invites": {}, "next": 1}

## A fresh guild record.
static func new_guild(name: String, tag: String, emblem: int, leader: String, now: float) -> Dictionary:
    return {"name": name, "tag": tag, "emblem": emblem, "leader": leader, "officers": [], "members": [leader], "bank": {"items": [], "goods": {}, "zeni": 0}, "withdraw": "officers", "xp": 0, "quests": {}, "founded": now}

func _ready() -> void:
    name = "Guilds"
    world = get_parent()
    z_index = 6

func session() -> Node:
    return get_node("/root/GameSession")

func world_time() -> float:
    return float(world.progression.get("world_time", 0.0)) if world != null and world.get("progression") is Dictionary else 0.0

## --- Queries (every peer).
func guild_of(character_id: String) -> String:
    for id in state.guilds:
        if character_id in state.guilds[id].members:
            return id
    return ""

func guild(id: String) -> Dictionary:
    return state.guilds.get(id, {})

func rank_of(character_id: String) -> String:
    var id := guild_of(character_id)
    if id.is_empty():
        return ""
    var entry: Dictionary = state.guilds[id]
    return "leader" if entry.leader == character_id else ("officer" if character_id in entry.officers else "member")

func tag_of(character_id: String) -> String:
    var id := guild_of(character_id)
    return String(state.guilds[id].tag) if not id.is_empty() else ""

func same_guild(a: String, b: String) -> bool:
    var id := guild_of(a)
    return not id.is_empty() and id == guild_of(b)

## Names and tags must be unique in the world (ignoring case).
func name_taken(text: String) -> bool:
    for id in state.guilds:
        if String(state.guilds[id].name).to_lower() == text.to_lower() or String(state.guilds[id].tag).to_lower() == text.to_lower():
            return true
    return false

static func valid_name(text: String) -> bool:
    if text.length() < NAME_MIN or text.length() > NAME_MAX or text != text.strip_edges():
        return false
    var pattern := RegEx.create_from_string("^[A-Za-z0-9' -]+$")
    return pattern.search(text) != null

static func valid_tag(text: String) -> bool:
    var pattern := RegEx.create_from_string("^[A-Z0-9]{%d,%d}$" % [TAG_MIN, TAG_MAX])
    return pattern.search(text) != null

## --- Host operations.
func _host() -> bool:
    return AUTHORITY.can_mutate(self) and not session().replica_world

func _tell(id: String, message: String) -> void:
    session().notify_character(id, message)

func _tell_guild(guild_id: String, message: String) -> void:
    for member in state.guilds[guild_id].members:
        _tell(member, message)

func found(actor: Node, guild_name: String, tag: String, emblem: int) -> bool:
    if not _host() or not guild_of(actor.character_id).is_empty():
        return false
    if not valid_name(guild_name) or not valid_tag(tag) or emblem < 0 or emblem >= NATION.EMBLEMS.size():
        _tell(actor.character_id, "A guild needs a name (%d-%d letters) and a tag (%d-%d capitals or digits)." % [NAME_MIN, NAME_MAX, TAG_MIN, TAG_MAX])
        return false
    if name_taken(guild_name) or name_taken(tag):
        _tell(actor.character_id, "That name or tag is taken in this world.")
        return false
    if not actor.spend_zeni(FOUND_PRICE):
        _tell(actor.character_id, "Founding a guild costs %d Zeni." % FOUND_PRICE)
        return false
    var id := "guild_%d" % int(state.next)
    state.next = int(state.next) + 1
    state.guilds[id] = new_guild(guild_name, tag, emblem, actor.character_id, world_time())
    state.invites.erase(actor.character_id)
    _tell(actor.character_id, "You founded the guild %s <%s>." % [guild_name, tag])
    session().queue_save()
    return true

func invite(actor: Node, guest_id: String) -> bool:
    var id := guild_of(actor.character_id)
    if not _host() or id.is_empty() or guest_id == actor.character_id or not rank_of(actor.character_id) in ["leader", "officer"]:
        return false
    if world.player_by_id(guest_id) == null:
        return false
    if not guild_of(guest_id).is_empty():
        _tell(actor.character_id, "%s is already in a guild." % guest_id)
        return false
    if state.guilds[id].members.size() >= MAX_MEMBERS:
        _tell(actor.character_id, "A guild holds %d characters." % MAX_MEMBERS)
        return false
    state.invites[guest_id] = {"guild": id, "from": actor.character_id, "until": world_time() + INVITE_SECONDS}
    _tell(guest_id, "%s invites you to the guild %s <%s> (P → Guild to answer)." % [actor.character_id, state.guilds[id].name, state.guilds[id].tag])
    _tell(actor.character_id, "Invited %s to the guild." % guest_id)
    return true

func accept(guest: Node) -> bool:
    var invite: Dictionary = state.invites.get(guest.character_id, {})
    if not _host() or invite.is_empty() or float(invite.until) < world_time():
        return false
    state.invites.erase(guest.character_id)
    var id: String = invite.guild
    if not state.guilds.has(id) or not guild_of(guest.character_id).is_empty():
        return false
    if state.guilds[id].members.size() >= MAX_MEMBERS:
        _tell(guest.character_id, "That guild is full.")
        return false
    state.guilds[id].members.append(guest.character_id)
    _tell_guild(id, "%s joined the guild." % guest.character_id)
    session().queue_save()
    return true

func decline(guest: Node) -> bool:
    if not _host() or not state.invites.has(guest.character_id):
        return false
    var from: String = state.invites[guest.character_id].from
    state.invites.erase(guest.character_id)
    _tell(from, "%s declined the guild invitation." % guest.character_id)
    return true

## Leave (a leader hands the lead to an officer, else the longest member; alone, the guild ends).
func leave(actor: Node) -> bool:
    if not _host() or guild_of(actor.character_id).is_empty():
        return false
    return _remove(actor.character_id, "%s left the guild.")

func kick(actor: Node, member_id: String) -> bool:
    var rank := rank_of(actor.character_id)
    if not _host() or member_id == actor.character_id or not same_guild(actor.character_id, member_id):
        return false
    var target := rank_of(member_id)
    if not (rank == "leader" or (rank == "officer" and target == "member")):
        _tell(actor.character_id, "Officers remove members; the leader anyone.")
        return false
    _tell(member_id, "You were removed from the guild.")
    return _remove(member_id, "%s was removed from the guild.")

func _remove(member_id: String, message: String) -> bool:
    var id := guild_of(member_id)
    var entry: Dictionary = state.guilds[id]
    entry.members.erase(member_id)
    entry.officers.erase(member_id)
    if entry.members.is_empty():
        state.guilds.erase(id)
        _tell(member_id, "The guild %s is no more." % entry.name)
        session().queue_save()
        return true
    if entry.leader == member_id:
        entry.leader = entry.officers[0] if not entry.officers.is_empty() else entry.members[0]
        entry.officers.erase(entry.leader)
        _tell_guild(id, "%s leads the guild now." % entry.leader)
    _tell(member_id, message % member_id)
    _tell_guild(id, message % member_id)
    session().queue_save()
    return true

## The leader makes a member an officer (promote) or an officer a member again (demote).
func set_rank(actor: Node, member_id: String, officer: bool) -> bool:
    if not _host() or rank_of(actor.character_id) != "leader" or member_id == actor.character_id or not same_guild(actor.character_id, member_id):
        return false
    var entry: Dictionary = state.guilds[guild_of(member_id)]
    if officer == (member_id in entry.officers):
        return false
    if officer:
        entry.officers.append(member_id)
    else:
        entry.officers.erase(member_id)
    _tell_guild(guild_of(member_id), "%s is %s now." % [member_id, "an officer" if officer else "a member"])
    session().queue_save()
    return true

func transfer(actor: Node, member_id: String) -> bool:
    if not _host() or rank_of(actor.character_id) != "leader" or member_id == actor.character_id or not same_guild(actor.character_id, member_id):
        return false
    var entry: Dictionary = state.guilds[guild_of(member_id)]
    entry.leader = member_id
    entry.officers.erase(member_id)
    if not actor.character_id in entry.officers:
        entry.officers.append(actor.character_id)
    _tell_guild(guild_of(member_id), "%s hands the guild to %s." % [actor.character_id, member_id])
    session().queue_save()
    return true

## The leader ends the guild (only with an empty bank, so nothing is lost).
func disband(actor: Node) -> bool:
    var id := guild_of(actor.character_id)
    if not _host() or rank_of(actor.character_id) != "leader":
        return false
    var bank: Dictionary = state.guilds[id].bank
    if not bank.items.is_empty() or not bank.goods.is_empty() or int(bank.zeni) > 0:
        _tell(actor.character_id, "Empty the guild bank before disbanding.")
        return false
    _tell_guild(id, "The guild %s was disbanded." % state.guilds[id].name)
    state.guilds.erase(id)
    session().queue_save()
    return true

func _process(_delta: float) -> void:
    if world != null and _host():
        var now := world_time()
        for id in state.invites.keys():
            if float(state.invites[id].until) < now:
                state.invites.erase(id)
    queue_redraw()

## Guild tags above characters' heads (above a worn title).
func _draw() -> void:
    var me: Node2D = world.get_local_player() if world != null and world.has_method("get_local_player") else null
    if me == null:
        return
    var font := ThemeDB.fallback_font
    for character in world.get_children():
        if not (character is CharacterBody2D and character.is_in_group("player") and character.visible) or character.global_position.distance_to(me.global_position) > 400.0:
            continue
        var tag := tag_of(character.character_id)
        if tag.is_empty():
            continue
        var text := "<%s>" % tag
        var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
        var lift := -34.0 if not ACH.worn_title(character).is_empty() else -26.0
        var spot: Vector2 = character.global_position + Vector2(-width / 2.0, lift)
        var colour := Color("8fe3a0") if same_guild(me.character_id, character.character_id) else Color("c9d4e8")
        draw_string_outline(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.05, 0.04, 0.02))
        draw_string(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, colour)

func capture() -> Dictionary:
    return state.duplicate(true)

func restore(value: Dictionary) -> void:
    state = value.duplicate(true)

static func valid_state(value: Variant, players: Dictionary = {}) -> bool:
    if not value is Dictionary or value.size() != 3 or not value.get("guilds") is Dictionary or not value.get("invites") is Dictionary or not (value.get("next") is int or value.get("next") is float):
        return false
    var seen := {}
    var names := {}
    for id in value.guilds:
        var entry: Variant = value.guilds[id]
        if not id is String or not String(id).begins_with("guild_") or not entry is Dictionary or entry.size() != 11:
            return false
        if not entry.get("name") is String or not valid_name(entry.name) or not entry.get("tag") is String or not valid_tag(entry.tag):
            return false
        if names.has(String(entry.name).to_lower()) or names.has(String(entry.tag).to_lower()):
            return false
        names[String(entry.name).to_lower()] = true
        names[String(entry.tag).to_lower()] = true
        if not (entry.get("emblem") is int or entry.get("emblem") is float) or int(entry.emblem) < 0 or int(entry.emblem) >= NATION.EMBLEMS.size():
            return false
        if not entry.get("leader") is String or not entry.get("officers") is Array or not entry.get("members") is Array:
            return false
        if entry.members.is_empty() or entry.members.size() > MAX_MEMBERS or not entry.leader in entry.members or entry.leader in entry.officers:
            return false
        for member in entry.members:
            if not member is String or seen.has(member) or (not players.is_empty() and not players.has(member)):
                return false
            seen[member] = true
        for officer in entry.officers:
            if not officer is String or not officer in entry.members:
                return false
        var bank: Variant = entry.get("bank")
        if not bank is Dictionary or bank.size() != 3 or not bank.get("items") is Array or not bank.get("goods") is Dictionary or not (bank.get("zeni") is int or bank.get("zeni") is float) or int(bank.zeni) < 0:
            return false
        if not entry.get("withdraw") in ["officers", "members"] or not (entry.get("xp") is int or entry.get("xp") is float) or int(entry.xp) < 0 or not entry.get("quests") is Dictionary or not (entry.get("founded") is int or entry.get("founded") is float):
            return false
    for guest in value.invites:
        var invite: Variant = value.invites[guest]
        if not invite is Dictionary or invite.size() != 3 or not invite.get("guild") is String or not invite.get("from") is String or not (invite.get("until") is float or invite.get("until") is int):
            return false
    return true
