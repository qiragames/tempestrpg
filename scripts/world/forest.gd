extends Node2D
@onready var session: Node = get_node("/root/GameSession")
signal system_message(message: String)
## A placeholder map with a fixed scheme (roads, pond, camp); the world's seed lays out deposits,
## creatures, points of interest and decorations (see WorldLayout). Visuals and collisions share geometry.
const LAYOUT := preload("res://scripts/world/world_layout.gd")
const ART := preload("res://scripts/visual/world_art.gd")
const WORLD_MAP := preload("res://scripts/world/world_map.gd")
const REGION := preload("res://scripts/world/region_content.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
## The archipelago around the clearing (M4.5a): ground tiles, coasts, props, collisions.
var terrain: Node2D
## The First Clearing (the start of the archipelago; see WorldMap for the whole world).
const WORLD_SIZE := Vector2(960, 640)
const POND := LAYOUT.POND

var camp: Node2D
var trial: Node2D
## Merchants, ferries and the travelling merchant (M4.5c).
var trade: Node2D
## Harbours, tickets, ships and crews (M4.5d).
var harbours: Node2D
## Parties (M4.6).
var party: Node
## M11c: trades between players.
var exchange: Node
## The Ki Realm: its people, wish orbs and tournament (M4.7).
var realm: Node2D
## M5d: the rival nations (presentation) and the monster horde's siege.
var rivals: Node2D
var siege: Node
## M11d: meteor showers, town invasions and treasure goblins.
var events: Node2D
## M11f: pets following their owners.
var pets: Node2D
## M11h: the nation's soldiers.
var army: Node2D
## Settlement and city storage (after 1.0).
var storage: Node2D
## M12b: the old master (classes) in your settlement.
var class_master: Node2D
## M14a: guilds and chat.
var guilds: Node2D
var chat: Node
## M15: duels and the arena.
var duels: Node2D
## M16: houses and inn rooms.
var housing: Node2D
var respawner: Node
## M6a: harvestable trees and ore rocks (professions).
var nodes: Node
## M7a: raid boss telegraphs and arenas.
var boss_fx: Node2D
## M7c: dungeon cave mouths and ways out.
var dungeon_gates: Node2D
## M11b: traps, levers, doors, vaults and Heroic mode in the dungeons.
var dungeon_features: Node2D
## Day, night and weather on screen.
var sky: Node2D
## M9c: quest givers, bounty boards and the quest rules.
var quests: Node2D
## Host-side randomness for gear drops, chests, trial rewards and the forge (17g).
var loot_rng := RandomNumberGenerator.new()
var chest_layer: Node2D
const SOURCES := preload("res://scripts/items/gear_sources.gd")
const GEAR_PICKUP := preload("res://scenes/pickups/gear_pickup.tscn")
const GEAR_PICKUP_REACH := 48.0
const CLAIM_RULES := preload("res://scripts/pickups/claim.gd")
var local_player: CharacterBody2D
var progression: Dictionary = {"quests": {}, "settlements": {}, "world_time": 0.0}
## The current seed's layout. Seed 0 (the reference map) until a hosted world applies its own.
var layout: Dictionary = LAYOUT.generate(0)
var _decorations: Node2D

func _ready() -> void:
    # Loot created in the first moments was loaded with the world: it lies still instead of popping.
    set_meta("born_msec", Time.get_ticks_msec())
    # Depth (step 20): characters, creatures, props and buildings are drawn in order of their feet,
    # so a character behind a tree or hut is hidden by it. Ground art is this node's own drawing.
    y_sort_enabled = true
    camp = load("res://scripts/settlement/first_camp.gd").new()
    camp.name = "FirstCamp"
    camp.y_sort_enabled = true
    add_child(camp)
    trade = load("res://scripts/trade/world_trade.gd").new()
    add_child(trade)
    harbours = load("res://scripts/travel/world_harbours.gd").new()
    add_child(harbours)
    add_child(load("res://scripts/travel/wild_mounts.gd").new())
    party = load("res://scripts/party/world_party.gd").new()
    add_child(party)
    exchange = load("res://scripts/trade/exchange.gd").new()
    add_child(exchange)
    realm = load("res://scripts/realm/ki_realm.gd").new()
    add_child(realm)
    rivals = load("res://scripts/nation/rival_nations.gd").new()
    add_child(rivals)
    siege = load("res://scripts/nation/siege.gd").new()
    add_child(siege)
    events = load("res://scripts/world/world_events.gd").new(self)
    add_child(events)
    pets = load("res://scripts/pets/pet_followers.gd").new(self)
    add_child(pets)
    army = load("res://scripts/nation/army.gd").new(self)
    add_child(army)
    storage = load("res://scripts/settlement/storage.gd").new(self)
    add_child(storage)
    class_master = load("res://scripts/nation/class_master.gd").new(self)
    add_child(class_master)
    guilds = load("res://scripts/guilds/world_guilds.gd").new()
    add_child(guilds)
    chat = load("res://scripts/network/world_chat.gd").new()
    add_child(chat)
    duels = load("res://scripts/pvp/world_duels.gd").new()
    add_child(duels)
    housing = load("res://scripts/housing/world_housing.gd").new()
    add_child(housing)
    nodes = load("res://scripts/professions/resource_nodes.gd").new(self)
    add_child(nodes)
    trial = load("res://scripts/trials/proving_trial.gd").new()
    trial.name = "ProvingTrial"
    trial.y_sort_enabled = true
    add_child(trial)
    respawner = load("res://scripts/world/respawner.gd").new()
    respawner.name = "Respawner"
    add_child(respawner)
    loot_rng.randomize()
    chest_layer = load("res://scripts/world/chest_layer.gd").new()
    chest_layer.name = "Chests"
    chest_layer.world = self
    add_child(chest_layer)
    local_player = $Player
    session.bind_world(self)
    bind_local_player(local_player)
    for enemy in [$ForestGnasher, $SecondGnasher, $ThornbackGnasher]:
        wire_enemy(enemy)
    # M4.5b: the regions' creatures (fixed homes and IDs; saves and snapshots restore them).
    for entry in REGION.all_creatures():
        var creature = load(CODEC.ENEMY_SCENES[entry[1]]).instantiate()
        creature.entity_id = entry[0]
        creature.difficulty = entry[3]
        creature.position = REGION.at(entry[2])
        add_child(creature)
        creature.home = creature.position
        creature.set_difficulty(entry[3])
        wire_enemy(creature)
    # M7a: the raid bosses in their arenas.
    var bosses := preload("res://scripts/bosses/boss_catalogue.gd")
    for id in bosses.all_ids():
        var boss = load("res://scenes/enemies/raid_boss.tscn").instantiate()
        boss.entity_id = id
        boss.difficulty = 2
        boss.position = bosses.centre(id)
        add_child(boss)
        boss.home = boss.position
        wire_enemy(boss)
    boss_fx = load("res://scripts/bosses/boss_fx.gd").new()
    add_child(boss_fx)
    # M7c: cave mouths, the ways out, and the Underdeep's darkness.
    dungeon_gates = load("res://scripts/dungeons/dungeon_gates.gd").new()
    add_child(dungeon_gates)
    dungeon_features = load("res://scripts/dungeons/dungeon_features.gd").new(self)
    add_child(dungeon_features)
    # Day, night and weather (and the darkness underground).
    sky = load("res://scripts/world/sky.gd").new(self)
    add_child(sky)
    quests = load("res://scripts/quests/quest_log.gd").new(self)
    add_child(quests)
    _add_obstacle(POND)
    # The clearing no longer ends at its edges: the archipelago surrounds it (world edges are
    # ocean and are closed by the terrain).
    terrain = load("res://scripts/world/world_terrain.gd").new()
    terrain.y_sort_enabled = true
    add_child(terrain)
    # Step 23: sound and effect cues from observed state changes (every peer).
    var presentation: Node = load("res://scripts/audio/presentation.gd").new()
    presentation.world = self
    add_child(presentation)
    _decorations = Node2D.new()
    _decorations.name = "Decorations"
    _decorations.y_sort_enabled = true
    add_child(_decorations)
    apply_layout(0, false)
    # Start the world chosen in the title menu (or on the command line), if any.
    session.call_deferred("launch_pending")

## Lay the world out from its seed. `fresh` also places the starting creatures and ally and resets
## the camp; loaded saves and client snapshots restore those from saved state instead.
func apply_layout(seed: int, fresh: bool) -> void:
    layout = LAYOUT.generate(seed)
    # The fixed region chests (M4.5b) follow the seeded three.
    layout.chests = layout.chests + REGION.chests()
    camp.set_sites(layout.deposits)
    trial.stone = layout.stone
    trial.queue_redraw()
    for child in _decorations.get_children():
        _decorations.remove_child(child)
        child.queue_free()
    # One collision body per decoration (as before); its art sits on the footprint's bottom edge.
    # SVE feedback: the clearing's own trees and rocks are resource nodes too (ResourceNodes gives
    # them indices from DECOR_BASE: trees DECOR_BASE + k, rocks DECOR_BASE + 1000 + k).
    decor_nodes = {}
    var base: int = load("res://scripts/professions/resource_nodes.gd").DECOR_BASE
    for k in range(layout.rocks.size()):
        var rock: Rect2 = layout.rocks[k]
        decor_nodes[base + 1000 + k] = ["boulder", rock.get_center() + Vector2(0, rock.size.y / 2.0 + 2.0), _add_obstacle(rock, _decorations, "rock")]
    for k in range(layout.trees.size()):
        var footprint := Rect2(layout.trees[k] + Vector2(-6, 4), Vector2(12, 12))
        decor_nodes[base + k] = ["tree_round", footprint.get_center() + Vector2(0, footprint.size.y / 2.0 + 2.0), _add_obstacle(footprint, _decorations, "tree")]
    if get("nodes") != null:
        nodes.reset_decor()
    if fresh:
        camp.restore(camp.initial_state(layout.deposits))
        for id in layout.creatures:
            var enemy: Node2D = entity_by_id(id)
            # Only untouched creatures are placed; one already hurt or defeated keeps its state.
            if enemy != null and enemy.state != enemy.State.DEFEATED and enemy.get_node("Health").current == enemy.get_node("Health").maximum:
                enemy.position = layout.creatures[id].position
                enemy.home = enemy.position
                enemy.set_difficulty(layout.creatures[id].difficulty)
        var ally: Node2D = entity_by_id(LAYOUT.ALLY_ID)
        if ally != null:
            ally.position = layout.ally
    queue_redraw()

## Host: put an item on the ground as loot (a creature drop).
## Host: a defeated character's bag as a pile at `at` (24a).
func drop_pile(owner_id: String, materials: Dictionary, items: Array, at: Vector2, id: String = "", claim_until: float = -1.0, zeni: int = 0) -> Node2D:
    if materials.is_empty() and items.is_empty() and zeni <= 0:
        return null
    var script := preload("res://scripts/pickups/item_pile.gd")
    if get_tree().get_nodes_in_group("item_piles").size() >= script.MAX_PILES:
        return null
    var pile = script.new()
    pile.entity_id = id if not id.is_empty() else "pile_" + Crypto.new().generate_random_bytes(8).hex_encode()
    pile.owner_id = owner_id
    pile.claim_until = claim_until if claim_until >= 0.0 else preload("res://scripts/pickups/claim.gd").until(self)
    pile.materials = materials.duplicate()
    pile.items = items.duplicate(true)
    pile.zeni = zeni
    pile.position = at
    add_child(pile)
    return pile

func drop_gear(item: Dictionary, at: Vector2, id: String = "", owner_id: String = "", claim_until: float = -1.0) -> Node2D:
    if item.is_empty() or get_tree().get_nodes_in_group("gear_pickups").size() >= SOURCES.MAX_LOOT:
        return null
    var pickup = GEAR_PICKUP.instantiate()
    pickup.item = item.duplicate(true)
    pickup.entity_id = id if not id.is_empty() else "loot_" + Crypto.new().generate_random_bytes(8).hex_encode()
    pickup.position = at
    pickup.owner_id = owner_id
    pickup.claim_until = claim_until if claim_until >= 0.0 else (preload("res://scripts/pickups/claim.gd").until(self) if not owner_id.is_empty() else 0.0)
    pickup.since = preload("res://scripts/pickups/claim.gd").world_time(self)
    add_child(pickup)
    return pickup

## Host, SVE feedback: loot pops out of a creature or chest at `from` and lands a short hop away
## (on open ground in sight of `from`, so it can always be picked up).
func pop_gear(item: Dictionary, from: Vector2, owner_id: String = "", claim_until: float = -1.0) -> Node2D:
    var landing := from + Vector2(0, 14)
    var start: float = loot_rng.randf() * TAU
    for attempt in range(8):
        var spot := from + Vector2.from_angle(start + attempt * TAU / 8.0) * loot_rng.randf_range(16.0, 24.0)
        var ray := PhysicsRayQueryParameters2D.create(from, spot, 1)
        if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
            landing = spot
            break
    var pickup: Node2D = drop_gear(item, landing, "", owner_id, claim_until)
    if pickup != null:
        pickup.pop_from = from - landing
    return pickup

## User request: drop bag things or loose gear at your feet (anyone may take them; gone after 10
## minutes of world time).
const DROP_LIFETIME := 600.0

func drop_from_bag(actor: Node2D, id: String, count: int) -> bool:
    var bag: Node = actor.get_node("Inventory")
    count = mini(count, bag.count_of(StringName(id)))
    if count <= 0 or preload("res://scripts/realm/realm_catalogue.gd").is_orb(id):
        return false
    if get_tree().get_nodes_in_group("item_piles").size() >= preload("res://scripts/pickups/item_pile.gd").MAX_PILES:
        session.notify_character(actor.character_id, "Too much is lying around already.")
        return false
    if not bag.discard(StringName(id), count):
        return false
    var pile: Node2D = drop_pile("", {id: count}, [], actor.global_position + Vector2(0, 10), "", 0.0)
    if pile == null:
        bag.add_material(id, count)
        return false
    pile.gone_at = CLAIM_RULES.world_time(self) + DROP_LIFETIME
    pile.dropper = actor.character_id
    session.queue_save()
    return true

func drop_gear_item(actor: Node2D, id: String) -> bool:
    var item: Dictionary = actor.item_by_id(id)
    if item.is_empty() or actor.progression.get("equipment", {}).values().has(id):
        return false
    if not actor.remove_item(id):
        return false
    var pickup: Node2D = drop_gear(item, actor.global_position + Vector2(0, 12), "", "", 0.0)
    if pickup == null:
        actor.add_item(item)
        return false
    pickup.dropper = actor.character_id
    pickup.pop_from = Vector2(0, -12)
    session.queue_save()
    return true

## Host: F picks up the nearest loot within reach (walking over it takes it as well).
func nearest_loot(actor: Node2D) -> String:
    var best := ""
    var distance: float = GEAR_PICKUP_REACH + 0.1
    for node in get_tree().get_nodes_in_group("item_piles"):
        var pile_gap: float = actor.global_position.distance_to(node.global_position)
        if pile_gap < distance and CLAIM_RULES.can_take(self, node.owner_id, node.claim_until, actor.character_id):
            best = node.entity_id
            distance = pile_gap
    for node in get_tree().get_nodes_in_group("gear_pickups"):
        var gap: float = actor.global_position.distance_to(node.global_position)
        if gap < distance and CLAIM_RULES.can_take(self, node.owner_id, node.claim_until, actor.character_id):
            best = node.entity_id
            distance = gap
    return best

func take_loot(actor: Node2D, id: String) -> bool:
    if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
        return false
    var lying: Node = entity_by_id(id)
    if lying == null or actor.get_node("Health").current <= 0:
        return false
    if lying.is_in_group("item_piles"):
        return lying.take(actor)
    if not lying.is_in_group("gear_pickups"):
        return false
    return lying.try_give(actor, true)

func nearest_chest(actor: Node2D) -> String:
    var opened: Array = actor.progression.get("chests", [])
    for chest in layout.get("chests", []):
        if not chest.id in opened and actor.global_position.distance_to(chest.position) <= SOURCES.CHEST_REACH:
            return chest.id
    return ""

## Host: each character opens each chest once and gets a rolled item.
func open_chest(actor: Node2D, id: String) -> bool:
    if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
        return false
    if session.replica_world or actor.get_node("Health").current <= 0 or nearest_chest(actor) != id:
        return false
    # The keep's and the crater's chests use the trial's better odds (Rare or Epic).
    var item: Dictionary = SOURCES.roll_trial(loot_rng) if REGION.is_rich_chest(id) else SOURCES.roll_chest(loot_rng)
    # SVE feedback: the item pops out of the chest and lies beside it, this character's for a while.
    var chest_at: Vector2 = actor.global_position
    for chest in layout.get("chests", []):
        if chest.id == id:
            chest_at = chest.position
    if pop_gear(item, chest_at, actor.character_id) == null:
        actor.add_item(item)
    actor.progression["chests"] = actor.progression.get("chests", []) + [id]
    session.notify_character(actor.character_id, "Chest opened: %s." % actor.GEAR.display_name(item))
    # M4.5c: chests hold Zeni too.
    actor.gain_zeni(preload("res://scripts/trade/trade_catalogue.gd").chest_zeni(REGION.is_rich_chest(id), loot_rng), "chest")
    session.queue_save()
    return true

func get_local_player() -> CharacterBody2D:
    return local_player if is_instance_valid(local_player) else $Player

func bind_local_player(actor: CharacterBody2D) -> void:
    local_player = actor
    actor.local_controlled = true
    var camera: Camera2D = actor.get_node("Camera2D")
    camera.enabled = true
    camera.make_current()
    var bounds: Rect2 = WORLD_MAP.bounds()
    camera.limit_left = int(bounds.position.x)
    camera.limit_top = int(bounds.position.y)
    camera.limit_right = int(bounds.end.x)
    camera.limit_bottom = int(bounds.end.y)
    $HUD.bind_player(actor)
    if not actor.has_meta("local_hud_wired"):
        actor.set_meta("local_hud_wired", true)
        actor.get_node("Health").changed.connect(func(current: int, maximum: int):
            if actor == local_player:
                _health_changed(current, maximum)
        )
        actor.get_node("Magicules").changed.connect(func(current: float, maximum: float):
            if actor == local_player:
                _magicules_changed(current, maximum)
        )
        actor.get_node("Absorption").status_changed.connect(func(message: String):
            if actor == local_player:
                _analysis_changed(message)
        )
        actor.get_node("Magicules").depleted.connect(func():
            if actor == local_player:
                _announce("Magicules depleted. Allow aura to recover.")
        )
        actor.get_node("Magicules").spend_rejected.connect(func(_cost: float):
            if actor == local_player and actor.get_node("Health").current > 0:
                _announce("Insufficient Magicules. Action unavailable.")
        )
        actor.get_node("Health").defeated.connect(func():
            if actor == local_player:
                _announce("Vital signs depleted. Press R to respawn." if session.active else "Vital signs depleted. Press R to retry.")
                actor.queue_redraw()
        )

func wire_enemy(enemy: Node2D) -> void:
    if enemy.has_meta("world_wired"):
        return
    enemy.set_meta("world_wired", true)
    enemy.get_node("Health").defeated.connect(session.queue_save)
    enemy.get_node("Health").defeated.connect(func(): respawner.schedule(enemy))
    enemy.get_node("Health").defeated.connect(func():
        if get_local_player().get_node("Health").current > 0:
            _announce("Threat neutralized. Specimen retained." if enemy.specimen != null else "Threat neutralized.")
    )

func player_by_id(id: String) -> CharacterBody2D:
    for actor in get_children():
        if actor.is_in_group("player") and actor.character_id == id:
            return actor
    return null

## User report (crazy lag for a connected player): every snapshot looked up each of the ~250
## creatures by scanning all world children (quadratic, ~15 ms per snapshot on a guest). Found
## entities are remembered; a miss scans once and remembers everything it passes.
var _entity_index: Dictionary = {}

func entity_by_id(id: String) -> Node2D:
    if id.is_empty():
        return null
    var cached: Variant = _entity_index.get(id)
    if cached != null and is_instance_valid(cached) and cached.get_parent() == self and cached.entity_id == id and not cached.is_queued_for_deletion():
        return cached
    _entity_index.erase(id)
    var found: Node2D = null
    for actor in get_children():
        if (actor.is_in_group("enemies") or actor.is_in_group("magicule_pickups") or actor.is_in_group("allies") or actor.is_in_group("gear_pickups") or actor.is_in_group("item_piles")) and not actor.is_queued_for_deletion():
            var actor_id: String = actor.entity_id
            if not _entity_index.has(actor_id):
                _entity_index[actor_id] = actor
            if actor_id == id:
                found = actor
    return found

func _process(delta: float) -> void:
    if not is_instance_valid(local_player):
        return
    if not session.active or multiplayer.is_server():
        progression.world_time += delta
        _discover_spots()
    var absorption = local_player.get_node("Absorption")
    $HUD/AnalysisProgress.visible = absorption.active
    $HUD/AnalysisProgress.value = 1.0 - absorption.time_left / maxf(absorption.channel_seconds, 0.001)
    _health_changed(local_player.get_node("Health").current, local_player.get_node("Health").maximum)
    _magicules_changed(local_player.get_node("Magicules").current, local_player.get_node("Magicules").maximum)

## Host: hidden leveling spots (24a) become known to a character who comes close; only then do
## the world map and minimap show them to that character.
func _discover_spots() -> void:
    for actor in get_children():
        if not actor is CharacterBody2D or not actor.has_method("race") or actor.get_node("Health").current <= 0:
            continue
        var known: Array = actor.progression.get("spots", [])
        for spot in REGION.SPOTS:
            if spot[0] in known or actor.global_position.distance_to(REGION.at(spot[2])) > REGION.DISCOVER_RADIUS:
                continue
            actor.progression["spots"] = known + [spot[0]]
            known = actor.progression.spots
            session.notify_character(actor.character_id, "Leveling spot discovered: %s. Its creatures return three times faster." % REGION.SPOT_NAMES[spot[0]])
            session.queue_save()
        # M7c: hidden elites.
        var bosses := preload("res://scripts/bosses/boss_catalogue.gd")
        var found: Array = actor.progression.get("elites", [])
        for id in bosses.ELITES:
            if id in found or actor.global_position.distance_to(bosses.centre(id)) > bosses.DISCOVER_RADIUS:
                continue
            actor.progression["elites"] = found + [id]
            found = actor.progression.elites
            session.notify_character(actor.character_id, "A hidden elite: %s! (level %d)" % [bosses.display_name(id), bosses.level(id)])
            session.queue_save()

func _analysis_changed(message: String) -> void:
    $HUD/Analysis.text = message
    if get_local_player().get_node("Health").current > 0:
        _announce(message)

func _announce(message: String) -> void:
    $HUD/SystemVoice.text = "[System] " + message
    system_message.emit(message)

func _health_changed(current: int, maximum: int) -> void:
    var regen: bool = is_instance_valid(local_player) and local_player.get_node("Health").regen_left > 0.0
    $HUD/Health.text = "HP %d / %d%s" % [current, maximum, "  + healing" if regen else ""]

func _magicules_changed(current: float, maximum: float) -> void:
    $HUD/Magicules.text = "Magicules %.1f / %.0f" % [current, maximum]
    $HUD/MagiculeBar.max_value = maximum
    $HUD/MagiculeBar.value = current

func announce_magicule_pickup(amount: float, character_id: String = "") -> void:
    var id: String = character_id if not character_id.is_empty() else get_local_player().character_id
    if session.active:
        session.notify_character(id, "Recovered %.1f Magicules." % amount)
    elif get_local_player().get_node("Health").current > 0:
        _announce("Recovered %.1f Magicules." % amount)

## Decoration index → [prop kind, foot, body] (see apply_layout).
var decor_nodes: Dictionary = {}

func _add_obstacle(rect: Rect2, parent: Node = self, art: String = "") -> StaticBody2D:
    var body := StaticBody2D.new()
    body.position = rect.get_center()
    var collider := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = rect.size
    collider.shape = shape
    body.add_child(collider)
    if not art.is_empty():
        body.y_sort_enabled = true
        body.add_child(ART.prop(art, Vector2(0, rect.size.y / 2.0 + 2.0)))
    parent.add_child(body)
    return body

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("restart") and not session.active:
        get_tree().reload_current_scene()

func _draw() -> void:
    # The ground (including the clearing's grass, roads and pond) is the terrain's tile layer.
    pass
