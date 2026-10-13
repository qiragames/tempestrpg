extends SceneTree
## Character sprites (step 19): animation sets built from the prepared sheets, race and mimic
## bodies, movement/attack/defeat animations on host and replicas, creature tiers and states,
## the ally's evolution look, and that presentation never changes collision or rules.
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
var checks := 0
var failures := 0
var world: Node2D
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
    # --- Library
    var slime: SpriteFrames = SPRITES.frames("slime")
    var human: SpriteFrames = SPRITES.frames("human")
    var gnasher: SpriteFrames = SPRITES.frames("gnasher")
    var directions_ok := true
    for direction in SPRITES.DIRECTIONS:
        directions_ok = directions_ok and slime.get_frame_count("walk_" + direction) == 4 and human.get_frame_count("walk_" + direction) == 4 and human.has_animation("attack_" + direction) and human.has_animation("idle_" + direction)
    _check(directions_ok and slime.has_animation("dead") and human.has_animation("dead"), "Races have idle/walk/attack in four directions plus a defeat pose")
    _check(gnasher.get_frame_count("idle") == 4 and gnasher.get_frame_count("run") == 6 and gnasher.get_frame_count("death") == 6 and not gnasher.get_animation_loop("death"), "Goblin-look creatures: 4 idle, 6 run and 6 death frames (death plays once)")
    _check(SPRITES.frames("slime") == slime, "Animation sets are built once and shared")
    var offsets: Dictionary = gnasher.get_meta("offsets")
    _check(offsets.run.y < 0.0 and offsets.idle.y < 0.0 and absf(human.get_meta("offsets").walk_down.y - (-1.0)) < 0.01, "Feet are aligned to the same spot for 16x16 and larger canvases")
    _check(SPRITES.direction_name(Vector2.LEFT) == "left" and SPRITES.direction_name(Vector2(0.2, -1)) == "up" and SPRITES.direction_name(Vector2(1, 0.3)) == "right", "Facing picks the nearest of four directions")
    var all_ok := true
    for id in ["slime", "human", "demon", "gnasher", "thornback", "goblin", "hobgoblin"]:
        all_ok = all_ok and SPRITES.has_set(id) and SPRITES.frames(id).get_animation_names().size() > 0
    _check(all_ok, "Every body set loads from assets/game/sprites")
    # --- Characters
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    actor.position = Vector2(100, 600)
    var radius: float = actor.get_node("CollisionShape2D").shape.radius
    await _frames(15)
    _check(is_instance_valid(actor.body_sprite) and actor.body_sprite.sprite_frames == slime and actor.body_sprite.animation.begins_with("idle_"), "The Slime shows its animated body, idle")
    actor.facing = Vector2.LEFT
    actor.position += Vector2(-3, 0)
    await process_frame
    _check(actor.body_sprite.animation == "walk_left", "Moving plays the walk cycle in the facing direction")
    await _frames(15)
    _check(actor.body_sprite.animation == "idle_left", "Standing still returns to idle")
    actor.choose_race("Human")
    await process_frame
    _check(actor.body_sprite.sprite_frames == human, "A Human uses the Human body")
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    actor.get_node("Magicules")._current = actor.get_node("Magicules").maximum
    actor.get_node("MeleeAttack").attack(Vector2.DOWN)
    actor.facing = Vector2.DOWN
    await process_frame
    _check(actor.body_sprite.animation == "attack_down", "Attacking shows the attack frame")
    actor.choose_race("Demon")
    await process_frame
    _check(actor.body_sprite.sprite_frames == SPRITES.frames("demon"), "A Demon uses the Demon body")
    actor.choose_race("Slime")
    actor.get_node("SkillBook").record_analysis(&"forest_gnasher")
    actor.form_cooldown = 0.0
    actor.get_node("Magicules")._current = actor.get_node("Magicules").maximum
    actor.try_transform("gnasher")
    await process_frame
    _check(actor.body_sprite.sprite_frames == gnasher and actor.body_sprite.modulate == actor.MIMIC_TINT, "Gnasher mimicry shows the Gnasher body in the slime's own colours")
    _check(is_equal_approx(actor.get_node("CollisionShape2D").shape.radius, actor.FORMS.FORMS.gnasher.radius), "The form's collision radius is still set by the form rules, not the sprite")
    actor.form_cooldown = 0.0
    actor.try_transform("slime")
    await process_frame
    _check(actor.body_sprite.sprite_frames == slime and is_equal_approx(actor.get_node("CollisionShape2D").shape.radius, radius), "Back to the slime body and its original collision radius")
    actor.get_node("Health").take_damage(999)
    await process_frame
    _check(actor.body_sprite.animation == "dead", "Defeat shows the defeat pose")
    # --- A replica animates from snapshot positions alone
    var replica = load("res://scenes/player/player.tscn").instantiate()
    replica.character_id = "replica"
    replica.local_controlled = false
    replica.position = Vector2(200, 600)
    world.add_child(replica)
    replica.configure_replica()
    await _frames(2)
    replica.position += Vector2(0, 4)
    replica.facing = Vector2.DOWN
    await process_frame
    _check(replica.body_sprite.animation == "walk_down", "Other players animate from their replicated positions")
    # --- Creatures
    var thing = world.entity_by_id("gnasher_2")
    var thornback = world.entity_by_id("thornback_1")
    _check(thing.body_sprite.sprite_frames == gnasher and thornback.body_sprite.sprite_frames == SPRITES.frames("thornback"), "Gnasher and Thornback have their own bodies")
    thing.set_difficulty(2)
    await process_frame
    _check(is_equal_approx(thing.body_sprite.scale.x, 1.15) and thing.body_sprite.modulate == thing.TIER_TINT[2], "Elites are tinted and slightly larger")
    thing.state = thing.State.WINDUP
    await process_frame
    _check(thing.body_sprite.modulate.g < 0.5, "The bite wind-up flashes red")
    thing.state = thing.State.IDLE
    var start: Vector2 = thing.position
    thing.position += Vector2(-5, 0)
    await process_frame
    _check(thing.body_sprite.animation == "run" and thing.body_sprite.flip_h, "Moving creatures run and face their direction")
    thing.position = start
    thing.get_node("Health").take_damage(999)
    await _frames(2)
    _check(thing.body_sprite.animation == "death", "Defeated creatures play their death animation")
    # --- Ally evolution look
    var ally = world.entity_by_id("ally_goblin_1")
    _check(ally.body_sprite.sprite_frames == SPRITES.frames("goblin"), "The nameless goblin ally uses the hooded goblin body")
    ally.race = "Hobgoblin"
    await process_frame
    _check(ally.body_sprite.sprite_frames == SPRITES.frames("hobgoblin"), "Naming evolves its look into the armored Hobgoblin")
    world.queue_free()
    await _frames()
    print("Sprite checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
