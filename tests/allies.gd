extends SceneTree
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _frames(count: int) -> void:
    for _i in range(count):
        await physics_frame
        await process_frame

func _run() -> void:
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var session: Node = root.get_node("GameSession")
    var player = world.get_local_player()
    var ally = world.get_node("GoblinAlly")
    player.position = Vector2(190, 360)
    await _frames(3)
    _check(InputMap.has_action("interact"), "Interaction must have a key binding")
    _check(ally.owner_id.is_empty() and ally.race == "Goblin", "Ally starts nameless and unclaimed")
    _check(not session.apply_action(player, "recruit", {"id": ally.entity_id}), "Live clearing threat must block recruitment")
    world.get_node("ForestGnasher/Health").take_damage(999)
    await _frames(3)
    player.position = Vector2(100, 360)
    _check(not ally.try_recruit(player), "Recruitment must require proximity")
    player.position = Vector2(190, 360)
    world._add_obstacle(Rect2(203, 340, 2, 40))
    var wall := world.get_child(world.get_child_count() - 1)
    await _frames(3)
    _check(not ally.try_recruit(player), "Terrain must block recruitment")
    wall.queue_free()
    await _frames(3)
    var reserves: float = player.get_node("Magicules").current
    _check(session.apply_action(player, "recruit", {"id": ally.entity_id}) and ally.owner_id == "host", "Host action must assign stable character ownership")
    _check(player.get_node("Magicules").current == reserves and ally.display_name.is_empty(), "Friendship itself costs no Magicules and does not name the ally")
    _check(not ally.try_recruit(player), "Recruitment cannot run twice")
    var guest = load("res://scenes/player/player.tscn").instantiate()
    guest.character_id = "guest"
    guest.local_controlled = false
    guest.position = ally.position
    world.add_child(guest)
    _check(not ally.try_recruit(guest) and ally.owner_id == "host", "Another player cannot steal a claimed ally")
    var before: Vector2 = ally.position
    player.position = Vector2(300, 360)
    await _frames(30)
    _check(ally.position.x > before.x + 10, "Ally must follow its owner")
    world.remove_child(player)
    before = ally.position
    await _frames(20)
    _check(ally.position.is_equal_approx(before) and ally.owner_id == "host", "Disconnected owner must leave an idle ally with ownership retained")
    world.add_child(player)
    world.bind_local_player(player)
    guest.queue_free()
    await _frames(3)
    var data := CODEC.capture_entities(world)
    data.merge({"version": STORE.VERSION, "world_id": "ally_world", "players": {"host": CODEC.capture_player(player)}, "progression": world.progression.duplicate(true)})
    _check(STORE.validate(data), "Allied entity state must pass save validation")
    var saved_position: Vector2 = ally.position
    ally.owner_id = ""
    ally.position = Vector2(500, 360)
    CODEC.apply_entities(world, data, false)
    _check(ally.owner_id == "host" and ally.position.is_equal_approx(saved_position), "Save restoration must retain the ally and position")
    var invalid := data.duplicate(true)
    invalid.allies[0].owner = "unknown_player"
    _check(not STORE.validate(invalid), "Unknown saved owner must be rejected")
    var legacy := data.duplicate(true)
    legacy.version = 1
    legacy.erase("allies")
    var migrated: Variant = STORE.migrate(legacy)
    _check(STORE.validate(migrated) and migrated.allies.size() == 1 and migrated.allies[0].owner == "", "Existing version-1 worlds must gain the unclaimed ally through migration")
    player.position = ally.position - Vector2(30, 0)
    var hud = world.get_node("HUD")
    hud._ally_dialog.open_nearest()
    _check(paused and hud._ally_dialog.visible and hud._ally_dialog._details.text.contains("Joined you"), "Interaction UI must show actual ownership and pause only offline")
    hud.open_inventory()
    _check(not hud._modal.visible, "Inventory must not stack over the ally dialog")
    hud._ally_dialog.close_dialog()
    _check(not paused, "Closing dialogue must restore gameplay")
    print("Ally checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
