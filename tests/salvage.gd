extends SceneTree
## Salvage (user request): gear from the bag is broken into what it was made of at the Forge or in
## a town — bars of its tier from weapons and armour with defence, cloth from cloth armour, gems
## from rings and amulets; more for rarer pieces, Arcane Essence from Legendary and Mythic ones
## (the Adamantite tools need it). Worn pieces are kept; "Salvage Commons" clears the junk.
const CRAFT := preload("res://scripts/professions/crafting_catalogue.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const PRO := preload("res://scripts/professions/profession_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
var world: Node2D
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
    var rng := RandomNumberGenerator.new()
    rng.seed = 21
    var sword: Dictionary = GEAR.roll("iron_sword", 0, rng)
    var sword_gain: Dictionary = CRAFT.salvage_yield(sword)
    _check(sword_gain.size() == 1 and CRAFT.is_bar(sword_gain.keys()[0]) and int(sword_gain.values()[0]) == 1, "A Common sword gives one bar of its tier")
    var hood: Dictionary = GEAR.roll("cloth_hood", 2, rng)
    var hood_gain: Dictionary = CRAFT.salvage_yield(hood)
    _check(hood_gain.has(CRAFT.cloth_for_level(1)) and int(hood_gain[CRAFT.cloth_for_level(1)]) == 2, "A Rare cloth hood gives two of its cloth")
    var ring: Dictionary = GEAR.roll("copper_ring", 1, rng)
    _check(CRAFT.salvage_yield(ring).keys().all(func(id): return PRO.GEMS.has(id)), "Rings and amulets give gems")
    var mythic: Dictionary = GEAR.roll("iron_sword", 5, rng)
    var mythic_gain: Dictionary = CRAFT.salvage_yield(mythic)
    _check(int(mythic_gain.get(CRAFT.ARCANE_ESSENCE, 0)) == 2 and int(mythic_gain[CRAFT.bar_for_level(int(GEAR.BASES.iron_sword.get("level", 1)))]) == 6, "A Mythic piece gives six bars and two Arcane Essence")
    _check(CRAFT.TOOL_RECIPES.axe[7][1].has(CRAFT.ARCANE_ESSENCE) and preload("res://scripts/trade/trade_catalogue.gd").bag_item(CRAFT.ARCANE_ESSENCE), "Arcane Essence is a bag item the Adamantite tools need")
    # --- In the world.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-salvage-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24891, dir.path_join("salvage.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    me.global_position = Vector2(480, 340)
    me.add_item(sword)
    _check(not session.apply_action(me, "gear", {"operation": "salvage", "id": sword.id}) and not me.item_by_id(sword.id).is_empty(), "Away from the Forge or a town nothing is salvaged")
    me.global_position = MAP.to_world(Vector2(MAP.town("brookhaven")[3]))
    await _frames(2)
    var bar: String = sword_gain.keys()[0]
    _check(session.apply_action(me, "gear", {"operation": "salvage", "id": sword.id}) and me.item_by_id(sword.id).is_empty() and me.ingredient_count(bar) == 1, "In a town the sword becomes a bar")
    var worn: Dictionary = GEAR.roll("cloth_hood", 0, rng)
    me.add_item(worn)
    preload("res://scripts/progression/class_catalogue.gd").enforced = false
    me.equip(worn.id, "head")
    _check(not session.apply_action(me, "gear", {"operation": "salvage", "id": worn.id}) and not me.item_by_id(worn.id).is_empty(), "Worn pieces are not salvaged")
    for index in range(3):
        me.add_item(GEAR.roll("copper_ring", 0, rng))
    var rare: Dictionary = GEAR.roll("copper_ring", 2, rng)
    me.add_item(rare)
    _check(session.apply_action(me, "gear", {"operation": "salvage_common"}) and not me.item_by_id(rare.id).is_empty() and not me.item_by_id(worn.id).is_empty() and me.gear.items.filter(func(item): return int(item.rarity) == 0).size() == 1, "Salvage Commons breaks every loose Common piece (worn and rarer ones stay)")
    var rejected: int = session.rejected_requests
    session.apply_action(me, "gear", {"operation": "salvage", "id": 5})
    _check(session.rejected_requests == rejected + 1, "Malformed salvage intents are refused")
    var bag: Node = me.get_node("Inventory")
    bag.capacity = bag.total_units()
    _check(not session.apply_action(me, "gear", {"operation": "salvage", "id": rare.id}) and not me.item_by_id(rare.id).is_empty(), "A full bag keeps the item")
    # The button in the equipment window.
    var hud: CanvasLayer = world.get_node("HUD")
    hud.gear_panel.open()
    hud.gear_panel._selected = rare.id
    await _frames(2)
    _check(not hud.gear_panel._salvage.disabled and hud.gear_panel._salvage.tooltip_text.contains("Breaks it into") and not hud.gear_panel._salvage_common.disabled, "The equipment window offers Salvage and Salvage Commons in town")
    hud.gear_panel.close()
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Salvage checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
