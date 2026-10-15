extends SceneTree
## M4.5d (user decisions): harbours in every region; ferry tickets and the pass; your own ship
## (price only, summoned anywhere, a crew of up to four you invite; the ferry takes nobody along);
## tools used automatically (axe/pickaxe yields, fishing with a rod); mounts bought or tamed,
## faster on land, lost when hit or attacking; runes in sockets by rarity at the Smithy; augments
## in level slots at the Shrine; saves and the v23 -> v24 migration.
const MAP := preload("res://scripts/world/world_map.gd")
const TRAVEL := preload("res://scripts/travel/travel_catalogue.gd")
const UPGRADES := preload("res://scripts/items/upgrade_catalogue.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const CAMP := preload("res://scripts/settlement/first_camp.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
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

func _at(body: Node2D, position: Vector2) -> void:
    body.global_position = position
    world.terrain.ensure_props_at(position)

func _friend(id: String) -> CharacterBody2D:
    var other = load("res://scenes/player/player.tscn").instantiate()
    other.character_id = id
    other.local_controlled = false
    world.add_child(other)
    return other

func _run() -> void:
    session = root.get_node("GameSession")
    # --- Harbours (static)
    var harbours_ok := MAP.HARBOURS.size() == 9
    var regions := {}
    for entry in MAP.HARBOURS:
        var dock := Vector2i(entry[2])
        var end: Vector2i = dock + Vector2i(entry[3]) * MAP.PIER_LENGTH
        harbours_ok = harbours_ok and not MAP.solid(dock.x, dock.y) and not MAP.solid(end.x, end.y) and MAP.data().ocean[MAP.vertex_index(end.x, end.y)] == 1
        regions[MAP.region_at(MAP.to_world(entry[2]))] = true
    _check(harbours_ok and regions.size() >= 8 and MAP.HARBOURS.filter(func(entry): return entry[4]).size() == 3, "Nine harbours with walkable piers out to sea, in every region; shipwrights in three harbour towns")
    _check(TRAVEL.fare("sunfall", "amberhold") < TRAVEL.fare("sunfall", "cinderport") and TRAVEL.fare("sunfall", "amberhold") >= 20, "Ticket prices grow with the distance")
    # --- Hosted world
    var dir := OS.get_temp_dir().path_join("tempestrpg-travel-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24700, dir.path_join("travel.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    actor = world.get_local_player()
    var harbours = world.harbours
    _check(harbours.get_node_or_null("ferryman_rimehaven") != null and harbours.get_node_or_null("shipwright_cinderport") != null, "Every harbour has a ferryman; harbour towns a shipwright")
    # --- Tickets and the pass
    _at(actor, MAP.dock_position("dunemarch"))
    actor.progression["zeni"] = 1000
    var fare: int = TRAVEL.fare("dunemarch", "bogsend")
    _check(harbours.buy_ticket(actor, "dunemarch", "bogsend") and actor.get_node("Inventory").count_of(TRAVEL.ticket_id("bogsend")) == 1 and actor.zeni() == 1000 - fare, "A ticket for one harbour goes into the bag")
    _check(not harbours.sail(actor, "dunemarch", "hanamura"), "A ticket only takes you where it says")
    var friend := _friend("friend")
    _at(friend, MAP.dock_position("dunemarch") + Vector2(10, 0))
    await _frames(1)
    _check(harbours.sail(actor, "dunemarch", "bogsend") and actor.get_node("Inventory").count_of(TRAVEL.ticket_id("bogsend")) == 0 and harbours.nearest_harbour(actor) == "bogsend" and harbours.nearest_harbour(friend) == "dunemarch", "Sailing uses the ticket; the ferry takes nobody along")
    _check(harbours.buy_pass(actor, "bogsend") and harbours.has_pass(actor) and harbours.sail(actor, "bogsend", "cinderport") and harbours.sail(actor, "cinderport", "rimehaven"), "A ferry pass: unlimited trips")
    world.progression["world_time"] = float(world.progression.get("world_time", 0.0)) + TRAVEL.PASS_SECONDS + 1.0
    _check(not harbours.has_pass(actor) and not harbours.sail(actor, "rimehaven", "sunfall"), "The pass runs out after an hour of world time")
    # --- Your own ship
    _at(actor, MAP.dock_position("cinderport"))
    actor.progression["zeni"] = TRAVEL.SHIP_PRICE - 1
    _check(not harbours.buy_ship(actor, "cinderport"), "A ship costs %d Zeni" % TRAVEL.SHIP_PRICE)
    actor.progression["zeni"] = TRAVEL.SHIP_PRICE + 50
    _at(actor, MAP.dock_position("bogsend"))
    _check(not harbours.buy_ship(actor, "bogsend"), "Only shipwrights sell ships")
    _at(actor, MAP.dock_position("cinderport"))
    _check(harbours.buy_ship(actor, "cinderport") and harbours.owns_ship(actor) and actor.progression.ship.at == "cinderport" and actor.zeni() == 50, "Bought a ship at Cinderport")
    _at(actor, MAP.dock_position("sunfall"))
    _check(not harbours.sail(actor, "sunfall", "hanamura"), "The ship sails from where it lies")
    _check(harbours.summon(actor, "sunfall") and actor.progression.ship.at == "sunfall", "Summoned to Sunfall")
    await _frames(2)
    _check(harbours.get_node_or_null("Ship_host") != null and harbours.get_node("Ship_host").position.distance_to(MAP.berth_position("sunfall")) < 1.0, "Everyone sees the ship docked at the harbour")
    # Crew: invite characters standing next to you; up to four in all.
    var crew: Array = []
    for index in range(4):
        var mate := _friend("mate_%d" % index)
        _at(mate, actor.global_position + Vector2(8 + index * 6, 6))
        crew.append(mate)
    await _frames(1)
    _check(harbours.invite(actor, "sunfall", "mate_0") and harbours.accept(crew[0]) and harbours.invite(actor, "sunfall", "mate_1") and harbours.accept(crew[1]) and harbours.invite(actor, "sunfall", "mate_2") and harbours.accept(crew[2]), "Three characters accept the owner's invitation")
    _check(not harbours.invite(actor, "sunfall", "mate_3"), "The ship takes four characters in all")
    _check(not harbours.accept(crew[3]), "An uninvited character cannot come aboard")
    _check(harbours.sail(actor, "sunfall", "hanamura") and crew.slice(0, 3).all(func(mate): return harbours.nearest_harbour(mate) == "hanamura") and harbours.nearest_harbour(crew[3]) == "sunfall" and actor.progression.ship.at == "hanamura", "The owner sails with the crew; the ship now lies at the destination")
    for mate in crew:
        world.remove_child(mate)
        mate.queue_free()
    world.remove_child(friend)
    friend.queue_free()
    # --- Tools
    _at(actor, world.trade.merchant_position("merchant_brookhaven") + Vector2(-14, 0))
    actor.progression["zeni"] = 5000
    world.trade.stock("merchant_brookhaven")
    _check(world.trade.buy(actor, "merchant_brookhaven", TRAVEL.tool_item("axe", 1)) and actor.progression.tools.axe == 1 and not world.trade.buy(actor, "merchant_brookhaven", TRAVEL.tool_item("axe", 1)), "Buying an axe: owned (not equipped), and not twice")
    _check(world.trade.buy(actor, "merchant_brookhaven", TRAVEL.tool_item("rod", 1)) and actor.progression.tools.rod == 1, "Bought a fishing rod")
    var camp = world.camp
    camp.state.founded = true
    camp.state.founder = actor.character_id
    var wood_site: String = camp.sites.keys().filter(func(id): return camp.sites[id].resource == "wood")[0]
    var amount: int = camp.state.deposits[wood_site]
    var wood_before: int = camp.state.wood
    _at(actor, camp.sites[wood_site].position)
    _check(camp.transact(actor, "gather", wood_site) and camp.state.wood == wood_before + amount + int(round(amount * 0.25)) and CAMP.valid_state(camp.state, {"host": true}, camp.sites), "The axe gathers 25% more wood, and the camp's books still add up")
    # Fishing: face the water with a rod.
    _at(actor, MAP.dock_position("sunfall"))
    actor.facing = Vector2(MAP.HARBOURS[0][3])
    _check(actor.cast_line() and actor.fishing_bite_in > 0.0, "Casting at the water from the pier")
    _check(not actor.reel_in() and actor.fishing_bite_in == -INF, "Pulling too early loses the fish")
    actor.cast_line()
    actor._tick_fishing(actor.fishing_bite_in + 0.1)
    var fish_before: int = actor.get_node("Inventory").total_units()
    # M6b: land it by pressing while the marker is in the zone (as many hits as it needs).
    var landed := false
    for _press in range(6):
        if actor.reel.is_empty():
            break
        actor.reel.centre = preload("res://scripts/professions/fish_catalogue.gd").marker(float(actor.reel.t), float(actor.reel.speed))
        landed = actor.reel_in() and actor.reel.is_empty()
    _check(landed and actor.get_node("Inventory").total_units() == fish_before + 1, "Pulling in during the bite catches a fish")
    actor.cast_line()
    actor.global_position += Vector2(30, 0)
    actor._tick_fishing(0.1)
    _check(actor.fishing_bite_in == -INF, "Walking away ends the cast")
    # --- Mounts
    _at(actor, world.trade.merchant_position("merchant_brookhaven") + Vector2(-14, 0))
    var speed_on_foot: float = actor.effective_speed() if actor.has_method("effective_speed") else 0.0
    _check(world.trade.buy(actor, "merchant_brookhaven", TRAVEL.mount_item("horse")) and "horse" in actor.progression.mounts, "Bought a horse at the Brookhaven stable")
    _check(actor.toggle_mount() and actor.riding() == "horse" and is_equal_approx(actor.mount_speed(), 1.6), "Riding the horse: +60% speed")
    actor.get_node("Health").take_damage(1)
    _check(actor.riding().is_empty(), "A hit throws you off")
    actor.toggle_mount()
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    actor.get_node("MeleeAttack").attack(Vector2.RIGHT)
    _check(actor.riding().is_empty(), "Attacking dismounts")
    var lion: Array = TRAVEL.WILD_MOUNTS.filter(func(entry): return entry[1] == "lion")[0]
    _at(actor, MAP.to_world(lion[2]))
    _check(not actor.tame(lion[0]), "Taming needs the animal's favourite offering")
    var tamed := false
    for _attempt in range(60):
        actor.get_node("Inventory").add_material("viper_scale", 3)
        actor._tame_cooldown = 0.0
        actor.tame(lion[0])
        if "lion" in actor.progression.mounts:
            tamed = true
            break
    _check(tamed, "Offering viper scales eventually tames a desert lion")
    # --- Runes and augments (at the camp's Smithy and Shrine, paid for legally)
    for id in camp.sites:
        if camp.state.deposits[id] > 0:
            camp.harvest(id)
    camp.state.essence += 6
    camp.state.essence_offered += 6
    for id in ["hut_1", "forge_1", "smithy_1", "shrine_1"]:
        camp.complete(id)
    var rng := RandomNumberGenerator.new()
    rng.seed = 5
    var legendary: Dictionary = GEAR.roll("scale_mail", 4, rng)
    var common: Dictionary = GEAR.roll("padded_vest", 0, rng)
    actor.add_item(legendary)
    actor.add_item(common)
    actor.equip(legendary.id, "body")
    var hp_before: int = actor.get_node("Health").maximum
    actor.get_node("Inventory").add_material("rune_vigor", 3)
    _at(actor, Vector2(480, 340))
    _check(not actor.socket_rune("rune_vigor"), "Runes are socketed at the Smithy")
    _at(actor, CAMP.STRUCTURES.smithy_1.site + Vector2(0, 30))
    _check(actor.socket_rune("rune_vigor") and actor.socket_rune("rune_vigor") and actor.get_node("Health").maximum == hp_before + 24 and GEAR.valid_item(actor.item_by_id(legendary.id)), "A Legendary item takes two runes (+12 HP each, while worn)")
    _check(not actor.socket_rune("rune_vigor"), "No free socket left")
    actor.unequip("body")
    _check(actor.get_node("Health").maximum == hp_before - int(legendary.stats.hp), "Taking the item off removes its runes' bonus too")
    actor.get_node("Inventory").add_material("rune_ward", 1)
    _check(actor.socket_rune("rune_ward", legendary.id, 0) and actor.item_by_id(legendary.id).runes == ["rune_ward", "rune_vigor"], "Replacing a rune destroys the old one")
    var forged_item: Dictionary = common.duplicate(true)
    forged_item["runes"] = ["rune_vigor"]
    _check(not GEAR.valid_item(forged_item), "Common gear has no socket")
    actor.get_node("Inventory").add_material("aug_vitality", 1)
    actor.get_node("Inventory").add_material("aug_absorb", 1)
    _at(actor, CAMP.STRUCTURES.shrine_1.site + Vector2(0, 26))
    actor.progression["zeni"] = 1000
    _check(not actor.install_augment("aug_vitality"), "Augment slots open at level 5")
    LEVELING.grant(actor, LEVELING.xp_for_level(5) - int(actor.progression.experience))
    var hp_now: int = actor.get_node("Health").maximum
    _check(actor.install_augment("aug_vitality") and actor.get_node("Health").maximum == hp_now + 20 and actor.zeni() == 1000 - UPGRADES.INSTALL_COST, "Installed a Vitality Augment at the Shrine (+20 HP, 100 Zeni)")
    _check(actor.install_augment("aug_absorb") and actor.progression.augments == ["aug_absorb"] and actor.get_node("Inventory").count_of("aug_vitality") == 1 and actor.get_node("Health").maximum == hp_now and is_equal_approx(actor.absorb_factor(), 0.75), "With one slot, a new augment replaces the old one (back to the bag); the Absorber speeds up analysis")
    # --- Saves
    var document: Dictionary = CODEC.capture_entities(world)
    document.merge({"version": STORE.VERSION, "world_id": "travel", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    _check(STORE.validate(document.duplicate(true)), "Ships, passes, tools, mounts, runes and augments save")
    var forgeries: Array = []
    for change in [["mount", "black_horse"], ["augments", ["aug_absorb", "aug_iron"]], ["tools", {"axe": 4, "pickaxe": 0, "rod": 1}], ["ship", {"owned": true, "at": "nowhere"}]]:
        var forged: Dictionary = document.duplicate(true)
        forged.players.host.progression[change[0]] = change[1]
        forgeries.append(STORE.validate(forged))
    _check(not forgeries.has(true), "Forged mounts, augments beyond the slots, tools beyond Master and unknown harbours are rejected")
    var legacy: Dictionary = document.duplicate(true)
    legacy.version = 23
    legacy.erase("harbours")
    legacy.camp.erase("tool_yield")
    legacy.camp.wood = int(legacy.camp.wood) - int(document.camp.tool_yield.wood)
    for key in ["ship", "ferry_pass_until", "tools", "mounts", "mount", "augments"]:
        legacy.players.host.progression.erase(key)
    legacy.players.host.erase("fishing")
    legacy.players.host.gear.items = legacy.players.host.gear.items.map(func(item): item.erase("runes"); return item)
    legacy.players.host.health.maximum = 120
    legacy.players.host.health.current = mini(int(legacy.players.host.health.current), 120)
    var migrated: Variant = STORE.migrate(legacy)
    _check(migrated is Dictionary and migrated.version == STORE.VERSION and migrated.players.host.progression.ship == {"owned": false, "at": ""} and migrated.players.host.progression.tools.rod == 0 and migrated.camp.tool_yield == {"wood": 0, "stone": 0} and migrated.harbours is Dictionary, "v23 worlds: no ship, pass, tools, mounts or augments yet; empty camp tool yield; harbours")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Travel checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
