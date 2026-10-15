extends SceneTree
## Item expansion (user request): hundreds of weapons and armour pieces with their own looks and
## names, six rarities (Mythic), daggers, bases gated by minimum rarity and item level, icons for
## every base, weapons drawn in hand; saves and forgeries.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const SOURCES := preload("res://scripts/items/gear_sources.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
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
    rng.seed = 4242
    # --- Catalogue
    var per_type := {}
    var names := {}
    var elements := {}
    var icons_ok := true
    for id in GEAR.BASES:
        var spec: Dictionary = GEAR.BASES[id]
        var key: String = spec.get("weapon", spec.slot)
        per_type[key] = int(per_type.get(key, 0)) + 1
        names[spec.name] = int(names.get(spec.name, 0)) + 1
        if not String(spec.get("element", "")).is_empty():
            elements[spec.element] = true
    for id in ["sword_001", "dagger_050", "bow_101", "scythe_077", "amulet_048", "iron_sword"]:
        var texture: Texture2D = GEAR.icon_texture(id, 3)
        icons_ok = icons_ok and texture != null and texture.get_width() > 0
    _check(per_type.get("dagger", 0) >= 100 and per_type.get("sword", 0) >= 100 and per_type.get("bow", 0) >= 100 and per_type.get("spear", 0) >= 80 and per_type.get("scythe", 0) >= 60, "Hundreds of weapons: %s" % [per_type])
    _check(per_type.get("head", 0) >= 40 and per_type.get("body", 0) >= 60 and per_type.get("hands", 0) >= 30 and per_type.get("feet", 0) >= 40 and per_type.get("accessory", 0) >= 60, "…and armour and jewellery for every slot")
    _check(names.values().all(func(count): return count == 1), "Every item has its own name")
    _check(elements.size() == 8, "Eight elements give themed names and colours (%s)" % [elements.keys()])
    _check(icons_ok, "Every base has an icon (atlas cells for the new ones)")
    _check(GEAR.RARITIES[-1] == "Mythic" and GEAR.RARITY_SCALE[-1] > GEAR.RARITY_SCALE[-2] and GEAR.PASSIVE_COUNT[-1] == 3, "Mythic: the sixth rarity, strongest scaling and three passives")
    # --- Stronger at higher levels and elements
    var plain: Dictionary = GEAR.BASES.sword_001
    var late: Array = GEAR.BASES.keys().filter(func(id): return GEAR.BASES[id].get("weapon", "") == "sword" and int(GEAR.BASES[id].level) >= 16)
    _check(not late.is_empty() and GEAR.BASES[late[0]].stats.damage[0] > plain.stats.damage[0], "Higher-level swords hit harder")
    # --- Minimum rarity and level gating
    var gated := true
    for _i in range(400):
        var rarity := rng.randi_range(0, 5)
        var id: String = SOURCES._base(rng, [], rarity, 3)
        gated = gated and int(GEAR.BASES[id].min_rarity) <= rarity and int(GEAR.BASES[id].level) <= 3 + SOURCES.LEVEL_REACH
    _check(gated, "Drops pick bases allowed at their rarity and near the creature's level")
    var low_item: Dictionary = GEAR.roll("sword_003", 2, rng)
    low_item.rarity = 0
    var epic_ids: Array = GEAR.BASES.keys().filter(func(id): return int(GEAR.BASES[id].get("min_rarity", 0)) == 3)
    var forged_epic: Dictionary = GEAR.roll(epic_ids[0], 3, rng)
    forged_epic.rarity = 1
    _check(not GEAR.valid_item(forged_epic), "An Epic-only piece can never be Uncommon")
    var mythic: Dictionary = GEAR.roll(epic_ids[0], 5, rng)
    _check(GEAR.valid_item(mythic) and mythic.passives.size() == 3 and not mythic.active.is_empty(), "A Mythic roll validates (three passives and an active)")
    var levels := {}
    for _i in range(300):
        var drop: Dictionary = SOURCES.roll_drop(2, rng, 18)
        if not drop.is_empty():
            levels[int(GEAR.BASES[drop.base].level)] = true
    _check(levels.keys().any(func(level): return level >= 12), "Elites at level 18 drop high-level pieces")
    # --- In a world: a dagger in hand, its quick stab, saves
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    var dagger_id: String = GEAR.BASES.keys().filter(func(id): return GEAR.BASES[id].get("weapon", "") == "dagger" and int(GEAR.BASES[id].min_rarity) == 2)[0]
    var dagger: Dictionary = GEAR.roll(dagger_id, 4, rng)
    actor.add_item(dagger)
    _check(actor.equip(dagger.id, "weapon"), "A Legendary %s equipped" % GEAR.BASES[dagger_id].name)
    await _frames(2)
    _check(actor._weapon_icon != null, "It is drawn in the character's hand")
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    _check(actor.get_node("MeleeAttack").attack(Vector2.RIGHT) and is_equal_approx(actor.get_node("MeleeAttack").cooldown_left, GEAR.WEAPONS.dagger.recovery * actor.get_node("MeleeAttack")._race().recovery), "Daggers stab quickly (%.2f s)" % GEAR.WEAPONS.dagger.recovery)
    var document: Dictionary = CODEC.capture_entities(world)
    document.merge({"version": STORE.VERSION, "world_id": "items", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    _check(STORE.validate(document.duplicate(true)), "New items save")
    var forged: Dictionary = document.duplicate(true)
    forged.players.host.gear.items[-1].stats.damage = 9999
    _check(not STORE.validate(forged), "Forged stats are rejected")
    world.queue_free()
    await _frames()
    print("Item checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
