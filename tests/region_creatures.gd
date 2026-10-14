extends SceneTree
## M4.5c region creatures and verticality: every new kind has a scene, a four-direction sprite set,
## a specimen with its material and Common skill (taught by analysis) and a utility effect; the
## creatures animate by direction; the ferry lands are harder; plateaus are ledges you cannot
## climb, with rock walls below, while roads ramp up over stairs.
const MAP := preload("res://scripts/world/world_map.gd")
const REGION := preload("res://scripts/world/region_content.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const CATALOGUE := preload("res://scripts/skills/skill_catalogue.gd")
const FX := preload("res://scripts/skills/skill_effects.gd")
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
const KINDS := ["frost_bear", "snow_wisp", "dune_viper", "sand_scuttler", "bog_kappa", "mirecap", "bamboo_sprite", "paper_lantern", "amber_owl", "burrow_mole", "ember_flame", "salamander"]
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
    # --- Kinds, specimens, skills
    var kinds_ok := true
    var skills: Array = []
    for kind in KINDS:
        var creature = load(CODEC.ENEMY_SCENES.get(kind, "res://missing.tscn")).instantiate() if CODEC.ENEMY_SCENES.has(kind) else null
        if creature == null:
            kinds_ok = false
            continue
        var specimen: Resource = creature.specimen
        var skill: String = String(specimen.skill.id)
        skills.append(skill)
        kinds_ok = kinds_ok and creature.kind == kind and SPRITES.has_set(kind) and not SPRITES.is_side(kind) and CATALOGUE.SPECIMENS.has(String(specimen.id))
        kinds_ok = kinds_ok and CATALOGUE.MATERIALS.get(String(specimen.material_id)) == String(specimen.id) and CATALOGUE.RULES[skill] == {"tier": "Common", "analysis": String(specimen.id)}
        kinds_ok = kinds_ok and not FX.effects(skill).is_empty() and load(CATALOGUE.SKILLS[skill]).damage == FX.damage_for(load(CATALOGUE.SKILLS[skill]).magicule_cost)
        creature.free()
    _check(kinds_ok and skills.size() == 12 and CATALOGUE.resource_errors().is_empty(), "Twelve region kinds: scene, four-direction sprites, specimen, material and a Common skill on the damage curve with an effect")
    var frames: SpriteFrames = SPRITES.frames("frost_bear")
    _check(frames.has_animation("walk_left") and frames.get_frame_count("walk_left") == 4 and frames.has_animation("idle_up") and frames.has_animation("dead"), "Region creatures walk in four directions (Ninja Adventure sheets)")
    var shopkeepers := true
    for npc in ["merchant_verdant", "merchant_frost", "merchant_desert", "merchant_sakura", "merchant_amber", "merchant_marsh", "merchant_ember", "merchant_harrow", "camp_trader", "camp_smith", "traveller", "ferryman"]:
        shopkeepers = shopkeepers and SPRITES.has_set(npc) and ResourceLoader.exists("res://assets/game/sprites/%s/%s_face.png" % [npc, npc])
    _check(shopkeepers, "Every shopkeeper and the ferryman has a body and a portrait")
    # --- Levels: the ferry lands are harder than the home continent
    var home_max := 0
    var ferry_min := 99
    for entry in REGION.CREATURES:
        if not entry[1] in KINDS:
            continue
        var region: int = MAP.region_at(REGION.at(entry[2]))
        var level: int = REGION.level_of(entry[0], entry[3])
        if region in MAP.BY_FERRY:
            ferry_min = mini(ferry_min, level)
        else:
            home_max = maxi(home_max, level)
    _check(home_max <= 13 and ferry_min >= 12 and REGION.SPOTS.size() == 20, "Home-continent creatures reach level 13; ferry lands start at 12 (up to 20); two leveling spots per region")
    # --- In a world: spawned, animated, analyzable
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    var bear: Node2D = world.entity_by_id("frost_bear_1")
    _check(bear != null and bear.kind == "frost_bear" and bear.level == 10 and bear.get_node("Health").maximum == preload("res://scripts/enemies/forest_gnasher.gd").scaled_health(1, 10), "Region creatures are spawned at their place with their level's HP")
    bear.set_physics_process(false)
    bear.position += Vector2(20, 0)
    await _frames(2)
    _check(String(bear.body_sprite.animation).ends_with("_right") and bear.body_sprite.scale == Vector2.ONE, "They face where they move and are drawn at full size")
    bear.get_node("Health").take_damage(9999)
    await _frames(2)
    _check(bear.body_sprite.animation == "dead" and not is_zero_approx(bear.body_sprite.rotation), "Defeated, they lie on their side")
    var actor = world.get_local_player()
    var gained: Array = actor.get_node("SkillBook").record_analysis(&"frost_bear")
    _check(gained.map(func(skill): return String(skill.id)) == ["frost_maul"], "Analyzing a Frost Bear teaches Frost Maul")
    world.queue_free()
    await _frames()
    # --- Verticality
    var rim := Vector2i.ZERO
    var wall := Vector2i.ZERO
    var ramp := Vector2i.ZERO
    var levels := {}
    for y in range(-200, -100):
        for x in range(120, 260):
            var cliff: int = MAP.cliff(x, y)
            if cliff == MAP.Cliff.RIM and rim == Vector2i.ZERO:
                rim = Vector2i(x, y)
            if cliff == MAP.Cliff.WALL_TOP and wall == Vector2i.ZERO:
                wall = Vector2i(x, y)
            levels[MAP.data().height[MAP.vertex_index(x, y)]] = true
    for y in range(-80, 80):
        for x in range(550, 640):
            if ramp == Vector2i.ZERO and MAP.heights(x, y).min() != MAP.heights(x, y).max() and MAP.ramp(x, y):
                ramp = Vector2i(x, y)
    _check(levels.has(1) and levels.has(2), "Frostpeak's mountain rises in two levels")
    _check(rim != Vector2i.ZERO and MAP.solid(rim.x, rim.y) and wall != Vector2i.ZERO and MAP.solid(wall.x, wall.y), "Plateau rims are ledges and their south faces rock walls nobody can walk through")
    _check(ramp != Vector2i.ZERO and not MAP.solid(ramp.x, ramp.y), "Where a road crosses a rim it ramps up (Sakura's shrine path)")
    print("Region creature checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
