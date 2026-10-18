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
    # These checks are about items, not classes (M12b): class requirements are off here.
    preload("res://scripts/progression/class_catalogue.gd").enforced = false
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
    # --- Elements (part 2): what a hit does, by element and rarity
    var ELEMENTS := preload("res://scripts/items/element_catalogue.gd")
    _check(ELEMENTS.on_hit("fire", 1, 20).is_empty() and ELEMENTS.on_hit("fire", 2, 20).has("dot") and ELEMENTS.on_hit("fire", 5, 20).dot[0] > ELEMENTS.on_hit("fire", 2, 20).dot[0], "Elements act from Rare and grow with rarity")
    var gnasher = load("res://scenes/enemies/forest_gnasher.tscn").instantiate()
    gnasher.entity_id = "items_gnasher"
    world.add_child(gnasher)
    world.wire_enemy(gnasher)
    gnasher.set_physics_process(false)
    var other = load("res://scenes/enemies/forest_gnasher.tscn").instantiate()
    other.entity_id = "items_gnasher_2"
    world.add_child(other)
    world.wire_enemy(other)
    other.set_physics_process(false)
    for pick in [["fire", "dot"], ["frost", "slow"], ["storm", "chain"]]:
        var ids: Array = GEAR.BASES.keys().filter(func(id): return GEAR.BASES[id].get("weapon", "") == "sword" and GEAR.BASES[id].element == pick[0])
        var blade: Dictionary = GEAR.roll(ids[0], 4, rng)
        actor.add_item(blade)
        actor.equip(blade.id, "weapon")
        gnasher.get_node("Health").maximum = 5000
        gnasher.get_node("Health").current = 5000
        gnasher.get_node("Health").immunity_left = 0.0
        other.get_node("Health").maximum = 5000
        other.get_node("Health").current = 5000
        other.get_node("Health").immunity_left = 0.0
        gnasher.dot_left = 0.0
        gnasher.slow_left = 0.0
        actor.global_position = Vector2(300, 520)
        gnasher.global_position = actor.global_position + Vector2(18, 0)
        other.global_position = gnasher.global_position + Vector2(20, 0)
        await _frames(2)
        actor.get_node("MeleeAttack").cooldown_left = 0.0
        var other_hp: int = other.get_node("Health").current
        var swung: bool = actor.get_node("MeleeAttack").attack(Vector2.RIGHT)
        match pick[1]:
            "dot":
                _check(gnasher.dot_left > 0.0, "A fire sword sets creatures burning")
            "slow":
                _check(gnasher.slow_left > 0.0, "A frost sword slows them")
            "chain":
                _check(other.get_node("Health").current < other_hp, "A storm sword arcs to a second creature")
    # --- Sets and uniques (part 3)
    var SETS := preload("res://scripts/items/set_catalogue.gd")
    var set_pieces: Array = GEAR.BASES.keys().filter(func(id): return GEAR.BASES[id].get("set", "") == "emberlord")
    var uniques: Array = GEAR.BASES.keys().filter(func(id): return GEAR.BASES[id].has("unique"))
    _check(set_pieces.size() == 5 and GEAR.BASES.keys().filter(func(id): return GEAR.BASES[id].has("set")).size() == 40, "Eight sets of five pieces")
    _check(uniques.size() >= 20 and uniques.all(func(id): return int(GEAR.BASES[id].min_rarity) >= 4), "%d unique named pieces, only Legendary or Mythic" % uniques.size())
    var strike_before: float = actor.gear_bonus("strike")
    var worn_set: Array = []
    for id in set_pieces:
        var piece: Dictionary = GEAR.roll(id, 3, rng)
        actor.add_item(piece)
        worn_set.append(piece)
    var slots := {"head": "head", "body": "body", "hands": "hands", "feet": "feet", "accessory": "accessory_1"}
    for k in range(2):
        actor.equip(worn_set[k].id, slots[GEAR.BASES[worn_set[k].base].slot])
    _check(is_equal_approx(actor.gear_bonus("strike") - strike_before, 3.0 + float(worn_set[0].stats.get("strike", 0)) + float(worn_set[1].stats.get("strike", 0))), "Two Emberlord pieces: +3 strike")
    for k in range(2, 4):
        actor.equip(worn_set[k].id, slots[GEAR.BASES[worn_set[k].base].slot])
    _check(is_equal_approx(SETS.damage_factor(actor.equipped_items(), GEAR.BASES), 1.15) and SETS.element_factor(actor.equipped_items(), GEAR.BASES, "fire") == 1.5, "Four pieces: +15% weapon damage, fire weapons act half as strong again")
    # Phoenix: one lethal hit survived.
    var phoenix_id: String = uniques.filter(func(id): return GEAR.BASES[id].unique == "phoenix" and GEAR.BASES[id].slot == "body")[0]
    var phoenix: Dictionary = GEAR.roll(phoenix_id, 5, rng)
    actor.add_item(phoenix)
    actor.equip(phoenix.id, "body")
    actor.get_node("Health").immunity_left = 0.0
    actor.get_node("Health").take_damage(99999)
    _check(actor.get_node("Health").current == 1 and actor.phoenix_left > 0.0, "Phoenix Plate: a lethal hit leaves 1 HP")
    actor.get_node("Health").current = actor.get_node("Health").maximum
    # Executioner: double damage below 30%.
    var kingsbane: Dictionary = GEAR.roll(uniques.filter(func(id): return GEAR.BASES[id].unique == "executioner" and GEAR.BASES[id].weapon == "sword")[0], 4, rng)
    actor.add_item(kingsbane)
    actor.equip(kingsbane.id, "weapon")
    var victim = load("res://scenes/enemies/forest_gnasher.tscn").instantiate()
    victim.entity_id = "items_victim"
    world.add_child(victim)
    victim.set_physics_process(false)
    await _frames(1)
    victim.get_node("Health").maximum = 1000
    victim.get_node("Health").current = 200
    _check(actor.get_node("MeleeAttack").ability_damage(victim, 40) == 80 and actor.get_node("MeleeAttack").ability_damage(victim, 40) == 80, "Kingsbane: double damage to a creature below 30%")
    victim.get_node("Health").current = 900
    _check(actor.get_node("MeleeAttack").ability_damage(victim, 40) == 40, "…normal damage above it")
    victim.queue_free()
    var legendary_fx: bool = is_instance_valid(actor._weapon_fx) and actor._weapon_fx.emitting
    _check(legendary_fx, "Legendary weapons spark (particles in the element's colour)")
    gnasher.queue_free()
    other.queue_free()
    var document: Dictionary = CODEC.capture_entities(world)
    document.merge({"version": STORE.VERSION, "world_id": "items", "players": {"host": CODEC.capture_player(actor)}, "progression": world.progression.duplicate(true)})
    _check(STORE.validate(document.duplicate(true)), "New items save")
    var forged: Dictionary = document.duplicate(true)
    forged.players.host.gear.items[-1].stats.damage = 9999
    _check(not STORE.validate(forged), "Forged stats are rejected")
    world.queue_free()
    await _frames()
    # User request: above level 20, new gear for every type every two to three levels.
    var by_type := {}
    for id in GEAR.BASES:
        var spec: Dictionary = GEAR.BASES[id]
        if spec.has("unique") or spec.get("boss", false):
            continue
        var type: String = spec.get("weapon", spec.slot)
        if not by_type.has(type):
            by_type[type] = {}
        by_type[type][int(spec.get("level", 1))] = true
    var gaps: Array = []
    for type in by_type:
        for level in range(21, 51):
            var near := false
            for tier_level in by_type[type]:
                near = near or absi(int(tier_level) - level) <= 2
            if not near:
                gaps.append("%s %d" % [type, level])
    _check(by_type.size() == 12 and gaps.is_empty(), "Every weapon, armour and accessory type has gear within two levels of every level 21-50 %s" % [gaps])
    var tier_names := {}
    for id in preload("res://scripts/items/high_items.gd").BASES:
        tier_names[GEAR.BASES[id].name] = true
    _check(tier_names.size() == preload("res://scripts/items/high_items.gd").BASES.size() and GEAR.BASES.has("t24_sword_100") == preload("res://scripts/items/item_bases.gd").BASES.has("sword_100"), "Every tier piece has its own name; the older tiers keep their IDs")
    print("Item checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
