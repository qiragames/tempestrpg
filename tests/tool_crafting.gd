extends SceneTree
## Tool crafting (user request after the SVE fixes): seven tiers of axes, pickaxes and fishing
## rods. Merchants sell Basic and Bronze/Birch; the rest are crafted at the Forge or in a town with
## the tool's own profession level and that level's logs, ores or fish, one tier after the other.
## Better tiers swing fewer times, gather more, work faster and help with rare fish; saves keep up
## to tier 7 and v43 maps the old Fine/Master tools to the tiers of equal strength.
const TRAVEL := preload("res://scripts/travel/travel_catalogue.gd")
const CRAFT := preload("res://scripts/professions/crafting_catalogue.gd")
const PRO := preload("res://scripts/professions/profession_catalogue.gd")
const FISHES := preload("res://scripts/professions/fish_catalogue.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
var world: Node2D
var checks := 0
var failures := 0
var messages: Array = []

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
    # --- The ladder.
    var ladder_ok := true
    for tool in CRAFT.TOOL_RECIPES:
        var last := 0
        for tier in range(2, TRAVEL.MAX_TOOL_TIER + 1):
            var spec: Array = CRAFT.TOOL_RECIPES[tool][tier]
            ladder_ok = ladder_ok and int(spec[0]) > last
            last = int(spec[0])
            for id in spec[1]:
                ladder_ok = ladder_ok and TRADE.bag_item(String(id))
    _check(ladder_ok and TRAVEL.MAX_TOOL_TIER == 7, "Seven tiers per tool; each crafted tier needs a higher level and real bag materials")
    _check(TRAVEL.tool_name("pickaxe", 3) == "Iron Pickaxe" and TRAVEL.tool_name("rod", 4) == "Maple Fishing Rod" and TRAVEL.tool_name("axe", 7) == "Adamantite Axe", "Tools are named after their material")
    _check(CRAFT.parse_tool_recipe("tool:axe:3") == ["axe", 3] and CRAFT.parse_tool_recipe("tool:axe:1") == ["", 0] and CRAFT.parse_tool_recipe("tool:sword:3") == ["", 0], "Tool recipe ids are checked")
    var faster := true
    for tier in range(1, TRAVEL.MAX_TOOL_TIER + 1):
        faster = faster and PRO.work_seconds(1.0, 10, 10, tier) <= PRO.work_seconds(1.0, 10, 10, tier - 1) and TRAVEL.GATHER_BONUS[tier] > TRAVEL.GATHER_BONUS[tier - 1] and FISHES.zone(20, "salmon", tier) >= FISHES.zone(20, "salmon", tier - 1)
    _check(faster and PRO.work_seconds(1.0, 10, 10, 7) < PRO.work_seconds(1.0, 10, 10, 3), "Every tier works faster, gathers more and widens the fishing zone")
    # --- In the world.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-tools-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24861, dir.path_join("tools.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var kept: Dictionary = me.progression.duplicate(true)
    var bag: Node = me.get_node("Inventory")
    bag.capacity = 200
    # Merchants: only the first two tiers.
    var shop_tiers: Array = []
    for entry in TRADE.MERCHANTS:
        if entry[3] == "town":
            for item in TRADE.roll_stock(entry, RandomNumberGenerator.new()):
                if item.kind == "tool":
                    shop_tiers.append(TRAVEL.parse_tool(item.id)[1])
    _check(not shop_tiers.is_empty() and shop_tiers.max() == TRAVEL.SHOP_TIERS and shop_tiers.all(func(tier): return tier <= TRAVEL.SHOP_TIERS) and TRAVEL.parse_tool("tool_axe_3") == ["", 0], "Merchants sell only Basic and the second tier")
    # Away from the Forge and towns nothing is made.
    me.global_position = Vector2(480, 340)
    me.progression.tools.axe = 1
    me.progression.professions.woodcutting = PRO.xp_for(5)
    bag.add_material("log_birch", 6)
    bag.add_material("bar_bronze", 2)
    _check(not session.apply_action(me, "craft", {"id": "tool:axe:2"}) and int(me.progression.tools.axe) == 1, "Tools are made at the Forge or in a town")
    # In Brookhaven.
    var town: Array = preload("res://scripts/world/world_map.gd").town("brookhaven")
    me.global_position = preload("res://scripts/world/world_map.gd").to_world(Vector2(town[3]))
    world.terrain.ensure_props_at(me.global_position)
    await _frames(2)
    _check(not me.craft_station("smithing").is_empty(), "Brookhaven counts as a crafting place")
    me.progression.professions.woodcutting = PRO.xp_for(4)
    _check(not session.apply_action(me, "craft", {"id": "tool:axe:2"}) and int(me.progression.tools.axe) == 1, "Woodcutting below the recipe's level: no Bronze Axe")
    me.progression.professions.woodcutting = PRO.xp_for(5)
    var wood_xp: int = int(me.progression.professions.woodcutting)
    _check(session.apply_action(me, "craft", {"id": "tool:axe:2"}) and int(me.progression.tools.axe) == 2 and me.ingredient_count("log_birch") == 0 and me.ingredient_count("bar_bronze") == 0, "Woodcutting 5 + 6 Birch Logs + 2 Bronze Bars make a Bronze Axe")
    _check(int(me.progression.professions.woodcutting) > wood_xp, "Crafting the tool gives Woodcutting XP")
    _check(not session.apply_action(me, "craft", {"id": "tool:axe:2"}), "Not the same tier twice")
    me.progression.professions.woodcutting = PRO.xp_for(40)
    bag.add_material("log_jadewood", 6)
    bag.add_material("bar_adamantite", 3)
    _check(not session.apply_action(me, "craft", {"id": "tool:axe:7"}) and int(me.progression.tools.axe) == 2, "Tiers come one after the other")
    _check(not session.apply_action(me, "craft", {"id": "tool:axe:3"}), "Missing ingredients: nothing happens")
    # Pickaxe and rod use their own professions.
    me.progression.professions.mining = PRO.xp_for(5)
    bag.add_material("ore_tin", 8)
    bag.add_material("log_oak", 2)
    _check(session.apply_action(me, "craft", {"id": "tool:pickaxe:2"}) and int(me.progression.tools.pickaxe) == 2, "Mining 5: a Bronze Pickaxe from tin ore and oak")
    me.progression.professions.fishing = PRO.xp_for(4)
    bag.add_material("log_birch", 4)
    bag.add_material("carp", 2)
    _check(not session.apply_action(me, "craft", {"id": "tool:rod:2"}), "The rod needs Fishing 5")
    me.progression.professions.fishing = PRO.xp_for(5)
    _check(session.apply_action(me, "craft", {"id": "tool:rod:2"}) and int(me.progression.tools.rod) == 2, "Fishing 5: a Birch Fishing Rod from birch and carp")
    var rejected: int = session.rejected_requests
    session.apply_action(me, "craft", {"id": 7})
    _check(session.rejected_requests == rejected + 1 and not session.apply_action(me, "craft", {"id": "tool:axe:99"}), "Malformed tool recipes are refused")
    # Swings by tier.
    _check(me.SWINGS.size() == TRAVEL.MAX_TOOL_TIER + 1 and me.SWINGS[7] < me.SWINGS[1], "Better tools need fewer swings")
    # The window shows the tool and the next one.
    var hud: CanvasLayer = world.get_node("HUD")
    hud.professions_panel.open()
    hud.professions_panel._selected = "woodcutting"
    hud.professions_panel.refresh()
    await _frames(2)
    var texts: Array = []
    for child in hud.professions_panel._list.get_children():
        if child is Label:
            texts.append(child.text)
        for inner in child.get_children():
            if inner is Label:
                texts.append(inner.text)
    _check(texts.any(func(text): return text.contains("Your axe: Bronze Axe")) and texts.any(func(text): return text.contains("Iron Axe")), "The Woodcutting tab shows your axe and the next one to craft")
    hud.professions_panel.close_panel()
    # --- Saves: up to tier 7; v43 maps Fine/Master to the same strength.
    me.progression = kept
    me.progression.tools = {"axe": 7, "pickaxe": 2, "rod": 1}
    _check(session.save_world() == OK, "Saved with an Adamantite Axe")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("tools.json")))
    _check(STORE.validate(raw) and int(raw.players.host.progression.tools.axe) == 7, "Tier 7 tools are saved")
    var bad: Dictionary = raw.duplicate(true)
    bad.players.host.progression.tools.axe = 8
    _check(not STORE.validate(bad), "Tier 8 does not exist")
    var old: Dictionary = raw.duplicate(true)
    old.version = 42
    old.players.host.progression.tools = {"axe": 3, "pickaxe": 2, "rod": 1}
    var migrated: Variant = STORE.migrate(old)
    _check(migrated is Dictionary and int(migrated.version) == STORE.VERSION and migrated.players.host.progression.tools == {"axe": 5, "pickaxe": 3, "rod": 1} and STORE.validate(migrated), "v42 tools: Master becomes Gold (tier 5), Fine becomes Iron (tier 3)")
    _check(is_equal_approx(TRAVEL.tool_power(5), 3.0) and is_equal_approx(TRAVEL.tool_power(3), 2.0), "...which work exactly as well as before")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Tool crafting checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
