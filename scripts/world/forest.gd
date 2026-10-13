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
var respawner: Node
## Host-side randomness for gear drops, chests, trial rewards and the forge (17g).
var loot_rng := RandomNumberGenerator.new()
var chest_layer: Node2D
const SOURCES := preload("res://scripts/items/gear_sources.gd")
const GEAR_PICKUP := preload("res://scenes/pickups/gear_pickup.tscn")
var local_player: CharacterBody2D
var progression: Dictionary = {"quests": {}, "settlements": {}, "world_time": 0.0}
## The current seed's layout. Seed 0 (the reference map) until a hosted world applies its own.
var layout: Dictionary = LAYOUT.generate(0)
var _decorations: Node2D

func _ready() -> void:
    # Depth (step 20): characters, creatures, props and buildings are drawn in order of their feet,
    # so a character behind a tree or hut is hidden by it. Ground art is this node's own drawing.
    y_sort_enabled = true
    camp = load("res://scripts/settlement/first_camp.gd").new()
    camp.name = "FirstCamp"
    camp.y_sort_enabled = true
    add_child(camp)
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
    for entry in REGION.CREATURES:
        var creature = load(CODEC.ENEMY_SCENES[entry[1]]).instantiate()
        creature.entity_id = entry[0]
        creature.difficulty = entry[3]
        creature.position = REGION.at(entry[2])
        add_child(creature)
        creature.home = creature.position
        creature.set_difficulty(entry[3])
        wire_enemy(creature)
    _add_obstacle(POND)
    # The clearing no longer ends at its edges: the archipelago surrounds it (world edges are
    # ocean and are closed by the terrain).
    terrain = load("res://scripts/world/world_terrain.gd").new()
    terrain.y_sort_enabled = true
    add_child(terrain)
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
    for rock in layout.rocks:
        _add_obstacle(rock, _decorations, "rock")
    for tree in layout.trees:
        _add_obstacle(Rect2(tree + Vector2(-6, 4), Vector2(12, 12)), _decorations, "tree")
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
func drop_gear(item: Dictionary, at: Vector2, id: String = "") -> Node2D:
    if item.is_empty() or get_tree().get_nodes_in_group("gear_pickups").size() >= SOURCES.MAX_LOOT:
        return null
    var pickup = GEAR_PICKUP.instantiate()
    pickup.item = item.duplicate(true)
    pickup.entity_id = id if not id.is_empty() else "loot_" + Crypto.new().generate_random_bytes(8).hex_encode()
    pickup.position = at
    add_child(pickup)
    return pickup

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
    if actor.gear.items.size() >= actor.GEAR.MAX_ITEMS:
        session.notify_character(actor.character_id, "Gear bag full. Make room before opening the chest.")
        return false
    # The keep's and the crater's chests use the trial's better odds (Rare or Epic).
    var item: Dictionary = SOURCES.roll_trial(loot_rng) if REGION.is_rich_chest(id) else SOURCES.roll_chest(loot_rng)
    actor.add_item(item)
    actor.progression["chests"] = actor.progression.get("chests", []) + [id]
    session.notify_character(actor.character_id, "Chest opened: %s." % actor.GEAR.display_name(item))
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

func entity_by_id(id: String) -> Node2D:
    if id.is_empty():
        return null
    for actor in get_children():
        if (actor.is_in_group("enemies") or actor.is_in_group("magicule_pickups") or actor.is_in_group("allies") or actor.is_in_group("gear_pickups")) and actor.entity_id == id and not actor.is_queued_for_deletion():
            return actor
    return null

func _process(delta: float) -> void:
    if not is_instance_valid(local_player):
        return
    if not session.active or multiplayer.is_server():
        progression.world_time += delta
    var absorption = local_player.get_node("Absorption")
    $HUD/AnalysisProgress.visible = absorption.active
    $HUD/AnalysisProgress.value = 1.0 - absorption.time_left / maxf(absorption.channel_seconds, 0.001)
    _health_changed(local_player.get_node("Health").current, local_player.get_node("Health").maximum)
    _magicules_changed(local_player.get_node("Magicules").current, local_player.get_node("Magicules").maximum)

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

func _add_obstacle(rect: Rect2, parent: Node = self, art: String = "") -> void:
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

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("restart") and not session.active:
        get_tree().reload_current_scene()

func _draw() -> void:
    # The ground (including the clearing's grass, roads and pond) is the terrain's tile layer.
    pass
