extends SceneTree
## M4.5c trade (user decisions): Zeni from defeats (split by damage share), chests and sales; a
## defeat drops 10% of the purse into the pile; town merchants, hired camp staff and the hidden
## travelling merchant with restocking stock; buying and selling with every refusal rule; the
## draught and tonic with their shared cooldown; common and scroll-only skill scrolls; ferries;
## snapshot replication; saves and the v22 -> v23 migration.
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const CAMP := preload("res://scripts/settlement/first_camp.gd")
const SKILLS := preload("res://scripts/skills/skill_catalogue.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const REGION := preload("res://scripts/world/region_content.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
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

func _at(position: Vector2) -> void:
    actor.global_position = position
    world.terrain.ensure_props_at(position)

func _run() -> void:
    session = root.get_node("GameSession")
    # --- Catalogue
    _check(TRADE.zeni_for(1, 0) < TRADE.zeni_for(12, 0) and TRADE.zeni_for(5, 0) < TRADE.zeni_for(5, 1) and TRADE.zeni_for(5, 1) < TRADE.zeni_for(5, 2), "Zeni grows with creature level and tier")
    _check(TRADE.sell_price(100) == 30 and TRADE.price("healing_draught") == 25 and TRADE.price(TRADE.scroll_id("tempest_edge")) > 10 * TRADE.price(TRADE.scroll_id("frost_maul")), "Selling pays 30%; scroll-only skills cost far more than common scrolls")
    var all_skills := true
    for skill in TRADE.COMMON_SCROLLS + TRADE.RARE_SCROLLS:
        all_skills = all_skills and SKILLS.scrollable(skill)
    _check(all_skills and TRADE.RARE_SCROLLS.all(func(skill): return SKILLS.RULES[skill].has("scroll")), "Every scroll teaches a known skill; the rare ones teach skills found nowhere else")
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var town_stock: Array = TRADE.roll_stock(TRADE.merchant("merchant_brookhaven"), rng)
    var traveller_stock: Array = TRADE.roll_stock(TRADE.merchant("traveller"), rng)
    var smith_stock: Array = TRADE.roll_stock(TRADE.merchant("camp_smith"), rng)
    _check(TRADE.valid_stock(town_stock) and TRADE.valid_stock(traveller_stock) and TRADE.valid_stock(smith_stock), "Rolled stock is valid")
    _check(traveller_stock.filter(func(e): return e.kind == "gear").all(func(e): return int(e.item.rarity) >= 2) and smith_stock.all(func(e): return e.kind == "gear" or e.id.begins_with("rune_")), "The traveller sells Rare or better gear; the smith gear (and now and then a rune)")
    var rare_seen := 0
    var town_rare := 0
    for seed in range(400):
        rng.seed = seed
        rare_seen += int(TRADE.roll_stock(TRADE.merchant("traveller"), rng).any(func(e): return TRADE.is_rare_scroll(e.id)))
        town_rare += int(TRADE.roll_stock(TRADE.merchant("merchant_hanamura"), rng).any(func(e): return TRADE.is_rare_scroll(e.id)))
    _check(rare_seen > 80 and town_rare < rare_seen / 5 and town_rare < 40, "Scroll-only skills: about a third of traveller visits, very rarely a big town (%d / %d of 400)" % [rare_seen, town_rare])
    # --- Hosted world
    var dir := OS.get_temp_dir().path_join("tempestrpg-trade-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24690, dir.path_join("trade.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    actor = world.get_local_player()
    _check(actor.zeni() == 0 and actor.progression.has("zeni"), "Characters start with an empty purse")
    # Merchants stand in every town, on dry land.
    var stands := true
    for entry in TRADE.MERCHANTS:
        if entry[3] == "town":
            var tile := MAP.to_tile(world.trade.merchant_position(entry[0]))
            stands = stands and world.trade.available(entry[0]) and not MAP.solid(tile.x, tile.y) and not MAP.town_at(world.trade.merchant_position(entry[0])).is_empty()
    _check(stands, "A merchant stands in every town")
    await _frames(2)
    _check(world.trade.get_children().any(func(npc): return npc.get_meta("merchant", "") == "merchant_brookhaven"), "Shopkeepers are drawn")
    _check(not world.trade.available("camp_trader") and not world.trade.available("camp_smith") and not world.trade.available("traveller"), "No camp staff before hiring; the traveller has not arrived yet")
    # --- Zeni from a defeat, split by damage share
    var gnasher = GNASHER.instantiate()
    gnasher.entity_id = "trade_gnasher"
    gnasher.position = actor.position + Vector2(18, 0)
    world.add_child(gnasher)
    world.wire_enemy(gnasher)
    gnasher.set_physics_process(false)
    var friend = load("res://scenes/player/player.tscn").instantiate()
    friend.character_id = "friend"
    friend.local_controlled = false
    friend.position = actor.position + Vector2(0, 30)
    world.add_child(friend)
    await _frames(1)
    var health = gnasher.get_node("Health")
    health.take_damage(int(health.maximum * 0.7), actor)
    health.immunity_left = 0.0
    health.take_damage(health.maximum, friend)
    await _frames(2)
    var coins: int = TRADE.zeni_for(gnasher.level, gnasher.difficulty)
    _check(actor.zeni() + friend.zeni() >= coins - 1 and actor.zeni() > friend.zeni() and friend.zeni() > 0, "A defeat's Zeni is split by damage share (%d + %d of %d)" % [actor.zeni(), friend.zeni(), coins])
    world.remove_child(friend)
    friend.queue_free()
    # --- Buying
    _at(world.trade.merchant_position("merchant_brookhaven") + Vector2(-14, 0))
    await _frames(2)
    _check(world.trade.nearest_merchant(actor) == "merchant_brookhaven", "Standing beside a merchant finds it")
    var stock: Array = world.trade.stock("merchant_brookhaven")
    var draught: Dictionary = stock.filter(func(e): return e.id == "healing_draught")[0]
    actor.progression["zeni"] = 0
    _check(not world.trade.buy(actor, "merchant_brookhaven", "healing_draught"), "Buying without enough Zeni is refused")
    actor.progression["zeni"] = 500
    var before_count: int = int(draught.count)
    _check(world.trade.buy(actor, "merchant_brookhaven", "healing_draught") and actor.zeni() == 500 - TRADE.price("healing_draught") and actor.get_node("Inventory").count_of("healing_draught") == 1 and int(draught.count) == before_count - 1, "Buying pays Zeni, puts the good in the bag and lowers the stock")
    var gear_entry: Dictionary = stock.filter(func(e): return e.kind == "gear")[0]
    actor.progression["zeni"] = 99999
    _check(world.trade.buy(actor, "merchant_brookhaven", gear_entry.id) and not actor.item_by_id(gear_entry.id).is_empty() and int(gear_entry.count) == 0, "Gear can be bought once")
    _check(not world.trade.buy(actor, "merchant_brookhaven", gear_entry.id), "Sold-out entries are refused")
    _at(Vector2(480, 340))
    _check(not world.trade.buy(actor, "merchant_brookhaven", "healing_draught"), "Trading needs the merchant within reach")
    # --- Selling
    _at(world.trade.merchant_position("merchant_brookhaven") + Vector2(-14, 0))
    actor.get_node("Inventory").add_material("frost_pelt", 2)
    var purse: int = actor.zeni()
    _check(world.trade.sell(actor, "merchant_brookhaven", "bag", "frost_pelt") and actor.zeni() == purse + TRADE.sell_price(TRADE.price("frost_pelt")) and actor.get_node("Inventory").count_of("frost_pelt") == 1, "Selling a material pays 30% of its price")
    purse = actor.zeni()
    var bought: Dictionary = actor.item_by_id(gear_entry.id)
    _check(world.trade.sell(actor, "merchant_brookhaven", "gear", gear_entry.id) and actor.item_by_id(gear_entry.id).is_empty() and actor.zeni() == purse + TRADE.sell_price(TRADE.gear_price(bought, 4)), "Selling unequipped gear pays 30% of its value")
    var worn: Dictionary = GEAR.roll("cloth_cap" if GEAR.BASES.has("cloth_cap") else GEAR.BASES.keys()[0], 0, rng)
    actor.add_item(worn)
    actor.equip(worn.id, GEAR.BASES[worn.base].slot if GEAR.BASES[worn.base].slot != "accessory" else "accessory_1")
    _check(not world.trade.sell(actor, "merchant_brookhaven", "gear", worn.id) and not actor.item_by_id(worn.id).is_empty(), "Equipped gear cannot be sold")
    # --- Consumables
    actor.get_node("Health").current = 40
    _check(actor.use_good("healing_draught") and actor.get_node("Inventory").count_of("healing_draught") == 0 and actor.consumable_cooldown > 19.0, "Drinking a draught uses it up and starts the shared cooldown")
    actor.get_node("Inventory").add_material("magicule_tonic", 1)
    _check(not actor.use_good("magicule_tonic") and actor.get_node("Inventory").count_of("magicule_tonic") == 1, "The tonic waits for the shared cooldown")
    for _i in range(6):
        actor._tick_consumables(1.0)
    _check(actor.get_node("Health").current == 80, "The draught restores 40 HP over 5 s (not instantly)")
    actor.consumable_cooldown = 0.0
    actor.get_node("Magicules")._current = 10.0
    _check(actor.use_good("magicule_tonic"), "The tonic is drunk after the cooldown")
    for _i in range(6):
        actor._tick_consumables(1.0)
    _check(is_equal_approx(actor.get_node("Magicules").current, 50.0), "The tonic restores 40 Magicules over 5 s")
    # --- Scrolls
    var book = actor.get_node("SkillBook")
    actor.get_node("Inventory").add_material(TRADE.scroll_id("frost_maul"), 1)
    actor.get_node("Inventory").add_material(TRADE.scroll_id("tempest_edge"), 1)
    _check(actor.use_good(TRADE.scroll_id("frost_maul")) and book.knows(&"frost_maul") and "frost_maul" in book.evidence.scrolls and not "frost_bear" in book.evidence.analyzed, "A common scroll teaches its skill without analysis")
    _check(actor.use_good(TRADE.scroll_id("tempest_edge")) and book.knows(&"tempest_edge") and SKILLS.justified(book.known_ids(), book.evidence), "A rare scroll teaches a skill found nowhere else; saves accept it")
    actor.get_node("Inventory").add_material(TRADE.scroll_id("frost_maul"), 1)
    _check(not actor.use_good(TRADE.scroll_id("frost_maul")) and actor.get_node("Inventory").count_of(TRADE.scroll_id("frost_maul")) == 1, "A scroll for a known skill is kept")
    # --- Camp staff
    var camp = world.camp
    camp.state.founded = true
    camp.state.founder = actor.character_id
    # Pay for the buildings the legal way (saves check the camp's books).
    for id in camp.sites:
        camp.harvest(id)
    camp.state.essence += 3
    camp.state.essence_offered += 3
    for id in ["hut_1", "forge_1", "stall_1", "smithy_1"]:
        camp.complete(id)
    _check(camp.state.stall and camp.state.smithy, "The Market Stall and Smithy can be built (after the hut / forge)")
    _at(CAMP.STRUCTURES.stall_1.site + Vector2(0, 30))
    actor.progression["zeni"] = 100
    _check(not camp.transact(actor, "hire", "trader") and not world.trade.available("camp_trader"), "Hiring the trader needs 150 Zeni")
    actor.progression["zeni"] = 400
    _check(camp.transact(actor, "hire", "trader") and actor.zeni() == 250 and world.trade.available("camp_trader"), "A hired trader keeps shop at the Market Stall")
    _check(not camp.transact(actor, "hire", "trader"), "Staff are hired once")
    _at(world.trade.merchant_position("camp_trader") + Vector2(0, 8))
    _check(not world.trade.sell(actor, "camp_trader", "gear", worn.id), "The trader does not buy gear")
    # --- Ferry (M4.5d: harbours and tickets; see tests/travel.gd for the rest)
    var harbours = world.harbours
    _at(MAP.dock_position("sunfall"))
    actor.progression["zeni"] = 10
    _check(harbours.nearest_harbour(actor) == "sunfall" and not harbours.sail(actor, "sunfall", "amberhold"), "Sailing needs a ticket, a pass or a ship")
    actor.progression["zeni"] = 100
    var fare: int = preload("res://scripts/travel/travel_catalogue.gd").fare("sunfall", "amberhold")
    _check(harbours.buy_ticket(actor, "sunfall", "amberhold") and harbours.sail(actor, "sunfall", "amberhold") and actor.global_position.distance_to(MAP.dock_position("amberhold")) < 12.0 and actor.zeni() == 100 - fare and harbours.nearest_harbour(actor) == "amberhold", "A ticket takes you across the sea to the chosen harbour")
    # --- The travelling merchant
    world.progression["world_time"] = float(world.trade.state.traveller.arrive) + 1.0
    await _frames(2)
    _check(world.trade.available("traveller") and not world.trade.stock("traveller").is_empty(), "The travelling merchant appears when its time comes, with its own stock")
    var spot: Vector2i = MAP.to_tile(world.trade.merchant_position("traveller"))
    _check(not MAP.solid(spot.x, spot.y), "It stands on open ground")
    world.progression["world_time"] = float(world.trade.state.traveller.leave) + 1.0
    await _frames(2)
    _check(not world.trade.available("traveller") and float(world.trade.state.traveller.arrive) > float(world.progression.world_time) + 2000.0, "It leaves again and returns much later, somewhere else")
    # --- Restocking
    var cycle: int = world.trade.state.merchants.merchant_brookhaven.cycle
    world.progression["world_time"] = float(world.progression.world_time) + TRADE.RESTOCK_SECONDS
    await _frames(2)
    _check(int(world.trade.state.merchants.merchant_brookhaven.cycle) > cycle, "Merchants restock every 15 minutes of world time")
    # --- Defeat drops 10% of the purse into the pile
    _at(Vector2(480, 340))
    actor.progression["zeni"] = 1000
    actor.get_node("Health").take_damage(9999)
    await _frames(2)
    var piles: Array = get_nodes_in_group("item_piles")
    _check(actor.zeni() == 900 and piles.size() == 1 and piles[0].zeni == 100, "A defeat drops 10% of the purse into the pile")
    var pile_state: Dictionary = piles[0].capture()
    _check(pile_state.zeni == 100 and preload("res://scripts/pickups/item_pile.gd").valid(pile_state), "The pile saves its Zeni")
    session.respawn_character(actor)
    _at(piles[0].global_position)
    await _frames(3)
    _check(actor.zeni() == 1000, "Picking the pile up returns the Zeni")
    # --- Replication and saves
    var snapshot: Dictionary = CODEC.capture_entities(world)
    _check(snapshot.trade.merchants.has("merchant_brookhaven") and STORE.validate(_document(world)), "Merchant state is in snapshots; the whole world validates")
    var replica: Dictionary = snapshot.trade.duplicate(true)
    world.trade.state = {}
    CODEC.apply_entities(world, snapshot, true)
    _check(world.trade.state == replica, "Snapshots restore every merchant's stock and the traveller")
    var legacy: Dictionary = _document(world)
    legacy.version = 22
    legacy.erase("trade")
    for key in ["stall", "smithy", "staff"]:
        legacy.camp.erase(key)
    for state in legacy.players.values():
        state.progression.erase("zeni")
        state.skill_evidence.erase("scrolls")
        state.skill_ids = state.skill_ids.filter(func(id): return SKILLS.RULES[id].tier != "Unique" and not id in ["frost_maul"])
    legacy.enemies = legacy.enemies.filter(func(enemy): return not String(enemy.id).begins_with("frost_bear"))
    var migrated: Variant = STORE.migrate(legacy)
    _check(migrated is Dictionary and migrated.version == STORE.VERSION and migrated.players.host.progression.zeni == 0 and migrated.players.host.skill_evidence.scrolls == [] and migrated.camp.staff == {"trader": false, "smith": false} and migrated.trade is Dictionary and migrated.enemies.any(func(enemy): return enemy.id == "frost_bear_1"), "v22 worlds gain purses, scroll evidence, camp staff, merchants and the new regions' creatures")
    var forged: Dictionary = _document(world)
    forged.players.host.progression.zeni = -5
    var forged_stock: Dictionary = _document(world)
    forged_stock.trade.merchants.merchant_brookhaven.stock[0].price = 0
    _check(not STORE.validate(forged) and not STORE.validate(forged_stock), "Negative purses and free stock are rejected")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Trade checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)

func _document(target: Node2D) -> Dictionary:
    var document: Dictionary = CODEC.capture_entities(target)
    document.merge({"version": STORE.VERSION, "world_id": "trade", "players": {"host": CODEC.capture_player(actor)}, "progression": target.progression.duplicate(true)})
    return document.duplicate(true)
