extends SceneTree
## Smithing and Alchemy (M6c): herbs picked from bushes, bars smelted from ores, gear forged from
## bars and logs (level by bar, rarity by Smithing), potions and elixirs brewed and drunk; recipes
## need the camp's Forge/Shrine or a town, show their chance and lose the ingredients on a failure.
const PRO := preload("res://scripts/professions/profession_catalogue.gd")
const CRAFT := preload("res://scripts/professions/crafting_catalogue.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
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
    # Catalogue.
    var ingredients_ok := true
    var trade := preload("res://scripts/trade/trade_catalogue.gd")
    var materials: Dictionary = preload("res://scripts/skills/skill_catalogue.gd").MATERIALS
    for profession in ["smithing", "alchemy"]:
        for id in CRAFT.recipes(profession):
            for need in CRAFT.recipes(profession)[id][2]:
                ingredients_ok = ingredients_ok and (need in ["log_*", "gem_*"] or trade.bag_item(need) or materials.has(need))
    _check(ingredients_ok, "Every ingredient is a real bag item")
    _check(CRAFT.recipes("smithing").keys().filter(func(id): return not String(id).begins_with("bossforge:")).size() == CRAFT.BARS.size() * (1 + CRAFT.FORGE.size()) and CRAFT.recipes("alchemy").size() == CRAFT.POTIONS.size(), "Recipes: smelting and forging for every bar, a brew for every potion")
    _check(trade.is_good("bar_mithril") and trade.is_good("elixir_might") and trade.is_good("herb_sakura") and trade.price("senzu_bean") > trade.price("healing_draught"), "Bars, potions and herbs are bag goods merchants buy")
    var rng := RandomNumberGenerator.new()
    rng.seed = 4
    var bases_ok := true
    for bar in CRAFT.BARS:
        for kind in CRAFT.FORGE:
            var base: String = CRAFT.forge_base(kind, bar, 2, rng)
            bases_ok = bases_ok and not base.is_empty() and not GEAR.BASES[base].has("unique")
    _check(bases_ok, "Every bar can forge every kind of gear (no uniques)")
    _check(CRAFT.forge_weights(1, 1)[5] == 0.0 and CRAFT.forge_weights(50, 3)[5] > 0.0 and CRAFT.forge_weights(40, 3)[4] > CRAFT.forge_weights(3, 3)[4], "Better Smithing forges rarer gear; Mythic only at 50")
    _check(PRO.resource_for("bush", "Sakura Vale", 1) == "herb_sakura" and PRO.profession_for("herb_mint") == "alchemy", "Bushes grow the region's herb (Alchemy)")
    # A world.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-craft-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24797, dir.path_join("craft.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    var bag: Node = actor.get_node("Inventory")
    # Picking a herb from a bush.
    var plan: Array = world.terrain.planned_props()
    var bush := -1
    for index in range(plan.size()):
        if world.nodes.info(index).get("resource") == "herb_mint":
            bush = index
            break
    _check(bush >= 0, "The world has mint bushes")
    actor.global_position = world.nodes.work_point(bush) + Vector2(0, 6)
    world.terrain.ensure_props_at(actor.global_position)
    await _frames(2)
    _check(String(world.nodes.prompt(actor, bush)[0]).begins_with("F: Pick Meadow Mint"), "The prompt offers to pick the herb")
    var picker := RandomNumberGenerator.new()
    picker.seed = 2
    for _i in range(30):
        if not world.nodes.strike(actor, bush, picker):
            break
    _check(bag.count_of("herb_mint") >= 2 and int(actor.progression.professions.alchemy) > 0, "Picking gives herbs and Alchemy XP")
    # No station out in the wild (the spawn meadow; the camp has no forge yet).
    actor.global_position = preload("res://scripts/world/world_layout.gd").SPAWN
    world.terrain.ensure_props_at(actor.global_position)
    await _frames(2)
    bag.add_material("ore_copper", 4)
    bag.add_material("ore_tin", 4)
    _check(actor.craft_station("smithing").is_empty() and not actor.craft("smelt:bar_bronze") and bag.count_of("ore_copper") == 4, "No smelting in the wild (nothing used)")
    # In a town.
    actor.global_position = world.trade.merchant_position("merchant_brookhaven") + Vector2(-14, 0)
    world.terrain.ensure_props_at(actor.global_position)
    await _frames(2)
    _check(actor.craft_station("smithing") == "town" and actor.craft_station("alchemy") == "town", "Towns have a smithy and an alchemist")
    var made := 0
    for _i in range(4):
        if actor.craft("smelt:bar_bronze"):
            made += 1
    _check(bag.count_of("ore_copper") == 0 and bag.count_of("bar_bronze") >= made and made >= 1, "Smelting bronze uses copper and tin (%d of 4 succeeded)" % made)
    _check(int(actor.progression.professions.smithing) > 0, "Smithing XP")
    # Forging: guaranteed with a master smith.
    actor.progression.professions.smithing = PRO.xp_for(50)
    bag.add_material("bar_bronze", 4)
    bag.add_material("log_oak", 2)
    var items: int = actor.gear.items.size()
    _check(actor.craft("forge:bar_bronze:sword") and actor.gear.items.size() == items + 1, "Forging a bronze sword")
    var sword: Dictionary = actor.gear.items[-1]
    _check(GEAR.BASES[sword.base].get("weapon") == "sword" and int(GEAR.BASES[sword.base].get("level", 1)) <= 4 and GEAR.valid_item(sword), "The sword is a valid low-level sword")
    bag.discard(&"bar_bronze", bag.count_of("bar_bronze"))
    bag.add_material("bar_bronze", 4)
    _check(not actor.craft("forge:bar_bronze:body") and bag.count_of("bar_bronze") == 4, "Armour needs five bars (four are not enough, nothing used)")
    # Failure loses the ingredients.
    actor.progression.professions.smithing = 0
    bag.add_material("ore_starmetal", 2)
    bag.add_material("gem_sapphire", 1)
    _check(not actor.craft("smelt:bar_starmetal") and bag.count_of("ore_starmetal") == 2, "More than 10 levels above yours: refused, nothing used")
    bag.add_material("ore_iron", 2)
    var iron_before: int = bag.count_of("bar_iron")
    var failed := 0
    for _i in range(1):
        if not actor.craft("smelt:bar_iron"):
            failed += 1
    _check(bag.count_of("ore_iron") == 0 and bag.count_of("bar_iron") - iron_before + failed >= 1, "A try uses the ingredients whether it works or not")
    # Alchemy: brew and drink.
    actor.progression.professions.alchemy = PRO.xp_for(50)
    bag.add_material("herb_mint", 4)
    bag.add_material("minnow", 2)
    _check(actor.craft("brew:healing_draught") and bag.count_of("healing_draught") >= 1, "Brewing a healing draught")
    bag.add_material("herb_sakura", 2)
    bag.add_material("koi", 1)
    _check(actor.craft("brew:elixir_swiftness") and bag.count_of("elixir_swiftness") == 2, "A master alchemist brews elixirs twice")
    var speed: float = actor.current_speed()
    _check(actor.use_good("elixir_swiftness") and actor.current_speed() > speed * 1.2 and actor.elixirs.has("speed"), "Swiftness makes you faster")
    _check(float(actor.elixirs.speed[1]) > 120.0, "Alchemy 30 makes elixirs last longer")
    actor._tick_elixirs(1000.0)
    _check(actor.elixirs.is_empty() and is_equal_approx(actor.current_speed(), speed), "Elixirs wear off")
    bag.add_material("elixir_iron", 1)
    var armor: int = actor.get_node("Health").armor
    actor.use_good("elixir_iron")
    _check(actor.get_node("Health").armor == armor + 6, "Iron Skin adds defence")
    actor._tick_elixirs(1000.0)
    _check(actor.get_node("Health").armor == armor, "and it wears off")
    bag.add_material("senzu_bean", 1)
    actor.get_node("Health").current = 10
    actor.consumable_cooldown = 0.0
    _check(actor.use_good("senzu_bean") and actor.get_node("Health").current == actor.get_node("Health").maximum, "A Senzu Bean heals fully")
    # Saves keep bars and potions.
    _check(session.save_world() == OK, "Saved with bars and potions in the bag")
    # The window: crafting rows.
    var hud: CanvasLayer = world.get_node("HUD")
    hud.professions_panel.open()
    hud.professions_panel._select("smithing")
    await _frames(2)
    var buttons := 0
    for row in hud.professions_panel._list.get_children():
        if row is HBoxContainer:
            buttons += 1
    _check(buttons == CRAFT.BARS.size() * 2, "Smithing lists smelting and forging for every bar")
    hud.professions_panel._select("alchemy")
    await _frames(2)
    buttons = 0
    for row in hud.professions_panel._list.get_children():
        if row is HBoxContainer:
            buttons += 1
    _check(buttons == CRAFT.POTIONS.size(), "Alchemy lists every brew")
    hud.professions_panel.close_panel()
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Crafting checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
