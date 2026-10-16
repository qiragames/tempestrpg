extends SceneTree
## Dungeon variety (M11b): spike traps on the bridges hurt only while up; the sealed door opens
## when both levers are down; the Keeper's key opens the vault; Heroic mode makes creatures and the
## boss stronger and pays a Legendary piece; an empty dungeon resets; the intents and saves.
const DUNGEONS := preload("res://scripts/dungeons/dungeon_catalogue.gd")
const FEATURES := preload("res://scripts/dungeons/dungeon_features.gd")
const BOSSES := preload("res://scripts/bosses/boss_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const MAP := preload("res://scripts/world/world_map.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _frames(count: int = 3) -> void:
    for _i in range(count):
        await physics_frame
        await process_frame

func _run() -> void:
    var placed := true
    for id in DUNGEONS.ORDER:
        for spot in [FEATURES.lever_position(id, 0), FEATURES.lever_position(id, 1), FEATURES.vault_position(id)]:
            var tile: Vector2i = MAP.to_tile(spot)
            placed = placed and not MAP.solid(tile.x, tile.y) and DUNGEONS.at_tile(tile) == id
        placed = placed and FEATURES.traps(id).size() >= 3
    _check(placed, "Every dungeon has two levers and a vault on open floor and three or more traps")
    _check(preload("res://scripts/trade/trade_catalogue.gd").bag_item("key_frostfang_cavern"), "Dungeon keys are bag items")
    var phases := {}
    for step in range(30):
        phases[FEATURES.trap_phase(step * 0.1, 0)] = true
    _check(phases.size() == 3, "Traps rest, warn and strike in turn")
    # A world.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-dungeon-features-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24814, dir.path_join("features.json"), false) == OK, "Solo world hosted")
    await _frames(40)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    var features: Node = world.dungeon_features
    var id := "frostfang_cavern"
    # The door.
    _check(not features.door_open(id) and not features._doors[id].get_child(0).disabled, "The boss chamber is sealed at first")
    actor.global_position = FEATURES.lever_position(id, 1) + Vector2(10, 0)
    _check(not session.apply_action(actor, "dungeon", {"operation": "lever", "id": id, "index": 0}), "A lever must be reached to pull it")
    _check(session.apply_action(actor, "dungeon", {"operation": "lever", "id": id, "index": 1}) and not features.door_open(id), "One lever is not enough")
    actor.global_position = FEATURES.lever_position(id, 0) + Vector2(10, 0)
    _check(session.apply_action(actor, "dungeon", {"operation": "lever", "id": id, "index": 0}) and features.door_open(id), "Both levers open the door")
    await _frames(2)
    _check(features._doors[id].get_child(0).disabled, "...and the door no longer blocks the bridge")
    # Traps.
    var trap: Array = FEATURES.traps(id)[0]
    actor.global_position = trap[0]
    var health: Node = actor.get_node("Health")
    health.immunity_left = 0.0
    var before: int = health.current
    var up_time := -1.0
    var rest_time := -1.0
    for step in range(60):
        var t := step * 0.05
        if FEATURES.trap_phase(t, 0) == 2 and up_time < 0.0:
            up_time = t
        if FEATURES.trap_phase(t, 0) == 0 and rest_time < 0.0:
            rest_time = t
    world.progression.world_time = rest_time
    features._physics_process(0.016)
    _check(health.current == before, "Resting spikes do no harm")
    world.progression.world_time = up_time
    features._physics_process(0.016)
    _check(health.current < before and before - health.current <= int(ceil(health.maximum * FEATURES.TRAP_DAMAGE)) + 1, "Raised spikes hurt (10% of max HP)")
    health.current = health.maximum
    # The vault and its key.
    actor.global_position = FEATURES.vault_position(id) + Vector2(8, 0)
    _check(not session.apply_action(actor, "dungeon", {"operation": "vault", "id": id}), "The vault stays shut without its key")
    features._rng.seed = 1
    var got_key := false
    for _i in range(20):
        world.quests.on_event(actor, "kill", {"kind": "frost_bear", "region": "The Underdeep", "id": FEATURES.keeper(id)})
        if actor.get_node("Inventory").count_of(FEATURES.key_item(id)) > 0:
            got_key = true
            break
    _check(got_key, "The Keeper drops the key now and then")
    var items: int = actor.gear.items.size()
    var zeni: int = int(actor.progression.zeni)
    _check(session.apply_action(actor, "dungeon", {"operation": "vault", "id": id}) and actor.gear.items.size() == items + 1 and int(actor.progression.zeni) > zeni and actor.get_node("Inventory").count_of(FEATURES.key_item(id)) == 0, "The key opens the vault: an Epic piece and Zeni; the key is used up")
    _check(int(actor.gear.items[-1].rarity) == 3, "Normal vaults give Epic gear")
    # Heroic.
    actor.global_position = Vector2(110, 150) * 16.0
    features._physics_process(0.016)
    var keeper_node: Node = null
    var boss_node: Node = null
    for enemy in get_nodes_in_group("enemies"):
        if enemy.entity_id == FEATURES.keeper(id):
            keeper_node = enemy
        if enemy.entity_id == DUNGEONS.boss_id(id):
            boss_node = enemy
    var keeper_level: int = keeper_node.level
    var boss_level: int = boss_node.level
    var boss_hp: int = boss_node.get_node("Health").maximum
    actor.global_position = world.dungeon_gates.mouth_position(id) + Vector2(0, 10)
    _check(session.apply_action(actor, "dungeon", {"operation": "enter", "id": id, "heroic": true}) and features.heroic(id), "Entering an empty dungeon on Heroic")
    _check(keeper_node.level == keeper_level + DUNGEONS.HEROIC_LEVELS and boss_node.level == boss_level + DUNGEONS.HEROIC_LEVELS and boss_node.get_node("Health").maximum > boss_hp, "Heroic creatures and boss are eight levels stronger")
    actor.global_position = world.dungeon_gates.mouth_position(id) + Vector2(0, 10)
    session.apply_action(actor, "dungeon", {"operation": "enter", "id": "thornwood_hollow", "heroic": true})
    _check(not features.heroic("thornwood_hollow"), "Heroic needs the right cave mouth")
    items = actor.gear.items.size()
    world.quests.on_event(actor, "boss", {"id": DUNGEONS.boss_id(id)})
    _check(actor.gear.items.size() == items + 1 and int(actor.gear.items[-1].rarity) == 4 and preload("res://scripts/progression/achievements.gd").has(actor, "heroic_first"), "A heroic boss pays a Legendary piece (and Heroic Delver)")
    _check(not session.apply_action(actor, "dungeon", {"operation": "lever", "id": id, "index": "x"}) and not session.apply_action(actor, "dungeon", {"operation": "fly", "id": id}), "Malformed dungeon requests are refused")
    # Saved, then reset when empty.
    _check(session.save_world() == OK, "Saved with the dungeons' state")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("features.json")))
    _check(bool(raw.progression.dungeons[id].heroic) and bool(raw.progression.dungeons[id].levers[0]), "Mode and levers are saved")
    actor.global_position = Vector2(110, 150) * 16.0
    for _i in range(int(FEATURES.RESET_SECONDS) + 2):
        features._physics_process(1.0)
    _check(not features.door_open(id) and not features.heroic(id) and keeper_node.level == keeper_level, "An empty dungeon resets: levers up, normal mode")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Dungeon feature checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
