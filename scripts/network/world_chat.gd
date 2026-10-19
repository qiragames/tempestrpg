extends Node
## Chat (M14a, with guilds): Enter opens a line at the bottom left; what you write goes to everyone
## in the world, or with /g to your guild and /p to your party. The host keeps the last LINES
## lines (snapshots only, never saved) with who said it and to whom; every peer shows the lines
## meant for its own character in the event log. One line per SPACING seconds per character.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const LINES := 40
const MAX_LENGTH := 120
const SPACING := 0.6
const CHANNELS := ["world", "guild", "party"]

var state: Dictionary = initial_state()
var world: Node
var _last_said: Dictionary = {}
## Game time (follows pausing and the engine's time scale, like every other cooldown).
var _clock := 0.0

static func initial_state() -> Dictionary:
    return {"lines": [], "next": 1}

func _ready() -> void:
    name = "Chat"
    world = get_parent()

func session() -> Node:
    return get_node("/root/GameSession")

## Host: say something on a channel. Guild and party lines need a guild or party.
func say(actor: Node, channel: String, text: String) -> bool:
    if not AUTHORITY.can_mutate(self) or session().replica_world or not channel in CHANNELS:
        return false
    var words := text.strip_edges().replace("\n", " ")
    if words.is_empty() or words.length() > MAX_LENGTH:
        return false
    var now := _clock
    if now - float(_last_said.get(actor.character_id, -100.0)) < SPACING:
        return false
    var to := ""
    if channel == "guild":
        to = world.guilds.guild_of(actor.character_id) if world.get("guilds") != null else ""
    elif channel == "party":
        to = world.party.party_of(actor.character_id)
    if channel != "world" and to.is_empty():
        session().notify_character(actor.character_id, "You are in no %s." % channel)
        return false
    _last_said[actor.character_id] = now
    state.lines.append({"id": int(state.next), "from": preload("res://scripts/progression/character_names.gd").display(actor.progression), "channel": channel, "to": to, "text": words})
    state.next = int(state.next) + 1
    while state.lines.size() > LINES:
        state.lines.pop_front()
    return true

func _process(delta: float) -> void:
    _clock += delta

## Whether a line is meant for this character (world lines for everyone).
func reaches(line: Dictionary, character_id: String) -> bool:
    match String(line.get("channel", "")):
        "world":
            return true
        "guild":
            return world.get("guilds") != null and world.guilds.guild_of(character_id) == line.to
        "party":
            return world.party.party_of(character_id) == line.to
    return false

func capture() -> Dictionary:
    return state.duplicate(true)

func restore(value: Dictionary) -> void:
    if value.get("lines") is Array:
        state = value.duplicate(true)
