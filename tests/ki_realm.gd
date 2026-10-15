extends SceneTree
## M4.7 the Ki Realm (user plan): hidden from the normal maps, reached only through the secret
## hermit in Sakura Vale (level 15 and the right answer), the guide back; mentors teaching the ki
## attacks and the Kaio Surge for Zeni; transformations (damage, speed, Magicule drain); the seven
## wish orbs and the four wishes (then the orbs rest and scatter); the tournament (five rounds in
## the ring, the champion's Golden Aura); saves, forgeries and the v25 -> v26 migration.
const MAP := preload("res://scripts/world/world_map.gd")
const REALM := preload("res://scripts/realm/realm_catalogue.gd")
const KI_REALM := preload("res://scripts/realm/ki_realm.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
const SKILLS := preload("res://scripts/skills/skill_catalogue.gd")
const EFFECTS := preload("res://scripts/skills/skill_effects.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
var checks := 0
var failures := 0
var world: Node2D
var session: Node
var actor: CharacterBody2D

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

func _at(tile: Vector2, offset: Vector2 = Vector2(0, 10)) -> void:
    actor.global_position = MAP.to_world(tile) + offset

func _realm() -> Node:
    return world.realm

func _run() -> void:
    session = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-realm-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24720, dir.path_join("realm.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    actor = world.get_local_player()
    var realm := _realm()
    # --- The world
    _check(MAP.in_realm(MAP.to_world(REALM.ARRIVAL_TILE)) and not MAP.in_realm(MAP.to_world(REALM.HERMIT_TILE)) and MAP.region_at(MAP.to_world(REALM.HERMIT_TILE)) == MAP.Region.SAKURA_VALE, "The hermit lives in Sakura Vale; the arrival lies inside the hidden realm")
    _check(MAP.region_at(MAP.to_world(REALM.ARRIVAL_TILE)) == MAP.Region.KI_REALM and MAP.town("dome_city")[1] == "Dome City" and MAP.town("martial_grounds")[4] == "village", "Dome City, Hermit Atoll and the World Martial Grounds stand in the Ki Realm")
    var spots_ok := true
    for tile in REALM.ORB_SPOTS + [REALM.ALTAR_TILE, REALM.ARRIVAL_TILE, REALM.GUIDE_TILE, REALM.ANNOUNCER_TILE]:
        spots_ok = spots_ok and MAP.in_realm(MAP.to_world(tile)) and not MAP.solid(int(tile.x), int(tile.y))
    for entry in REALM.MENTORS:
        spots_ok = spots_ok and MAP.in_realm(MAP.to_world(entry[3])) and not MAP.solid(int(entry[3].x), int(entry[3].y))
    _check(spots_ok and REALM.ORB_SPOTS.size() >= REALM.ORB_COUNT, "Mentors, orb spots, the altar and the arena's announcer stand on open realm ground")
    var foes_ok := true
    for kind in REALM.FOES:
        var foe = load(CODEC.ENEMY_SCENES[kind]).instantiate()
        foes_ok = foes_ok and foe.specimen == null and foe.kind == kind
        foe.free()
    _check(foes_ok and REALM.FOES.size() == 8, "Eight realm foes (dinosaurs, fighters, androids, the Demon King) that cannot be analysed")
    var ki_ok := true
    for id in ["ki_blast", "turtle_wave", "ki_disc", "spirit_orb"]:
        var skill: Resource = load(SKILLS.SKILLS[id])
        ki_ok = ki_ok and skill.tier == "Unique" and SKILLS.scrollable(id) and skill.damage > 0
    _check(ki_ok and EFFECTS.effects("turtle_wave").get("reach", 0.0) > EFFECTS.effects("ki_blast").get("reach", 0.0) and EFFECTS.effects("spirit_orb").has("area"), "Four ki attacks: Ki Blast (fast), Turtle Wave (long charged beam), Ki Disc (piercing), Spirit Orb (huge area)")
    # --- The hermit
    _at(REALM.HERMIT_TILE)
    LEVELING.grant(actor, LEVELING.xp_for_level(14) - int(actor.progression.experience))
    _check(realm.nearest_person(actor) == "secret_hermit" and not realm.answer_hermit(actor, REALM.HERMIT_RIGHT) and not MAP.in_realm(actor.global_position), "Below level 15 the hermit sends you away")
    LEVELING.grant(actor, LEVELING.xp_for_level(18) - int(actor.progression.experience))
    _check(int(actor.progression.level) == 18, "Leveled to 18")
    var wrong := (REALM.HERMIT_RIGHT + 1) % REALM.HERMIT_ANSWERS.size()
    _check(not realm.answer_hermit(actor, wrong) and not MAP.in_realm(actor.global_position), "A wrong answer gets nothing")
    _check(session.apply_action(actor, "realm", {"operation": "answer", "id": str(REALM.HERMIT_RIGHT)}) and MAP.in_realm(actor.global_position), "The right answer (level 15+) folds the world: you stand in the Ki Realm")
    # --- Maps
    var hud = world.get_node("HUD")
    hud.world_map.open()
    await _frames(1)
    _check(hud.world_map._title.text.ends_with("KI REALM") and hud.world_map._view.size == Vector2(MAP.REALM_RECT.size), "Inside the realm the map shows only the realm")
    hud.world_map.close()
    await _frames(1)
    # --- Mentors
    var mentor: Array = REALM.mentor("spire_sage")
    _at(mentor[3])
    actor.progression.zeni = 100
    _check(not realm.learn(actor, "spire_sage") and not actor.get_node("SkillBook").knows(&"ki_blast"), "A mentor wants his fee")
    actor.progression.zeni = 50000
    _check(session.apply_action(actor, "realm", {"operation": "learn", "id": "spire_sage"}) and actor.get_node("SkillBook").knows(&"ki_blast") and actor.zeni() == 50000 - int(mentor[7]), "The Spire Sage teaches the Ki Blast for %d Zeni" % mentor[7])
    _check(not realm.learn(actor, "spire_sage"), "A lesson is learned only once")
    _at(REALM.mentor("guardian")[3])
    _check(realm.learn(actor, "guardian") and actor.get_node("SkillBook").knows(&"spirit_orb"), "The Guardian teaches the Spirit Orb at level 18")
    _at(REALM.mentor("mountain_master")[3])
    _check(realm.learn(actor, "mountain_master") and "kaio_surge" in actor.progression.auras, "The Mountain Master teaches the Kaio Surge")
    # --- Transformations
    var base_speed: float = actor.current_speed()
    actor.get_node("Magicules")._current = actor.get_node("Magicules").maximum
    _check(session.apply_action(actor, "aura", {"operation": "toggle"}) and actor.aura() == "kaio_surge" and is_equal_approx(actor.aura_damage(), 1.3), "X powers up: Kaio Surge (x1.3 damage)")
    _check(actor.current_speed() > base_speed, "A transformation makes you faster")
    var before: float = actor.get_node("Magicules").current
    await _frames(30)
    _check(actor.get_node("Magicules").current < before, "A transformation drains Magicules")
    _check(session.apply_action(actor, "aura", {"operation": "toggle"}) and actor.aura().is_empty(), "X again powers down")
    # --- Wish orbs
    var bag: Node = actor.get_node("Inventory")
    for index in range(REALM.ORB_COUNT):
        actor.global_position = MAP.to_world(REALM.ORB_SPOTS[int(realm.state.orbs[index])]) + Vector2(8, 8)
        session.apply_action(actor, "realm", {"operation": "orb", "id": str(index)})
    var held := 0
    for index in range(REALM.ORB_COUNT):
        held += bag.count_of(REALM.orb_id(index))
    _check(held == REALM.ORB_COUNT and realm.state.orbs.all(func(spot): return int(spot) == -1), "All seven orbs found and carried in the bag")
    _check(TRADE.price(REALM.orb_id(0)) == 0 and not session.apply_action(actor, "discard", {"id": REALM.orb_id(0)}), "Orbs cannot be sold or thrown away")
    _at(REALM.ALTAR_TILE)
    var points: int = int(actor.progression.skill_points)
    _check(realm.nearest_person(actor) == "altar" and session.apply_action(actor, "realm", {"operation": "wish", "id": "points"}) and int(actor.progression.skill_points) == points + REALM.WISH_POINTS and int(actor.progression.bonus_points) == REALM.WISH_POINTS, "A wish for skill points: +3 to spend")
    _check(bag.count_of(REALM.orb_id(0)) == 0 and float(realm.state.rest_until) > 0.0 and not realm.wish(actor, "zeni"), "The orbs are spent and rest for an hour")
    world.progression.world_time = float(realm.state.rest_until) + 1.0
    await _frames(2)
    _check(realm.state.orbs.all(func(spot): return int(spot) >= 0) and float(realm.state.rest_until) == 0.0 and int(realm.state.scatter) == 1, "An hour later they glow again at new spots")
    # The other wishes (orbs handed over directly).
    for choice in ["zeni", "aura", "item"]:
        for index in range(REALM.ORB_COUNT):
            bag.add_material(REALM.orb_id(index), 1)
        var zeni: int = actor.zeni()
        var items: int = actor.gear.items.size()
        var wished: bool = realm.wish(actor, choice)
        match choice:
            "zeni":
                _check(wished and actor.zeni() == zeni + REALM.WISH_ZENI, "A wish for Zeni: %d" % REALM.WISH_ZENI)
            "aura":
                _check(wished and "golden_aura" in actor.progression.auras, "A wish for power: the next transformation")
            "item":
                _check(wished and actor.gear.items.size() == items + 1 and int(actor.gear.items[-1].rarity) == 4, "A wish for treasure: a Legendary item")
    # --- Tournament
    actor.progression.auras.erase("golden_aura")
    _at(REALM.ANNOUNCER_TILE)
    var zeni_before: int = actor.zeni()
    _check(session.apply_action(actor, "realm", {"operation": "enter", "id": ""}) and actor.zeni() == zeni_before - REALM.ENTRY_FEE and realm.state.tournament.fighter == "host", "Entering the tournament costs %d Zeni" % REALM.ENTRY_FEE)
    var first: Node = world.entity_by_id("tourney_0")
    _check(first != null and first.kind == REALM.ROUNDS[0][0] and not first.drops_rewards and first.level == REALM.ROUNDS[0][2], "Round one: a Gi Fighter in the ring")
    for round_index in range(REALM.ROUNDS.size()):
        var foe: Node = world.entity_by_id("tourney_%d" % round_index)
        if foe == null:
            break
        foe.set_physics_process(false)
        foe.get_node("Health").take_damage(99999)
        actor.global_position = REALM.ring_centre()
        await _frames(2)
    _check(actor.progression.champion and "golden_aura" in actor.progression.auras and actor.zeni() == zeni_before - REALM.ENTRY_FEE + REALM.PRIZE and realm.state.tournament.fighter == "", "Five wins: champion, %d Zeni and the Golden Aura" % REALM.PRIZE)
    _at(REALM.ANNOUNCER_TILE)
    _check(session.apply_action(actor, "realm", {"operation": "enter", "id": ""}), "A champion may fight again")
    actor.global_position = REALM.ring_centre() + Vector2(400, 0)
    await _frames(2)
    _check(realm.state.tournament.fighter == "" and world.entity_by_id("tourney_0") == null, "Leaving the ring loses the bout (the opponent leaves)")
    # --- Guide back
    _at(REALM.GUIDE_TILE)
    _check(session.apply_action(actor, "realm", {"operation": "leave", "id": ""}) and not MAP.in_realm(actor.global_position), "The guide sends you back to the hermit")
    _check(not session.apply_action(actor, "realm", {"operation": "fly", "id": ""}) and not session.apply_action(actor, "realm", {"operation": "learn", "id": "x".repeat(40)}), "Malformed realm requests are rejected")
    # --- Saves
    var document: Dictionary = CODEC.capture_entities(world)
    document.merge({"version": STORE.VERSION, "world_id": "realm", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    _check(STORE.validate(document.duplicate(true)), "Transformations, wish points, the title and the orbs save")
    var forgeries: Array = []
    for change in [["auras", ["super_mode"]], ["aura", "golden_aura_2"], ["bonus_points", 99], ["champion", "yes"]]:
        var forged: Dictionary = document.duplicate(true)
        forged.players.host.progression[change[0]] = change[1]
        forgeries.append(STORE.validate(forged))
    var orbs_forged: Dictionary = document.duplicate(true)
    orbs_forged.realm.orbs = [0, 0, 1, 2, 3, 4, 5]
    forgeries.append(STORE.validate(orbs_forged))
    _check(not forgeries.has(true), "Unknown or unlearned transformations, too many wish points, a bad title and doubled orbs are rejected")
    var legacy: Dictionary = document.duplicate(true)
    legacy.version = 25
    legacy.erase("realm")
    for key in ["auras", "aura", "bonus_points", "champion"]:
        legacy.players.host.progression.erase(key)
    legacy.players.host.progression.skill_points = int(legacy.players.host.progression.skill_points) - REALM.WISH_POINTS
    var migrated: Variant = STORE.migrate(legacy)
    _check(migrated is Dictionary and migrated.version == STORE.VERSION and migrated.players.host.progression.auras == [] and migrated.realm == KI_REALM.initial_state() and STORE.validate(migrated), "v25 worlds: no transformations yet, the orbs at their first spots")
    # --- The bigger realm (v31): old worlds' realm creatures and characters move over.
    var old_world: Dictionary = document.duplicate(true)
    old_world.version = 30
    old_world.enemies = old_world.enemies.filter(func(enemy): return enemy.id != "ki_bear_1")
    for enemy in old_world.enemies:
        if enemy.id == "raptor_1":
            enemy.position = [-2560.0 + (-330) * 16.0, -1536.0 + (-160) * 16.0]
            enemy.home = enemy.position.duplicate()
    old_world.players.host.position = [-2560.0 + (-262) * 16.0, -1536.0 + (-165) * 16.0]
    var moved: Variant = STORE.migrate(old_world)
    var raptor: Dictionary = moved.enemies.filter(func(enemy): return enemy.id == "raptor_1")[0] if moved is Dictionary else {}
    _check(moved is Dictionary and moved.version == STORE.VERSION and MAP.in_realm(Vector2(raptor.home[0], raptor.home[1])) and Vector2(raptor.home[0], raptor.home[1]).distance_to(MAP.to_world(Vector2(-1150, -30))) < 20.0 and moved.enemies.any(func(enemy): return enemy.id == "ki_bear_1") and Vector2(moved.players.host.position[0], moved.players.host.position[1]).distance_to(MAP.to_world(REALM.ARRIVAL_TILE)) < 1.0 and STORE.validate(moved), "v30 worlds: realm creatures move to the bigger realm, new ones arrive, characters there move to Dome City")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Ki Realm checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
