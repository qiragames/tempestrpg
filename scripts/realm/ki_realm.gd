extends Node2D
## The Ki Realm of one world (M4.7, user plan): the secret hermit in Sakura Vale and the way in
## (the right answer, level 36+, M7b), the guide back, the mentors who teach ki attacks and the Kaio
## Surge, the seven wish orbs (lying at hidden spots until taken; all seven make one wish at the
## Guardian's altar, then they rest for an hour and scatter again) and the World Martial Grounds'
## tournament (five rounds in the ring; the champion's first win teaches the Golden Aura). The host
## decides everything; clients name an NPC, an answer, an orb or a wish. Saved and replicated.
const REALM := preload("res://scripts/realm/realm_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
const AUTHORITY := preload("res://scripts/network/authority.gd")
const GNASHER := preload("res://scripts/enemies/forest_gnasher.gd")

var state: Dictionary = initial_state()
var world: Node
var _orbs: Dictionary = {}
var _altar: Node2D

## Orbs start at the first seven spots; no tournament is running.
static func initial_state() -> Dictionary:
    return {"orbs": range(REALM.ORB_COUNT), "rest_until": 0.0, "scatter": 0, "tournament": {"fighter": "", "round": 0}}

func _ready() -> void:
    name = "KiRealm"
    y_sort_enabled = true
    world = get_parent()
    _person("secret_hermit", "secret_hermit", REALM.HERMIT_TILE)
    _person("realm_guide", "realm_guide", REALM.GUIDE_TILE)
    _person("announcer", "announcer", REALM.ANNOUNCER_TILE)
    for entry in REALM.MENTORS:
        _person(entry[0], entry[2], entry[3])
    _altar = Node2D.new()
    _altar.name = "WishAltar"
    _altar.position = MAP.to_world(REALM.ALTAR_TILE)
    _altar.draw.connect(func():
        _altar.draw_rect(Rect2(-10, -6, 20, 8), Color("8a7f72"))
        _altar.draw_rect(Rect2(-7, -12, 14, 6), Color("b0a596"))
        _altar.draw_circle(Vector2(0, -15), 3.0, Color(1.0, 0.75, 0.25, 0.6 + 0.4 * sin(Time.get_ticks_msec() / 300.0)))
    )
    add_child(_altar)
    # The tournament ring: a raised stone platform (sorted behind everyone standing on it).
    var ring := Node2D.new()
    ring.name = "Ring"
    var lift := REALM.RING_RADIUS * MAP.TILE + 40.0
    ring.position = REALM.ring_centre() - Vector2(0, lift)
    ring.draw.connect(func():
        var half := REALM.RING_RADIUS * MAP.TILE
        var box := Rect2(Vector2(-half, lift - half), Vector2(half, half) * 2.0)
        ring.draw_rect(box.grow(3), Color("5d5850"))
        ring.draw_rect(box, Color("c9c1ae"))
        for line in range(1, 4):
            var y := box.position.y + box.size.y * line / 4.0
            ring.draw_line(Vector2(box.position.x, y), Vector2(box.end.x, y), Color("aea58f"), 1.0)
            var x := box.position.x + box.size.x * line / 4.0
            ring.draw_line(Vector2(x, box.position.y), Vector2(x, box.end.y), Color("aea58f"), 1.0)
    )
    add_child(ring)

func _person(id: String, sprite: String, tile: Vector2) -> void:
    var npc := Node2D.new()
    npc.name = id
    npc.position = MAP.to_world(tile)
    var body := SPRITES.make(sprite)
    npc.add_child(body)
    SPRITES.play(body, "idle_down")
    add_child(npc)

func session() -> Node:
    return get_node("/root/GameSession")

func world_time() -> float:
    return float(world.progression.get("world_time", 0.0)) if world != null else 0.0

func _host() -> bool:
    return AUTHORITY.can_mutate(self) and not session().replica_world

func _tell(actor: Node, message: String) -> void:
    session().notify_character(actor.character_id, message)

func person_position(id: String) -> Vector2:
    var node := get_node_or_null(id)
    return node.position if node != null else Vector2.INF

## The realm person (or the altar) an actor stands beside ("" if none).
func nearest_person(actor: Node2D) -> String:
    for child in get_children():
        if child == _altar or child.name.begins_with("Orb") or child.name == "Ring":
            continue
        if actor.global_position.distance_to(child.position) <= REALM.NPC_REACH:
            return String(child.name)
    if actor.global_position.distance_to(_altar.position) <= REALM.NPC_REACH:
        return "altar"
    return ""

## An orb lying within reach (its index, -1 if none).
func nearest_orb(actor: Node2D) -> int:
    for index in range(state.orbs.size()):
        var spot: int = int(state.orbs[index])
        if spot >= 0 and actor.global_position.distance_to(MAP.to_world(REALM.ORB_SPOTS[spot])) <= REALM.ORB_REACH:
            return index
    return -1

## Host: answer the secret hermit (index into HERMIT_ANSWERS).
func answer_hermit(actor: Node2D, answer: int) -> bool:
    if not _host() or nearest_person(actor) != "secret_hermit":
        return false
    if int(actor.progression.get("level", 1)) < REALM.REQUIRED_LEVEL:
        _tell(actor, "The hermit smiles: \"Come back when you are stronger.\" (level %d)" % REALM.REQUIRED_LEVEL)
        return false
    if answer != REALM.HERMIT_RIGHT:
        _tell(actor, "The hermit shrugs and goes back to watching the petals.")
        return false
    _travel(actor, MAP.to_world(REALM.ARRIVAL_TILE))
    _tell(actor, "The hermit taps his staff... the world folds. Welcome to the Ki Realm.")
    return true

## Host: the guide in Dome City sends you back to the hermit.
func leave_realm(actor: Node2D) -> bool:
    if not _host() or nearest_person(actor) != "realm_guide":
        return false
    _travel(actor, MAP.to_world(REALM.HERMIT_TILE) + Vector2(0, 20))
    _tell(actor, "Back in Sakura Vale, beside the old hermit.")
    return true

func _travel(actor: Node2D, to: Vector2) -> void:
    actor.global_position = to
    actor.velocity = Vector2.ZERO
    actor.dismount()
    if world.has_node("WorldTerrain"):
        world.get_node("WorldTerrain").ensure_props_at(to)
    session().queue_save()

## Host: learn from a mentor (level and Zeni).
func learn(actor: Node2D, mentor_id: String) -> bool:
    var entry: Array = REALM.mentor(mentor_id)
    if not _host() or entry.is_empty() or nearest_person(actor) != mentor_id:
        return false
    var known: bool = actor.get_node("SkillBook").knows(StringName(entry[5])) if entry[4] == "skill" else entry[5] in actor.progression.get("auras", [])
    if known:
        _tell(actor, "%s: \"You already know it.\"" % entry[1])
        return false
    if int(actor.progression.get("level", 1)) < int(entry[6]):
        _tell(actor, "%s: \"Come back at level %d.\"" % [entry[1], entry[6]])
        return false
    if not actor.spend_zeni(int(entry[7])):
        _tell(actor, "%s asks %d Zeni for the lesson." % [entry[1], entry[7]])
        return false
    if entry[4] == "skill":
        actor.get_node("SkillBook").learn_from_scroll(entry[5])
        _tell(actor, "%s taught you %s. Activate it in the skill tree (K)." % [entry[1], load(preload("res://scripts/skills/skill_catalogue.gd").SKILLS[entry[5]]).display_name])
    else:
        actor.progression.auras.append(entry[5])
        _tell(actor, "%s taught you the %s. Power up with X." % [entry[1], REALM.AURAS[entry[5]][0]])
    session().queue_save()
    return true

## Host: pick up the wish orb at your feet.
func take_orb(actor: Node2D, index: int) -> bool:
    if not _host() or index < 0 or index >= state.orbs.size() or int(state.orbs[index]) < 0 or nearest_orb(actor) != index:
        return false
    if actor.get_node("Inventory").add_material(REALM.orb_id(index), 1) != 1:
        _tell(actor, "No room in the bag for the orb.")
        return false
    state.orbs[index] = -1
    var held := 0
    for n in range(REALM.ORB_COUNT):
        held += actor.get_node("Inventory").count_of(REALM.orb_id(n))
    _tell(actor, "You found a wish orb (%d of %d). Bring all seven to the Guardian's altar." % [held, REALM.ORB_COUNT])
    session().queue_save()
    return true

## Host: make a wish at the altar with all seven orbs.
func wish(actor: Node2D, choice: String) -> bool:
    if not _host() or nearest_person(actor) != "altar" or not choice in REALM.WISHES:
        return false
    var bag: Node = actor.get_node("Inventory")
    for n in range(REALM.ORB_COUNT):
        if bag.count_of(REALM.orb_id(n)) <= 0:
            _tell(actor, "The altar stays silent. It wants all seven orbs.")
            return false
    if choice == "aura" and "golden_aura_2" in actor.progression.get("auras", []):
        _tell(actor, "You already hold every transformation the dragon can give.")
        return false
    if choice == "item" and actor.gear.items.size() >= actor.GEAR.MAX_ITEMS:
        _tell(actor, "Make room in your gear bag first.")
        return false
    for n in range(REALM.ORB_COUNT):
        bag.discard(StringName(REALM.orb_id(n)), 1)
    match choice:
        "item":
            var rng := RandomNumberGenerator.new()
            rng.randomize()
            var item: Dictionary = actor.GEAR.roll(preload("res://scripts/items/gear_sources.gd")._base(rng, [], 4, int(actor.progression.get("level", 15))), 4, rng)
            actor.add_item(item)
            _tell(actor, "The eternal dragon grants: %s!" % actor.GEAR.display_name(item))
        "zeni":
            actor.gain_zeni(REALM.WISH_ZENI, "wish")
            _tell(actor, "The eternal dragon grants: %d Zeni!" % REALM.WISH_ZENI)
        "points":
            actor.progression["bonus_points"] = int(actor.progression.get("bonus_points", 0)) + REALM.WISH_POINTS
            actor.progression["skill_points"] = int(actor.progression.skill_points) + REALM.WISH_POINTS
            _tell(actor, "The eternal dragon grants: %d skill points!" % REALM.WISH_POINTS)
        "aura":
            var gift: String = "golden_aura" if not "golden_aura" in actor.progression.get("auras", []) else "golden_aura_2"
            actor.progression.auras.append(gift)
            _tell(actor, "The eternal dragon grants: the %s! (X to power up)" % REALM.AURAS[gift][0])
    state.orbs = []
    for n in range(REALM.ORB_COUNT):
        state.orbs.append(-1)
    state.rest_until = world_time() + REALM.ORB_REST
    for id in [actor.character_id]:
        session().notify_character(id, "The seven orbs turn to stone and fly off in every direction. In an hour they will glow again.")
    session().queue_save()
    return true

## Host: enter the tournament (level, fee; one fighter at a time).
func enter_tournament(actor: Node2D) -> bool:
    if not _host() or nearest_person(actor) != "announcer":
        return false
    if not String(state.tournament.fighter).is_empty():
        _tell(actor, "A bout is under way. Wait for the next one.")
        return false
    if int(actor.progression.get("level", 1)) < REALM.TOURNAMENT_LEVEL:
        _tell(actor, "Fighters must be level %d." % REALM.TOURNAMENT_LEVEL)
        return false
    if not actor.spend_zeni(REALM.ENTRY_FEE):
        _tell(actor, "The entry fee is %d Zeni." % REALM.ENTRY_FEE)
        return false
    state.tournament = {"fighter": actor.character_id, "round": 0}
    actor.global_position = REALM.ring_centre() + Vector2(-40, 0)
    _spawn_round()
    _tell(actor, "The World Martial Grounds! Five bouts — stay in the ring.")
    session().queue_save()
    return true

func _spawn_round() -> void:
    var round_index: int = int(state.tournament.round)
    var spec: Array = REALM.ROUNDS[round_index]
    var foe = load(preload("res://scripts/persistence/state_codec.gd").ENEMY_SCENES[spec[0]]).instantiate()
    foe.entity_id = "tourney_%d" % round_index
    foe.drops_rewards = false
    foe.specimen = null
    foe.position = REALM.ring_centre() + Vector2(40, 0)
    world.add_child(foe)
    world.wire_enemy(foe)
    foe.set_difficulty(spec[1])
    foe.level = spec[2]
    foe.get_node("Health").maximum = GNASHER.scaled_health(spec[1], spec[2])
    foe.get_node("Health").current = foe.get_node("Health").maximum
    foe.damage = GNASHER.scaled_damage(spec[1], spec[2])

func _tournament_foe() -> Node:
    return world.entity_by_id("tourney_%d" % int(state.tournament.round))

func _end_tournament(message: String) -> void:
    var fighter: Node = world.player_by_id(String(state.tournament.fighter))
    var foe := _tournament_foe()
    if foe != null:
        world.remove_child(foe)
        foe.queue_free()
    if fighter != null:
        _tell(fighter, message)
    state.tournament = {"fighter": "", "round": 0}
    session().queue_save()

func _process(_delta: float) -> void:
    _sync_orbs()
    _altar.queue_redraw()
    if world == null or not _host():
        return
    # Orbs scatter again an hour after a wish.
    if float(state.rest_until) > 0.0 and world_time() >= float(state.rest_until):
        var rng := RandomNumberGenerator.new()
        rng.seed = hash("orbs:%d" % (int(state.scatter) + 1))
        var spots: Array = range(REALM.ORB_SPOTS.size())
        for index in range(spots.size() - 1, 0, -1):
            var other := rng.randi_range(0, index)
            var keep = spots[index]
            spots[index] = spots[other]
            spots[other] = keep
        state.orbs = spots.slice(0, REALM.ORB_COUNT)
        state.rest_until = 0.0
        state.scatter = int(state.scatter) + 1
    # The tournament: a defeat or leaving the ring loses; a defeated opponent brings the next.
    var fighter_id: String = String(state.tournament.fighter)
    if fighter_id.is_empty():
        return
    var fighter: Node = world.player_by_id(fighter_id)
    if fighter == null or fighter.get_node("Health").current <= 0:
        _end_tournament("You were defeated in the tournament.")
        return
    if fighter.global_position.distance_to(REALM.ring_centre()) > REALM.RING_RADIUS * MAP.TILE * 1.6:
        _end_tournament("You left the ring — the bout is lost.")
        return
    var foe := _tournament_foe()
    if foe == null or foe.get_node("Health").current <= 0:
        if foe != null:
            world.remove_child(foe)
            foe.queue_free()
        state.tournament.round = int(state.tournament.round) + 1
        if int(state.tournament.round) >= REALM.ROUNDS.size():
            fighter.gain_zeni(REALM.PRIZE, "tournament")
            var first: bool = not fighter.progression.get("champion", false)
            fighter.progression["champion"] = true
            if first and not "golden_aura" in fighter.progression.get("auras", []):
                fighter.progression.auras.append("golden_aura")
            state.tournament = {"fighter": "", "round": 0}
            _tell(fighter, "CHAMPION of the World Martial Grounds! %d Zeni%s" % [REALM.PRIZE, " and the Golden Aura (X)!" if first else "."])
            session().queue_save()
            return
        _spawn_round()
        _tell(fighter, "Round %d!" % (int(state.tournament.round) + 1))

## Glowing orbs at their spots (every peer, from the replicated state).
func _sync_orbs() -> void:
    for index in range(REALM.ORB_COUNT):
        var spot: int = int(state.orbs[index]) if index < state.orbs.size() else -1
        var node: Node2D = _orbs.get(index)
        if spot < 0:
            if is_instance_valid(node):
                node.queue_free()
                _orbs.erase(index)
            continue
        if not is_instance_valid(node):
            node = Node2D.new()
            node.name = "Orb%d" % index
            var stars := index + 1
            node.draw.connect(func():
                var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 250.0 + stars)
                node.draw_circle(Vector2(0, -6), 7.0, Color(1.0, 0.7, 0.2, 0.25 * pulse))
                node.draw_circle(Vector2(0, -6), 4.5, Color(1.0, 0.62, 0.15))
                node.draw_circle(Vector2(-1.5, -7.5), 1.2, Color(1, 1, 1, 0.8))
                for star in range(stars):
                    var at := Vector2(-2.0 + (star % 3) * 2.0, -7.0 + int(star / 3) * 2.0)
                    node.draw_rect(Rect2(at, Vector2(1, 1)), Color("c0281e"))
            )
            add_child(node)
            _orbs[index] = node
        node.position = MAP.to_world(REALM.ORB_SPOTS[spot]) + Vector2(8, 8)
        node.queue_redraw()

func capture() -> Dictionary:
    return state.duplicate(true)

## A reloaded world never resumes a bout (its fighters and foes are not saved mid-fight).
func restore(value: Dictionary, replica: bool = false) -> void:
    state = value.duplicate(true)
    if not replica:
        state.tournament = {"fighter": "", "round": 0}
        _clear_tournament_foes.call_deferred()

func _clear_tournament_foes() -> void:
    for node in get_tree().get_nodes_in_group("enemies"):
        if String(node.entity_id).begins_with("tourney_"):
            node.get_parent().remove_child(node)
            node.queue_free()

static func valid_state(value: Variant) -> bool:
    if not value is Dictionary or value.size() != 4 or not value.get("orbs") is Array or value.orbs.size() != REALM.ORB_COUNT:
        return false
    var seen := {}
    for spot in value.orbs:
        if not (spot is int or spot is float) or spot != floor(spot) or spot < -1 or spot >= REALM.ORB_SPOTS.size() or (spot >= 0 and seen.has(spot)):
            return false
        seen[spot] = true
    if not (value.get("rest_until") is float or value.get("rest_until") is int) or float(value.rest_until) < 0.0:
        return false
    if not (value.get("scatter") is int or value.get("scatter") is float) or value.scatter < 0:
        return false
    var bout: Variant = value.get("tournament")
    return bout is Dictionary and bout.size() == 2 and bout.get("fighter") is String and (bout.get("round") is int or bout.get("round") is float) and bout.round >= 0 and bout.round < REALM.ROUNDS.size()
