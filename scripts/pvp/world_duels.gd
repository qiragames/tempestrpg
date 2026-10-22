extends Node2D
## Duels and the arena (M15, user design 2026-10-18): challenge a character next to you to a duel
## (both must accept; no item loss, nobody dies). Both fighters start at full HP inside a ring;
## only they can hurt each other; the blow that would finish one leaves them at 1 HP and wins the
## round; leaving the ring gives the match away; a round runs out after ROUND_SECONDS (more HP left
## wins it). A duel is one round. At an Arena (a village building) the match is best of three, with
## a short break between rounds, and goes into everyone's arena record (won/lost, saved with the
## character in progression.pvp = {"duels": [won, lost], "arena": [won, lost]}).
## Host rules here (the "duel" intent); matches are snapshots only (never saved); drawn everywhere.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const CHALLENGE_REACH := 160.0
const CHALLENGE_SECONDS := 30.0
const RING := 120.0
const ARENA_RING := 110.0
const ARENA_REACH := 70.0
const ROUND_SECONDS := 90.0
const BREAK_SECONDS := 3.0
const ARENA_ROUNDS := 2

var state: Dictionary = initial_state()
var world: Node
var _clock := 0.0
var _drawn_rings := false

static func initial_state() -> Dictionary:
    return {"challenges": {}, "matches": {}, "next": 1}

func _ready() -> void:
    name = "Duels"
    world = get_parent()
    z_index = 5

func session() -> Node:
    return get_node("/root/GameSession")

func _host() -> bool:
    return AUTHORITY.can_mutate(self) and not session().replica_world

func _tell(id: String, message: String) -> void:
    session().notify_character(id, message)

## --- Queries (every peer).
func match_of(character_id: String) -> String:
    for id in state.matches:
        if character_id in [state.matches[id].a, state.matches[id].b]:
            return id
    return ""

func in_match(character_id: String) -> bool:
    return not match_of(character_id).is_empty()

func opponent(character_id: String) -> String:
    var id := match_of(character_id)
    if id.is_empty():
        return ""
    var entry: Dictionary = state.matches[id]
    return entry.b if entry.a == character_id else entry.a

## Whether `attacker` may hurt `target` right now (fighting each other, not between rounds).
func can_hit(attacker: Node, target: Node) -> bool:
    if attacker == null or target == null or not attacker.get("character_id") is String or not target.get("character_id") is String:
        return false
    var id := match_of(attacker.character_id)
    return not id.is_empty() and opponent(attacker.character_id) == target.character_id and _clock >= float(state.matches[id].resume)

func arenas() -> Array:
    var camp: Node = world.get("camp") if world != null else null
    if camp == null or not camp.state.founded:
        return []
    return camp.state.nation.buildings.filter(func(entry): return entry.kind == "arena")

## The foot of the arena a character stands at (Vector2.INF when none).
func arena_at(actor: Node2D) -> Vector2:
    for entry in arenas():
        var foot: Vector2 = NATION.foot(Vector2i(entry.tile[0], entry.tile[1]))
        if actor.global_position.distance_to(foot) <= ARENA_REACH:
            return foot
    return Vector2.INF

static func record(progression: Dictionary, kind: String) -> Array:
    var pvp: Variant = progression.get("pvp")
    if pvp is Dictionary and pvp.get(kind) is Array and pvp[kind].size() == 2:
        return [int(pvp[kind][0]), int(pvp[kind][1])]
    return [0, 0]

## --- Host operations.
func challenge(actor: Node2D, target_id: String) -> bool:
    if not _host() or target_id == actor.character_id or in_match(actor.character_id):
        return false
    var target: Node2D = world.player_by_id(target_id)
    if target == null or in_match(target_id) or target.get_node("Health").current <= 0 or actor.get_node("Health").current <= 0:
        return false
    if actor.global_position.distance_to(target.global_position) > CHALLENGE_REACH:
        _tell(actor.character_id, "Stand closer to %s to challenge them." % target_id)
        return false
    var arena: bool = arena_at(actor) != Vector2.INF and arena_at(target) != Vector2.INF
    state.challenges[target_id] = {"from": actor.character_id, "until": _clock + CHALLENGE_SECONDS, "arena": arena}
    _tell(target_id, "%s challenges you to %s (P to answer)." % [preload("res://scripts/progression/character_names.gd").display(actor.progression), "an arena match (best of three)" if arena else "a duel"])
    _tell(actor.character_id, "You challenged %s." % target_id)
    return true

func accept(actor: Node2D) -> bool:
    var offer: Dictionary = state.challenges.get(actor.character_id, {})
    if not _host() or offer.is_empty() or float(offer.until) < _clock:
        return false
    state.challenges.erase(actor.character_id)
    var rival: Node2D = world.player_by_id(offer.from)
    if rival == null or in_match(offer.from) or in_match(actor.character_id) or rival.global_position.distance_to(actor.global_position) > CHALLENGE_REACH + 40.0:
        return false
    var centre: Vector2 = (rival.global_position + actor.global_position) / 2.0
    var arena := bool(offer.arena)
    if arena:
        var foot := arena_at(actor)
        if foot == Vector2.INF:
            arena = false
        else:
            centre = foot + Vector2(0, 40)
    var id := "match_%d" % int(state.next)
    state.next = int(state.next) + 1
    state.matches[id] = {"a": offer.from, "b": actor.character_id, "at": [centre.x, centre.y], "ring": ARENA_RING if arena else RING, "arena": arena, "round": 1, "wins": [0, 0], "until": _clock + BREAK_SECONDS + ROUND_SECONDS, "resume": _clock + BREAK_SECONDS}
    for fighter in [rival, actor]:
        _restore(fighter)
    _tell(offer.from, "%s accepted! Fight in the ring — round 1 begins in %d s." % [preload("res://scripts/progression/character_names.gd").display(actor.progression), int(BREAK_SECONDS)])
    _tell(actor.character_id, "Fight %s in the ring — round 1 begins in %d s." % [offer.from, int(BREAK_SECONDS)])
    return true

func decline(actor: Node) -> bool:
    if not _host() or not state.challenges.has(actor.character_id):
        return false
    _tell(state.challenges[actor.character_id].from, "%s declined the challenge." % preload("res://scripts/progression/character_names.gd").display(actor.progression))
    state.challenges.erase(actor.character_id)
    return true

func forfeit(actor: Node) -> bool:
    var id := match_of(actor.character_id)
    if not _host() or id.is_empty():
        return false
    _finish(id, opponent(actor.character_id), "%s gave up." % preload("res://scripts/progression/character_names.gd").display(actor.progression))
    return true

## From Health.take_damage (via Player.duel_guard): the blow that would finish a fighter wins the
## round instead (both are healed for the next round, or after the match). Returns the damage to
## apply (0 after a round-winning blow).
func guard(defender: Node, source: Node, hit: int) -> int:
    if not _host() or not can_hit(source, defender):
        return hit
    if hit < defender.get_node("Health").current:
        return hit
    _round_won(match_of(defender.character_id), source.character_id)
    return 0

func _restore(fighter: Node) -> void:
    var health: Node = fighter.get_node("Health")
    health.current = health.maximum
    health.changed.emit(health.current, health.maximum)

func _round_won(id: String, winner: String) -> void:
    var entry: Dictionary = state.matches[id]
    var side := 0 if entry.a == winner else 1
    entry.wins[side] = int(entry.wins[side]) + 1
    var needed := ARENA_ROUNDS if entry.arena else 1
    if int(entry.wins[side]) >= needed:
        _finish(id, winner, "")
        return
    entry.round = int(entry.round) + 1
    entry.resume = _clock + BREAK_SECONDS
    entry.until = entry.resume + ROUND_SECONDS
    for fighter_id in [entry.a, entry.b]:
        _tell(fighter_id, "%s takes the round (%d-%d). Round %d in %d s." % [winner, int(entry.wins[0]), int(entry.wins[1]), int(entry.round), int(BREAK_SECONDS)])
        var fighter: Node = world.player_by_id(fighter_id)
        if fighter != null:
            _restore(fighter)

func _finish(id: String, winner: String, why: String) -> void:
    var entry: Dictionary = state.matches[id]
    state.matches.erase(id)
    var loser: String = entry.b if entry.a == winner else entry.a
    var kind := "arena" if entry.arena else "duels"
    for pair in [[winner, 0], [loser, 1]]:
        var fighter: Node = world.player_by_id(pair[0])
        if fighter == null:
            continue
        var counts := record(fighter.progression, kind)
        counts[pair[1]] += 1
        if not fighter.progression.get("pvp") is Dictionary:
            fighter.progression["pvp"] = {"duels": [0, 0], "arena": [0, 0]}
        fighter.progression.pvp[kind] = counts
        _restore(fighter)
    var text := "%s%s won the %s against %s (%d-%d)." % [why + " " if not why.is_empty() else "", winner, "arena match" if entry.arena else "duel", loser, maxi(int(entry.wins[0]), int(entry.wins[1])), mini(int(entry.wins[0]), int(entry.wins[1]))]
    if entry.arena:
        for actor in get_tree().get_nodes_in_group("player"):
            if actor.get_parent() == world:
                _tell(actor.character_id, text)
    else:
        _tell(winner, text)
        _tell(loser, text)
    session().queue_save()

func _process(delta: float) -> void:
    _clock += delta
    if not state.matches.is_empty() or _drawn_rings:
        _drawn_rings = not state.matches.is_empty()
        queue_redraw()
    if world == null or not _host():
        return
    for target in state.challenges.keys():
        if float(state.challenges[target].until) < _clock:
            state.challenges.erase(target)
    for id in state.matches.keys():
        if not state.matches.has(id):
            continue
        var entry: Dictionary = state.matches[id]
        var a: Node2D = world.player_by_id(entry.a)
        var b: Node2D = world.player_by_id(entry.b)
        if a == null or b == null:
            _finish(id, entry.a if a != null else entry.b, "%s left." % (entry.b if a != null else entry.a))
            continue
        var centre := Vector2(entry.at[0], entry.at[1])
        for pair in [[a, entry.b], [b, entry.a]]:
            if state.matches.has(id) and pair[0].global_position.distance_to(centre) > float(entry.ring) + 8.0:
                _finish(id, pair[1], "%s left the ring." % preload("res://scripts/progression/character_names.gd").display(pair[0].progression))
        if state.matches.has(id) and _clock >= float(entry.until):
            var share_a: float = float(a.get_node("Health").current) / maxf(1.0, a.get_node("Health").maximum)
            var share_b: float = float(b.get_node("Health").current) / maxf(1.0, b.get_node("Health").maximum)
            if is_equal_approx(share_a, share_b):
                entry.resume = _clock + BREAK_SECONDS
                entry.until = entry.resume + ROUND_SECONDS
                _restore(a)
                _restore(b)
                _tell(entry.a, "Time! A draw — the round starts again.")
                _tell(entry.b, "Time! A draw — the round starts again.")
            else:
                _round_won(id, entry.a if share_a > share_b else entry.b)

## The rings of running matches.
func _draw() -> void:
    for id in state.matches:
        var entry: Dictionary = state.matches[id]
        var centre := Vector2(entry.at[0], entry.at[1])
        var colour := Color("ffd84a") if entry.arena else Color("ff8a5a")
        draw_arc(centre, float(entry.ring), 0.0, TAU, 64, Color(colour, 0.25), 6.0)
        draw_arc(centre, float(entry.ring), 0.0, TAU, 64, Color(colour, 0.85), 1.5)

## The banner text for a fighter ("" when not fighting).
func banner(character_id: String) -> String:
    var id := match_of(character_id)
    if id.is_empty():
        return ""
    var entry: Dictionary = state.matches[id]
    var mine := 0 if entry.a == character_id else 1
    var waiting: float = float(entry.resume) - _clock
    var left: float = maxf(0.0, float(entry.until) - _clock)
    return "%s vs %s · round %d · %d-%d · %s" % ["ARENA" if entry.arena else "DUEL", preload("res://scripts/progression/character_names.gd").named(self, opponent(character_id)), int(entry.round), int(entry.wins[mine]), int(entry.wins[1 - mine]), ("starts in %d" % ceili(waiting)) if waiting > 0.0 else "%d:%02d" % [int(left) / 60, int(left) % 60]]

func capture() -> Dictionary:
    var copy := state.duplicate(true)
    copy["clock"] = _clock
    return copy

func restore(value: Dictionary) -> void:
    if value.get("matches") is Dictionary:
        state = value.duplicate(true)
        _clock = float(state.get("clock", _clock))
        state.erase("clock")

## Saves: the per-character record.
static func valid_record(progression: Dictionary) -> bool:
    if not progression.has("pvp"):
        return true
    var pvp: Variant = progression.pvp
    if not pvp is Dictionary or pvp.size() != 2:
        return false
    for kind in ["duels", "arena"]:
        var counts: Variant = pvp.get(kind)
        if not counts is Array or counts.size() != 2:
            return false
        for value in counts:
            if not (value is int or value is float) or int(value) < 0 or int(value) > 1000000:
                return false
    return true
