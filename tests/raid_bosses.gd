extends SceneTree
## Raid bosses and the level cap (M7a): twelve bosses in open arenas, phases with telegraphed
## attacks that hurt whoever stands inside, HP growing with the characters present, a reset when
## everyone leaves, personal loot, uniques, XP and Zeni for helpers, a long respawn; level cap 50
## (levels 1-20 unchanged); the world map shows each region's level range.
const BOSS := preload("res://scripts/bosses/boss_catalogue.gd")
const BOSS_ITEMS := preload("res://scripts/bosses/boss_items.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const REGION := preload("res://scripts/world/region_content.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const FX := preload("res://scripts/bosses/boss_fx.gd")
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
    # Level cap.
    _check(LEVELING.LEVEL_CAP == 50 and LEVELING.level_for(LEVELING.max_experience()) == 50, "The level cap is 50")
    _check(LEVELING.xp_for_level(20) == int(round(100.0 * pow(19, 2.8))) and LEVELING.xp_for_level(21) > LEVELING.xp_for_level(20) and LEVELING.xp_for_level(50) - LEVELING.xp_for_level(49) > LEVELING.xp_for_level(21) - LEVELING.xp_for_level(20), "Levels 1-20 keep their curve; each level beyond costs a little more")
    _check(LEVELING.defeat_xp(30, 2) > 2 * LEVELING.defeat_xp(15, 2), "Creatures above level 20 give much more XP")
    # Catalogue.
    var arenas_ok := true
    var data: Dictionary = MAP.data()
    for id in BOSS.RAID:
        var tile: Vector2 = BOSS.RAID[id][3]
        arenas_ok = arenas_ok and not MAP.solid(int(tile.x), int(tile.y)) and data.ocean[MAP.vertex_index(int(tile.x), int(tile.y))] == 0
    _check(BOSS.RAID.size() >= 12 and arenas_ok, "Twelve raid bosses, every arena on land")
    var uniques_ok := true
    var rng := RandomNumberGenerator.new()
    rng.seed = 9
    for id in BOSS.RAID:
        for unique in BOSS.RAID[id][8]:
            uniques_ok = uniques_ok and GEAR.BASES.has(unique) and GEAR.valid_item(GEAR.roll(unique, maxi(4, int(GEAR.BASES[unique].min_rarity)), rng))
    _check(uniques_ok, "Every boss's uniques are valid items")
    _check(GEAR.BASES.boss_overlord_edge.stats.damage[0] > GEAR.BASES.boss_matriarch_fang.stats.damage[0] * 2, "Uniques of higher bosses are much stronger")
    var drops_ok := true
    var sources := preload("res://scripts/items/gear_sources.gd")
    for _i in range(400):
        drops_ok = drops_ok and not GEAR.BASES[sources.roll_chest(rng, 20).base].get("boss", false)
    _check(drops_ok, "Boss uniques never drop from chests or creatures")
    _check(REGION.range_text("Thornwood").begins_with("Lv ") and REGION.range_text("The Ki Realm").contains("–"), "Regions know their level range (%s)" % REGION.range_text("Thornwood"))
    # The world: bosses in their arenas.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-boss-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24799, dir.path_join("boss.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        if not enemy.is_in_group("raid_bosses"):
            enemy.set_physics_process(false)
    var bosses: Array = get_nodes_in_group("raid_bosses")
    _check(bosses.size() == BOSS.RAID.size(), "Every raid boss stands in the world")
    var boss: Node2D = world.entity_by_id("boss_gnashmaw")
    _check(boss != null and boss.level == 11 and boss.get_node("Health").maximum > 1000 and boss.sprite_kind() == "gnasher", "Gnashmaw: level 11, huge health, a Gnasher's look")
    var actor = world.get_local_player()
    actor.progression.level = 30
    actor.progression.experience = LEVELING.xp_for_level(30)
    actor.progression.skill_points = 30
    var normal_hp: int = actor.get_node("Health").maximum
    actor.get_node("Health").maximum = 100000
    actor.get_node("Health").current = 100000
    actor.global_position = BOSS.centre("boss_gnashmaw") + Vector2(40, 0)
    world.terrain.ensure_props_at(actor.global_position)
    await _frames(10)
    _check(boss.challengers().size() == 1 and boss._group_scaled, "Stepping into the arena starts the fight")
    # Telegraphs: geometry and damage.
    var circle := {"shape": "circle", "at": [0.0, 0.0], "size": 50.0, "extra": [0.0, 0.0]}
    var ring := {"shape": "ring", "at": [0.0, 0.0], "size": 100.0, "extra": [40.0, 0.0]}
    var line := {"shape": "line", "at": [0.0, 0.0], "size": 30.0, "extra": [100.0, 0.0]}
    _check(FX.inside(circle, Vector2(30, 30)) and not FX.inside(circle, Vector2(60, 0)), "Circle zones")
    _check(FX.inside(ring, Vector2(70, 0)) and not FX.inside(ring, Vector2(20, 0)) and not FX.inside(ring, Vector2(120, 0)), "Ring zones: safe close to the boss and far away")
    _check(FX.inside(line, Vector2(50, 10)) and not FX.inside(line, Vector2(50, 20)) and not FX.inside(line, Vector2(130, 0)), "Line zones")
    var health: Node = actor.get_node("Health")
    var before: int = health.current
    world.boss_fx.zones = []
    boss._start_attack("slam")
    _check(world.boss_fx.zones.size() == 1 and boss.state == boss.State.WINDUP, "A slam is telegraphed first (the boss winds up)")
    world.boss_fx._physics_process(5.0)
    _check(health.current < before and world.boss_fx.zones.is_empty(), "The slam hurts whoever stands inside when it lands")
    actor.global_position = BOSS.centre("boss_gnashmaw") + Vector2(BOSS.radius("boss_gnashmaw") - 5, 0)
    health.immunity_left = 0.0
    before = health.current
    boss._start_attack("slam")
    world.boss_fx._physics_process(5.0)
    _check(health.current == before, "Out of the zone you take nothing")
    # Phases.
    var boss_health: Node = boss.get_node("Health")
    boss_health.immunity_left = 0.0
    boss_health.take_damage(int(boss_health.maximum * 0.4), actor)
    boss.state = boss.State.IDLE
    boss._attack_in = 99.0
    world.boss_fx.zones = []
    boss._physics_process(0.016)
    _check(boss.phase == 1 and world.boss_fx.zones.any(func(zone): return zone.shape == "ring"), "Below 66% the boss enters phase 2 with a ring attack")
    _check(not boss.credit.is_empty(), "Damage is credited")
    # Leaving resets the boss.
    actor.global_position = BOSS.centre("boss_gnashmaw") + Vector2(BOSS.radius("boss_gnashmaw") + 300, 0)
    boss._physics_process(0.016)
    _check(boss_health.current == boss_health.maximum and boss.credit.is_empty() and boss.phase == 0, "When everyone leaves the arena the boss heals and resets")
    # Defeat: XP, Zeni, personal loot, respawn.
    actor.global_position = BOSS.centre("boss_gnashmaw") + Vector2(40, 0)
    await _frames(3)
    var xp: int = int(actor.progression.experience)
    var zeni: int = actor.zeni()
    var items_before: int = actor.gear.items.size()
    boss_health.immunity_left = 0.0
    boss_health.take_damage(boss_health.current + 10, actor)
    await _frames(3)
    _check(boss.state == boss.State.DEFEATED and int(actor.progression.experience) > xp + 1500 and actor.zeni() > zeni + 500, "The defeat gives big XP and Zeni")
    # The drop lands at the helper's feet (and is picked up at once when they stand there).
    await _frames(5)
    var mine: Array = get_nodes_in_group("gear_pickups").filter(func(pickup): return pickup.owner_id == actor.character_id).map(func(pickup): return pickup.item)
    if actor.gear.items.size() > items_before:
        mine.append(actor.gear.items[-1])
    _check(mine.size() == 1 and int(mine[0].rarity) >= 3, "A personal Epic-or-better drop for the helper")
    _check(world.respawner.scheduled("boss_gnashmaw") and world.respawner.pending.filter(func(entry): return entry.id == "boss_gnashmaw")[0].remaining > BOSS.RESPAWN - 5.0, "The boss returns after 30 minutes")
    # Saves: bosses validate; older worlds get them.
    actor.get_node("Health").maximum = normal_hp
    actor.get_node("Health").current = normal_hp
    _check(session.save_world() == OK, "A world with bosses saves")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("boss.json")))
    _check(int(raw.version) == STORE.VERSION and raw.enemies.any(func(enemy): return enemy.id == "boss_majin"), "Saved with the bosses")
    var old: Dictionary = raw.duplicate(true)
    old.version = 32
    old.enemies = old.enemies.filter(func(enemy): return not BOSS.is_boss(enemy.id))
    old.respawns = old.respawns.filter(func(entry): return not BOSS.is_boss(entry.id))
    # An older (v33) world: realm creatures at their old, lower health; no Eastern Reaches yet.
    for enemy in old.enemies:
        if enemy.id == "raptor_1":
            enemy.maximum_hp = 100
            enemy.hp = 100
    old.enemies = old.enemies.filter(func(enemy): return not String(enemy.id).begins_with("storm_"))
    var migrated: Variant = STORE.migrate(old)
    var raptor: Array = migrated.enemies.filter(func(enemy): return enemy.id == "raptor_1") if migrated is Dictionary else []
    _check(not raptor.is_empty() and int(raptor[0].maximum_hp) == preload("res://scripts/enemies/forest_gnasher.gd").scaled_health(1, REGION.level_of("raptor_1", 1)) and migrated.enemies.any(func(enemy): return enemy.id == "storm_storm_bat_1"), "Older worlds: the Ki Realm's creatures rise to their new levels, the Eastern Reaches' creatures arrive")
    _check(migrated is Dictionary and BOSS.RAID.keys().all(func(id): return migrated.enemies.any(func(enemy): return enemy.id == id)) and STORE.validate(migrated), "v32 worlds get every boss and stay valid")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Raid boss checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
