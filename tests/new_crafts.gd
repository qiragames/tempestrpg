extends SceneTree
## Cooking, Enchanting and Tailoring (M11e): recipes exist for real ingredients; meals work like
## potions (and Scholar's Soup gives more XP); runes come from Enchanting; Tailoring sews light
## armour in its cloth's level band; old saves gain the three professions (v38); the window.
const PRO := preload("res://scripts/professions/profession_catalogue.gd")
const CRAFT := preload("res://scripts/professions/crafting_catalogue.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
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
    var trade := preload("res://scripts/trade/trade_catalogue.gd")
    var problems: Array = []
    for profession in ["cooking", "enchanting", "tailoring"]:
        var recipes: Dictionary = CRAFT.recipes(profession)
        if recipes.size() < 7:
            problems.append(profession + " has few recipes")
        for id in recipes:
            for ingredient in recipes[id][2]:
                if not ingredient in ["fish_*", "gem_*", "log_*"] and not trade.bag_item(ingredient):
                    problems.append("%s needs unknown %s" % [id, ingredient])
            if CRAFT.recipe(id).is_empty() or CRAFT.recipe(id)[0] != profession:
                problems.append(id + " not found")
    _check(problems.is_empty(), "Every new recipe uses real ingredients %s" % [problems])
    _check(PRO.ORDER.size() == 8 and PRO.initial_state().has("tailoring"), "Eight professions")
    _check(CRAFT.CLOTHS.keys().all(func(cloth): return ["head", "body", "hands", "feet"].all(func(slot): return not CRAFT.tailor_base(slot, cloth, 0, RandomNumberGenerator.new()).is_empty())), "Every cloth can sew every piece")
    # A world.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-new-crafts-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24820, dir.path_join("crafts.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    var bag: Node = actor.get_node("Inventory")
    _check(PRO.valid(actor.progression.professions), "A new character has all eight professions")
    actor.global_position = world.trade.merchant_position("merchant_brookhaven") + Vector2(-14, 0)
    world.terrain.ensure_props_at(actor.global_position)
    _check(actor.craft_station("cooking") == "town" and actor.craft_station("tailoring") == "town", "Towns are stations for the new crafts")
    # Cooking.
    bag.add_material("trout", 3)
    bag.add_material("minnow", 2)
    _check(actor.ingredient_count("fish_*") == 5, "Any fish counts for a meal")
    var cooked := false
    for _i in range(12):
        if actor.craft("cook:food_grilled_fish"):
            cooked = true
            break
        bag.add_material("minnow", 1)
    _check(cooked and bag.count_of("food_grilled_fish") >= 1 and PRO.level_of(actor.progression, "cooking") >= 1 and int(actor.progression.professions.cooking) > 0, "Cooking grilled fish (Cooking XP)")
    _check(bag.count_of("minnow") < 2 or bag.count_of("trout") == 3, "The cheapest fish goes into the pan first")
    actor.get_node("Health").current = 10
    actor.consumable_cooldown = 0.0
    _check(actor.use_good("food_grilled_fish") and bag.count_of("food_grilled_fish") >= 0, "Eating the grilled fish")
    bag.add_material("food_scholars_soup", 1)
    _check(actor.use_good("food_scholars_soup") and actor.elixir("wisdom") == 20.0, "Scholar's Soup: +20% XP")
    var before: int = int(actor.progression.experience)
    actor.gain_experience(100, "test")
    _check(int(actor.progression.experience) - before == 120, "...and it works (100 XP → 120)")
    # Enchanting.
    actor.progression.professions["enchanting"] = PRO.max_xp()
    bag.add_material("gem_sapphire", 2)
    bag.add_material("gnasher_essence", 4)
    var runes: int = bag.count_of("rune_vigor")
    _check(actor.craft("enchant:rune_vigor") and bag.count_of("rune_vigor") > runes, "Inscribing a Rune of Vigor")
    # Tailoring.
    actor.progression.professions["tailoring"] = PRO.max_xp()
    var items: int = actor.gear.items.size()
    # Even a master fails 2% of tries, and Double Stitch (Tailoring 40) sometimes sews two.
    var sewn := false
    for _try in range(4):
        bag.add_material("frost_pelt", 4)
        if actor.craft("tailor:frost_pelt:body"):
            sewn = true
            break
    _check(sewn and actor.gear.items.size() in [items + 1, items + 2], "Sewing a Frost Pelt robe")
    var robe: Dictionary = actor.gear.items[-1]
    var level: int = int(GEAR.BASES[robe.base].get("level", 1))
    _check(GEAR.BASES[robe.base].slot == "body" and level >= 5 and level <= 11, "Body armour in the pelt's level band (Lv %d)" % level)
    if bag.count_of("frost_pelt") > 0:
        bag.discard(&"frost_pelt", bag.count_of("frost_pelt"))
    _check(not actor.craft("tailor:frost_pelt:feet"), "No pelts left, no boots")
    # Saves.
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("crafts.json")))
    var old: Dictionary = raw.duplicate(true)
    old.version = 37
    for profession in ["cooking", "enchanting", "tailoring"]:
        old.players.host.progression.professions.erase(profession)
    var migrated: Variant = STORE.migrate(old)
    _check(migrated is Dictionary and STORE.validate(migrated) and int(migrated.players.host.progression.professions.cooking) == 0, "v37 saves gain the three professions at 0")
    # The window.
    var hud: CanvasLayer = world.get_node("HUD")
    hud.quest_panel._queue.clear()
    hud.dialog_panel.close()
    hud.professions_panel.open()
    hud.professions_panel._selected = "tailoring"
    hud.professions_panel.refresh()
    await _frames(2)
    _check(hud.professions_panel.visible and hud.professions_panel._list.get_child_count() >= 7, "The professions window lists Tailoring's cloths")
    hud.professions_panel.close_panel()
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("New craft checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
