extends SceneTree
## World events (M11d): meteor showers (warning circles, damage where they land, meteorites to
## collect), town invasions (won by defeating every invader; rewards for defenders nearby),
## treasure goblins (flee, a sack of Zeni and gear); events end, are never saved, and their
## creatures do not respawn.
const EVENTS := preload("res://scripts/world/world_events.gd")
const ACH := preload("res://scripts/progression/achievements.gd")
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
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-events-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24818, dir.path_join("events.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    me.global_position = preload("res://scripts/world/world_map.gd").to_world(Vector2(110, 160))
    var events: Node = world.events
    _check(not events.active() and float(events.state.next) >= EVENTS.FIRST_DELAY - 5.0, "No event at first; the first one comes after a while")
    # Meteors.
    _check(events.start("meteors", me) and events.state.meteors.size() == EVENTS.METEORS and String(events.banner()).contains("Meteor"), "A meteor shower starts near a character")
    var meteor: Array = events.state.meteors[0]
    me.global_position = Vector2(float(meteor[0]), float(meteor[1]))
    var health: Node = me.get_node("Health")
    health.immunity_left = 0.0
    var before: int = health.current
    _check(not events.collect(me, 0), "A meteorite cannot be collected before it lands")
    events.state.clock = EVENTS.DURATION.meteors - float(meteor[2]) - 0.01
    events._physics_process(0.02)
    _check(bool(meteor[3]) and health.current < before, "Where a meteor lands, it hurts")
    var zeni: int = int(me.progression.zeni)
    _check(events.nearest_meteorite(me) == 0 and session.apply_action(me, "event", {"operation": "collect", "index": 0}) and int(me.progression.zeni) > zeni, "Collecting the meteorite pays Zeni and star metal")
    _check(not events.collect(me, 0), "...once")
    _check(int(ACH.stats(me).get("meteorites", 0)) == 1, "Meteorites count toward Stargazer")
    _check(session.save_world() == OK, "Saved during an event")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("events.json")))
    _check(not raw.has("events") and session.document().has("events"), "Events travel with snapshots but are never saved")
    events.state.clock = 0.01
    events._physics_process(0.02)
    _check(not events.active(), "The shower ends")
    # Invasion.
    _check(events.start("invasion", me) and events.creatures().size() == EVENTS.INVADERS, "A town invasion: eight invaders march on the nearest town")
    var town: Array = preload("res://scripts/world/world_map.gd").town(events.state.town)
    _check(not town.is_empty() and town[4] == "town", "...on a town's plaza (%s)" % (town[1] if not town.is_empty() else "?"))
    _check(events.creatures().all(func(creature): return creature.home.distance_to(events.at()) < 2.0 and creature.leash_radius >= 4000.0), "The invaders head for the plaza")
    _check(session.save_world() == OK and not JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("events.json"))).enemies.any(func(enemy): return String(enemy.id).begins_with("event_")), "Invaders are never saved")
    me.global_position = events.at()
    var items: int = me.gear.items.size()
    zeni = int(me.progression.zeni)
    events.state.clock = EVENTS.DURATION.invasion - 5.0
    for invader in events.creatures():
        invader.get_node("Health").take_damage(999999, me)
    await _frames(2)
    events._physics_process(0.02)
    _check(not events.active() and me.gear.items.size() > items and int(me.progression.zeni) > zeni and int(ACH.stats(me).get("invasions", 0)) == 1, "Every invader defeated: the defenders are rewarded")
    _check(not world.respawner.scheduled(String("event_gnasher_1")), "Event creatures do not respawn")
    # Treasure goblin.
    _check(events.start("goblin", me) and events.creatures().size() == 1 and events.creatures()[0].kind == "treasure_goblin", "A treasure goblin appears")
    var goblin: Node2D = events.creatures()[0]
    var start: Vector2 = goblin.global_position
    me.global_position = start + Vector2(30, 0)
    for _i in range(20):
        events._physics_process(0.05)
    _check(goblin.global_position.x < start.x - 5.0, "It runs away from you")
    items = me.gear.items.size()
    zeni = int(me.progression.zeni)
    goblin.get_node("Health").take_damage(999999, me)
    await _frames(3)
    _check(int(me.progression.zeni) > zeni + 100 and me.gear.items.size() > items and ACH.has(me, "goblin_slayer") and not events.active(), "Caught: a sack of Zeni, gear, Goblin Slayer; the event ends")
    events.start("goblin", me)
    events.state.clock = 0.01
    events._physics_process(0.02)
    _check(not events.active() and events.creatures().is_empty(), "An uncaught goblin escapes")
    _check(not session.apply_action(me, "event", {"operation": "loot", "index": 0}), "Malformed event requests are refused")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("World event checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
