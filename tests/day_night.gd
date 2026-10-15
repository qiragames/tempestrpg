extends SceneTree
## Day, night and weather (user request): a 24-minute game day from the shared world time, ambient
## light and night lights, region weather that changes every three game hours (the same on every
## peer), and its small effects: night creatures bite harder and give more XP, sandstorms slow,
## fog hides you, rain brings fish.
const DAY := preload("res://scripts/world/day_night.gd")
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

## The first world time at or after `from` when `region` has `wanted` weather (-1 if none soon).
func _time_with(region: String, wanted: String, from: float = 0.0) -> float:
    var period := DAY.DAY_SECONDS / 24.0 * DAY.WEATHER_HOURS
    for step in range(400):
        var time := from + step * period + 5.0
        if DAY.weather(region, time) == wanted:
            return time
    return -1.0

## A world time at a game hour.
func _at_hour(h: float) -> float:
    return fposmod(h - DAY.START_HOUR, 24.0) / 24.0 * DAY.DAY_SECONDS

func _run() -> void:
    _check(is_equal_approx(DAY.hour(0.0), 8.0) and DAY.clock_text(0.0) == "Day 1 · 08:00" and DAY.day(DAY.DAY_SECONDS) == 2, "The world starts at 08:00 on day 1; a day lasts 24 minutes")
    _check(DAY.is_night(_at_hour(23.0)) and DAY.is_night(_at_hour(3.0)) and not DAY.is_night(_at_hour(12.0)) and not DAY.is_night(_at_hour(19.0)), "Night is from 21:00 to 05:00")
    _check(DAY.ambient(_at_hour(12.0)).is_equal_approx(Color.WHITE) and DAY.ambient(_at_hour(0.0)).v < 0.7 and DAY.darkness(_at_hour(12.0)) == 0.0 and DAY.darkness(_at_hour(0.0)) > 0.9, "Bright noon, dark (but playable) midnight")
    var regions_ok := true
    for region in DAY.REGION_WEATHER:
        regions_ok = regions_ok and region in MAP.REGION_NAMES.values()
        for weather in DAY.REGION_WEATHER[region]:
            regions_ok = regions_ok and DAY.WEATHER.has(weather)
    _check(regions_ok, "Every region's weather table names real regions and weathers")
    _check(DAY.weather("Frostpeak", 1234.0) == DAY.weather("Frostpeak", 1234.0) and _time_with("Frostpeak", "snow") >= 0.0 and _time_with("Sunscorch Desert", "sandstorm") >= 0.0 and _time_with("Gloomveil", "gloom_mist") >= 0.0 and _time_with("Frostpeak", "sandstorm") < 0.0, "Snow in Frostpeak, sandstorms in the desert, mist in Gloomveil — never sand in the snow")
    _check(DAY.weather("The Underdeep", 99999.0) == "clear", "No weather underground")
    var changes := 0
    var last := DAY.weather("Thornwood", 0.0)
    for step in range(1, 40):
        var now := DAY.weather("Thornwood", step * DAY.DAY_SECONDS / 8.0)
        if now != last:
            changes += 1
        last = now
    _check(changes >= 5, "The weather changes over the days (%d changes)" % changes)
    # In a world.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-day-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24806, dir.path_join("day.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    var sky: Node = world.sky
    world.progression.world_time = _at_hour(12.0)
    await _frames(2)
    var noon: Color = sky.ambient.color
    var noon_light: float = sky._player_light.energy
    world.progression.world_time = _at_hour(0.5)
    await _frames(2)
    _check(sky.ambient.color.v < noon.v - 0.2 and sky._player_light.energy > noon_light + 0.3, "At night the world darkens and a soft light surrounds you")
    var hud: CanvasLayer = world.get_node("HUD")
    _check(String(hud.minimap.get_node("Clock").text).begins_with("Day "), "The clock under the minimap (%s)" % hud.minimap.get_node("Clock").text)
    # Sandstorms slow walking; rain brings fish sooner.
    actor.global_position = MAP.to_world(Vector2(-150, 110))
    world.terrain.ensure_props_at(actor.global_position)
    world.progression.world_time = _time_with("Sunscorch Desert", "clear")
    var clear_speed: float = actor.current_speed()
    world.progression.world_time = _time_with("Sunscorch Desert", "sandstorm")
    await _frames(2)
    _check(actor.current_speed() < clear_speed and sky.weather_id == "sandstorm" and sky._particles.emitting and sky._haze.visible, "A sandstorm: blowing sand, haze, slower walking")
    # Night creatures.
    var creature: Node2D = world.entity_by_id("thornwood_gnasher_1")
    world.progression.world_time = _at_hour(12.0)
    _check(not creature.night(), "Noon: no night")
    world.progression.world_time = _at_hour(23.0)
    _check(creature.night(), "Night has fallen for the creatures")
    var xp: int = int(actor.progression.experience)
    var zeni_level: int = creature.level
    creature.global_position = actor.global_position + Vector2(20, 0)
    creature.get_node("Health").immunity_left = 0.0
    creature.get_node("Health").take_damage(99999, actor)
    await _frames(3)
    var expected := int(round(preload("res://scripts/progression/leveling.gd").defeat_xp(zeni_level, creature.difficulty) * DAY.NIGHT_XP))
    _check(int(actor.progression.experience) - xp == expected, "Night kills give 10%% more XP (%d)" % (int(actor.progression.experience) - xp))
    # M9b: night and weather catches.
    var fishes := preload("res://scripts/professions/fish_catalogue.gd")
    var rng := RandomNumberGenerator.new()
    rng.seed = 21
    var by_day := {}
    var by_night := {}
    var in_storm := {}
    for _i in range(6000):
        by_day[fishes.pick("Verdant Isle", false, 3, 50, rng, false, "clear")] = true
        by_night[fishes.pick("Verdant Isle", false, 3, 50, rng, true, "clear")] = true
        in_storm[fishes.pick("Verdant Isle", false, 3, 50, rng, false, "storm")] = true
    _check(not by_day.has("lantern_angler") and by_night.has("lantern_angler") and in_storm.has("thunder_eel") and not by_day.has("thunder_eel") and not by_day.has("moonfish"), "Some fish only bite at night or in thunderstorms")
    _check(fishes.entries().any(func(row): return row[4] == "ghost_koi" and String(row[2]).contains("at night")), "The fish log says when they bite")
    # Night stalkers sleep by day.
    var stalker: Node2D = world.entity_by_id("night_meadow_a")
    _check(stalker != null and stalker.difficulty == 2 and stalker.level == 6, "A night stalker waits at every leveling spot (an elite, three levels above it)")
    world.progression.world_time = _at_hour(12.0)
    stalker.set_physics_process(true)
    await _frames(3)
    var hp: int = stalker.get_node("Health").current
    stalker.get_node("Health").take_damage(10, actor)
    _check(stalker.dormant() and not stalker.visible and stalker.get_node("CollisionShape2D").disabled and stalker.get_node("Health").current == hp, "By day it sleeps: hidden and untouchable")
    world.progression.world_time = _at_hour(23.0)
    await _frames(3)
    stalker.get_node("Health").immunity_left = 0.0
    stalker.get_node("Health").take_damage(10, actor)
    _check(not stalker.dormant() and stalker.visible and not stalker.get_node("CollisionShape2D").disabled and stalker.get_node("Health").current < hp, "At night it hunts")
    stalker.set_physics_process(false)
    # Night herbs.
    var plan: Array = world.terrain.planned_props()
    var bush := -1
    for index in range(plan.size()):
        if world.nodes.info(index).get("resource") == "herb_mint":
            bush = index
            break
    actor.global_position = world.nodes.work_point(bush) + Vector2(0, 6)
    world.terrain.ensure_props_at(actor.global_position)
    var herb_rng := RandomNumberGenerator.new()
    herb_rng.seed = 3
    for _i in range(200):
        world.nodes.regrow.clear()
        world.nodes.used.clear()
        world.nodes.strike(actor, bush, herb_rng)
    _check(actor.get_node("Inventory").count_of("herb_moonbloom") > 0, "Picking herbs at night turns up Moonblooms")
    # Saves: older worlds get the night stalkers.
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("day.json")))
    var old: Dictionary = raw.duplicate(true)
    old.version = 35
    old.enemies = old.enemies.filter(func(enemy): return not String(enemy.id).begins_with("night_"))
    old.respawns = old.respawns.filter(func(entry): return not String(entry.id).begins_with("night_"))
    var store := preload("res://scripts/persistence/save_store.gd")
    var migrated: Variant = store.migrate(old)
    _check(migrated is Dictionary and migrated.enemies.any(func(enemy): return enemy.id == "night_sky_b") and store.validate(migrated), "v35 worlds get the night stalkers")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Day and night checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
