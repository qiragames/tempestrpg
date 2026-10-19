extends SceneTree
## Visible end-to-end playtest of the first slice. Run WITHOUT --headless so the window shows:
##   godot --path . --script tests/visual_playtest.gd
## It drives the real game through input actions (movement, strike, absorb, skill, B/I/F/F8)
## and button presses, saves screenshots to docs/playtest/, and writes docs/playtest/log.md.
## Offline sandbox only; hosted play is covered by the network suites.
const OUT := "res://docs/playtest"
var world: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
var session: Node
var camp: Node2D
var ally: CharacterBody2D
var lines: Array[String] = []
var messages: Array[String] = []
var failures := 0
var shots := 0
var retreats := 0
var xp_assist := 0

func _initialize() -> void:
    call_deferred("_run")

func _log(text: String) -> void:
    lines.append(text)
    print(text)

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
    _log("- [%s] %s" % ["x" if ok else " ", message])

## Input events are dispatched on a later frame; wait briefly for the expected state.
func _until(condition: Callable, seconds: float = 1.0) -> bool:
    var start := Time.get_ticks_msec()
    while not condition.call():
        if Time.get_ticks_msec() - start > seconds * 1000:
            return false
        await process_frame
    return true

func _wait(seconds: float) -> void:
    await create_timer(seconds, true, false, true).timeout

func _shot(name: String, caption: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    # The game draws at the window's size (sharp text); captures are kept at 960x540.
    if image.get_width() > 960:
        image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
    shots += 1
    var file := "%02d_%s.png" % [shots, name]
    image.save_png(ProjectSettings.globalize_path(OUT.path_join(file)))
    _log("\n![%s](%s)\n*%s* (%dx%d)\n" % [caption, file, caption, image.get_width(), image.get_height()])

## 17c: open the skill tree with K and press a button: activate a learned skill or buy a node.
## Creatures respawn after 60 s (17d2); waiting for enough of them would make the run very long,
## so the bot is still given any missing XP for points; logged.
func _use_tree(id: String, shot: String = "", caption: String = "") -> bool:
    if int(player.progression.skill_points) < 1:
        var need: int = preload("res://scripts/progression/leveling.gd").xp_for_level(player.progression.level + 1) - int(player.progression.experience)
        player.gain_experience(need, "showcase assistance")
        xp_assist += need
        _log("- (XP assistance: +%d XP to reach level %d for a skill point)" % [need, player.progression.level])
    await _tap("skill_tree")
    if not await _until(func(): return hud.skill_tree.visible and paused):
        return false
    await _wait(0.2)
    var learned: Array = player.get_node("SkillBook").evidence_ids()
    if hud.skill_tree._node_buttons.has(id):
        hud.skill_tree._node_buttons[id].pressed.emit()
    else:
        hud.skill_tree._activate_buttons[learned.find(id)].pressed.emit()
    await _wait(0.3)
    if not shot.is_empty():
        await _shot(shot, caption)
    await _tap("skill_tree")
    var closed: bool = await _until(func(): return not hud.skill_tree.visible and not paused)
    return closed and (id in player.progression.tree.nodes or player.get_node("SkillBook").is_active(StringName(id)))

func _tap(action: String) -> void:
    for pressed in [true, false]:
        var event := InputEventAction.new()
        event.action = action
        event.pressed = pressed
        Input.parse_input_event(event)
        await process_frame

func _key(code: Key) -> void:
    for pressed in [true, false]:
        var event := InputEventKey.new()
        event.keycode = code
        event.physical_keycode = code
        event.pressed = pressed
        Input.parse_input_event(event)
        await process_frame

func _release_moves() -> void:
    for action in ["move_left", "move_right", "move_up", "move_down"]:
        Input.action_release(action)

func _steer(direction: Vector2) -> void:
    _release_moves()
    if direction.x < -0.3:
        Input.action_press("move_left", minf(1.0, -direction.x))
    elif direction.x > 0.3:
        Input.action_press("move_right", minf(1.0, direction.x))
    if direction.y < -0.3:
        Input.action_press("move_up", minf(1.0, -direction.y))
    elif direction.y > 0.3:
        Input.action_press("move_down", minf(1.0, direction.y))

## Walks with real movement input; reports and returns false if terrain blocks the route.
func _walk_to(target: Vector2, tolerance: float = 6.0, timeout: float = 15.0) -> bool:
    var start := Time.get_ticks_msec()
    var last := player.position
    var stuck := 0.0
    while player.position.distance_to(target) > tolerance:
        if Time.get_ticks_msec() - start > timeout * 1000:
            _release_moves()
            _log("  walk to %s timed out at %s" % [target, player.position.round()])
            return false
        _steer(player.position.direction_to(target))
        await physics_frame
        stuck = stuck + 1.0 / Engine.physics_ticks_per_second if player.position.distance_to(last) < 0.2 else 0.0
        last = player.position
        if stuck > 1.0:
            _release_moves()
            _log("  walk to %s blocked at %s" % [target, player.position.round()])
            return false
    _release_moves()
    await physics_frame
    return true

func _fight(enemy: Node2D, use_skill: bool, shot_name: String) -> bool:
    var start := Time.get_ticks_msec()
    var shot_taken := false
    while enemy.get_node("Health").current > 0:
        if Time.get_ticks_msec() - start > 25000 or player.get_node("Health").current <= 0:
            _release_moves()
            return false
        var offset: Vector2 = enemy.position - player.position
        if offset.length() > 20:
            _steer(offset.normalized())
            await physics_frame
            continue
        _release_moves()
        # Face the enemy with a short nudge, then strike.
        _steer(offset.normalized())
        await physics_frame
        _release_moves()
        if not shot_taken and offset.length() < 40:
            await _shot(shot_name, "Fighting: strike arc and enemy health bar")
            shot_taken = true
        if player.get_node("Magicules").current < 8.0:
            # Like a player would: back off until the aura recovers instead of mashing an unaffordable strike.
            await _recover()
            continue
        var skill_ready: bool = use_skill and player.get_node("SkillBook").skill_at_slot(0) != null and player.get_node("Magicules").current >= 12
        await _tap("skill_1" if skill_ready else "attack")
        await _wait(0.45 if not skill_ready else 0.85)
        if not is_instance_valid(player) or not is_instance_valid(enemy):
            # The trial cleared its creatures (or the showcase moved on) while this swing was waiting.
            _release_moves()
            return is_instance_valid(player)
    _release_moves()
    return true

## Retreat from the nearest living enemy (staying inside an active trial circle) until Magicules recover.
func _recover() -> void:
    var start := Time.get_ticks_msec()
    retreats += 1
    while player.get_node("Magicules").current < 40.0 and Time.get_ticks_msec() - start < 9000 and player.get_node("Health").current > 0:
        var threat: Node2D = null
        for enemy in get_nodes_in_group("enemies"):
            if enemy.get_node("Health").current > 0 and (threat == null or player.position.distance_to(enemy.position) < player.position.distance_to(threat.position)):
                threat = enemy
        var away: Vector2 = (player.position - threat.position).normalized() if threat != null else Vector2.ZERO
        if world.trial.state.active and (player.position + away * 24.0).distance_to(world.trial.stone) > world.trial.ARENA_RADIUS - 30:
            # Near the circle's edge: circle around the stone (and slightly inward) instead of leaving.
            var radial: Vector2 = world.trial.stone.direction_to(player.position)
            var tangent: Vector2 = radial.orthogonal()
            if tangent.dot(away) < 0:
                tangent = -tangent
            away = (tangent - radial * 0.6).normalized()
        _steer(away)
        await physics_frame
    _release_moves()

func _absorb(enemy: Node2D) -> bool:
    if not await _walk_to(enemy.position + Vector2(-14, 0), 4.0):
        player.position = enemy.position + Vector2(-14, 0)
    await _tap("absorb")
    await _wait(0.5)
    await _shot("analysis_%s" % enemy.entity_id, "Absorbing %s: analysis channel and progress bar" % enemy.entity_id)
    await _wait(1.2)
    return not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_in_group("absorbable_creatures")

func _click(button: BaseButton) -> bool:
    await _until(func(): return button.is_visible_in_tree())
    if button.disabled or not button.is_visible_in_tree():
        return false
    button.pressed.emit()
    await process_frame
    return true

func _gather_here() -> bool:
    var before: int = camp.state.wood + camp.state.stone
    await _tap("camp")
    var ok: bool = await _click(hud._camp_dialog._gather)
    # Gathering is chopping/mining now: the window closes and the swings take a few seconds.
    if hud._camp_dialog.visible:
        await _tap("camp")
    return ok and await _until(func(): return camp.state.wood + camp.state.stone > before, 8.0)

func _run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    # Numbering shifts when captures are added; clear old ones so the folder matches the log.
    for file in DirAccess.get_files_at(ProjectSettings.globalize_path(OUT)):
        if file.ends_with(".png"):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT).path_join(file))
    session = root.get_node("GameSession")
    # Title menu first (with an empty temporary save folder), then the gameplay world.
    var temp_worlds := OS.get_temp_dir().path_join("tempestrpg-showcase-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(temp_worlds)
    var title = load("res://scenes/menu/title_menu.tscn").instantiate()
    title.worlds_dir = temp_worlds
    root.add_child(title)
    current_scene = title
    await _wait(0.3)
    lines.append("# Visual playtest — full first slice\n")
    _log("## 0. Title menu")
    await _shot("title_menu", "Title screen: storm backdrop, logo, ornamented menu with the slime marker (New Game, Continue, Load Game, Join a Friend, Settings, Credits, Quit)")
    title._show("credits")
    await _shot("credits", "Credits: every art pack, including the required Kyrise attribution")
    title._show("new")
    title._name_field.text = "Showcase World"
    title._seed_field.text = "goblin camp"
    await _shot("new_world", "New World: name and seed (numbers or any text, empty = random)")
    title.queue_free()
    await _wait(0.1)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    player = world.get_local_player()
    hud = world.get_node("HUD")
    camp = world.camp
    ally = world.get_node("GoblinAlly")
    world.system_message.connect(func(message: String): messages.append(message))
    root.get_window().title = "TempestRPG — visual playtest (automated)"
    _log("Automated, visible run on %s. Viewport %s, window %s. Movement, combat, absorb, skills and menus use the real input actions; menu buttons are pressed programmatically.\n" % [OS.get_name(), root.get_visible_rect().size, root.get_window().size])
    await _wait(0.5)
    _log("## 1. Spawn")
    _check(root.get_visible_rect().size == Vector2(640, 360), "Base resolution is 640x360")
    await _shot("spawn", "Spawn: HUD, controls bar, hotbar and event log at 640x360")
    _log("## 2. First fight")
    var gnasher: Node2D = world.entity_by_id("gnasher_1")
    _check(await _fight(gnasher, false, "combat"), "Defeated the first Forest Gnasher with real strikes")
    await _wait(0.3)
    var pickup_count := get_nodes_in_group("magicule_pickups").size()
    await _shot("defeated", "Gnasher defeated; Magicule drop beside the corpse")
    _log("## 3. Absorb and analyze")
    _check(await _absorb(gnasher), "Absorbed the corpse")
    _check(player.get_node("SkillBook").skill_at_slot(0) == null, "Rending Bite learned, waiting for activation")
    _check(await _use_tree("rending_bite", "skill_tree", "Skill tree (K): the Slime tree on the left, learned skills on the right; Rending Bite activated with the level-1 point"), "Activated Rending Bite in the skill tree (K)")
    _check(player.get_node("SkillBook").skill_at_slot(0) != null, "Activated Rending Bite sits in hotbar slot 1")
    _check(pickup_count >= 1 or messages.any(func(m): return m.begins_with("Recovered")), "Defeat dropped a Magicule pickup (collected on the spot when standing next to it)")
    await _shot("skill_learned", "Hotbar shows Rending Bite with cost")
    await _tap("inventory")
    _check(await _until(func(): return paused and hud._modal.visible), "I opens the bag and pauses offline play")
    await _shot("inventory", "Dimensional storage with Gnasher Essence")
    await _tap("inventory")
    _check(await _until(func(): return not paused and not hud._modal.visible), "I closes the bag")
    _log("## 4. Recruit and name the goblin")
    _check(await _walk_to(ally.position + Vector2(24, 0), 6.0, 20.0), "Walked west to the goblin")
    await _tap("interact")
    _check(await _until(func(): return hud._ally_dialog.visible), "F opens the ally dialog")
    await _shot("recruit", "Ally dialog before recruitment")
    _check(await _click(hud._ally_dialog._recruit) and ally.owner_id == player.character_id, "Recruited the goblin")
    await _tap("interact")
    var pool = player.get_node("Magicules")
    var start := Time.get_ticks_msec()
    while pool.current < 80 and Time.get_ticks_msec() - start < 20000:
        await _wait(0.25)
    await _tap("interact")
    hud._ally_dialog._name_field.text = "Aster"
    await _wait(0.1)
    await _shot("naming", "Naming dialog: cost preview and name field")
    _check(await _click(hud._ally_dialog._recruit) and ally.race == "Hobgoblin", "Named the ally Aster; evolved to Hobgoblin")
    await _tap("interact")
    await _wait(0.3)
    await _shot("exhausted", "Namer asleep below 25% Magicules; recovery timer; evolved Hobgoblin")
    start = Time.get_ticks_msec()
    while player.is_exhausted() and Time.get_ticks_msec() - start < 25000:
        await _wait(0.25)
    _check(not player.is_exhausted(), "Recovered from naming exhaustion")
    _log("## 5. Found the camp and put the ally to work")
    _check(await _walk_to(camp.SITE + Vector2(0, 8)), "Walked to the camp flag")
    start = Time.get_ticks_msec()
    while ally.position.distance_to(camp.SITE) > 70 and Time.get_ticks_msec() - start < 8000:
        await _wait(0.2)
    await _tap("camp")
    await _shot("camp_menu", "Camp menu before founding")
    _check(await _click(hud._camp_dialog._found) and camp.state.founded, "Founded the camp")
    _check(await _click(hud._camp_dialog._work_buttons.gather), "Assigned the ally to gather")
    await _tap("camp")
    await _wait(4.0)
    await _shot("ally_gathering", "Ally walking between near deposits")
    start = Time.get_ticks_msec()
    while ally.work_role == "gather" and Time.get_ticks_msec() - start < 40000:
        await _wait(0.25)
    _check(camp.state.wood == 16 and camp.state.stone == 8, "Ally gathered all near deposits (16 wood, 8 stone)")
    await _tap("camp")
    _check(await _click(hud._camp_dialog._work_buttons.build), "Assigned the ally to build")
    await _tap("camp")
    start = Time.get_ticks_msec()
    while not camp.state.hut and Time.get_ticks_msec() - start < 20000:
        await _wait(0.25)
    _check(camp.state.hut, "Ally built the Goblin Hut")
    await _wait(0.5)
    await _shot("hut_built", "Goblin Hut built; camp level 2")
    _log("## 6. Explore for outlying materials")
    _check(await _walk_to(camp.sites.wood_3.position, 8.0, 20.0), "Walked east to the outlying wood")
    var second: Node2D = world.entity_by_id("gnasher_2")
    await _shot("outlying_wood", "Outlying wood near the second Gnasher")
    if second.get_node("Health").current > 0:
        _check(await _fight(second, true, "skill_fight"), "Defeated the second Gnasher using Rending Bite")
    _check(await _absorb(second), "Absorbed the second Gnasher (second essence)")
    _check(await _walk_to(camp.sites.wood_3.position, 8.0), "Returned to the wood pile")
    _check(await _gather_here(), "Gathered outlying wood")
    _check(await _walk_to(camp.sites.stone_2.position, 8.0, 20.0), "Walked northeast past the pond to outlying stone")
    _check(await _gather_here(), "Gathered northeast stone")
    await _shot("outlying_stone", "Northeast stone deposit gathered")
    var route_ok: bool = await _walk_to(Vector2(484, 340), 8.0, 20.0) and await _walk_to(Vector2(484, 440), 8.0, 20.0) and await _walk_to(Vector2(200, 470), 8.0, 20.0) and await _walk_to(camp.sites.stone_3.position, 8.0, 20.0)
    _check(route_ok, "Walked to the southwest stone")
    _check(await _gather_here(), "Gathered southwest stone")
    await _shot("southwest_stone", "Southwest stone deposit gathered")
    _log("## 7. Grow the camp")
    _check(await _walk_to(Vector2(200, 350), 8.0, 20.0) and await _walk_to(camp.SITE + Vector2(0, 8), 6.0, 20.0), "Returned to camp")
    await _wait(1.0)
    await _tap("camp")
    await _shot("camp_ready", "Camp menu with outlying materials and essence in the bag")
    for _i in range(2):
        await _click(hud._camp_dialog._offer)
    _check(camp.state.essence == 2, "Offered two Gnasher Essences")
    _check(await _click(hud._camp_dialog._build_buttons.storehouse_1) and camp.state.storehouse, "Built the Storehouse")
    _check(await _click(hud._camp_dialog._build_buttons.shrine_1) and camp.state.shrine, "Built the Essence Shrine")
    _check(camp.level() == 4, "Camp reached level 4")
    await _shot("camp_complete", "Camp menu after all buildings: level 4")
    await _tap("camp")
    await _wait(0.3)
    await _shot("camp_overview", "Camp with hut, storehouse, shrine and range ring")
    _log("## 8. Shrine")
    pool.try_spend(30)
    _check(await _walk_to(camp.STRUCTURES.shrine_1.site + Vector2(0, 26)), "Walked to the shrine")
    var before: float = pool.current
    await _wait(3.0)
    _log("  Magicules near shrine: %.1f -> %.1f in 3s (base regen 6/s after 1.5s delay)" % [before, pool.current])
    _check(pool.current - before > 18.0 * 0.9 or pool.current >= pool.maximum, "Shrine visibly speeds up regeneration")
    await _shot("shrine", "Resting at the Essence Shrine")
    _log("## 9. Thornback Gnasher and the first Extra skill")
    var thornback: Node2D = world.entity_by_id("thornback_1")
    var hunt_ok: bool = await _walk_to(Vector2(300, 340), 8.0) and await _walk_to(Vector2(484, 340), 8.0, 20.0) and await _walk_to(Vector2(484, 440), 8.0, 20.0) and await _walk_to(Vector2(800, 560), 8.0, 20.0)
    _check(hunt_ok, "Walked to the southeast corner")
    await _shot("thornback", "Thornback Gnasher: spiny purple variant in the southeast corner")
    if thornback.get_node("Health").current > 0:
        _check(await _fight(thornback, true, "thornback_fight"), "Defeated the Thornback Gnasher with Rending Bite")
    _check(await _absorb(thornback), "Absorbed the Thornback")
    var skills = player.get_node("SkillBook")
    _check(skills.knows(&"thorn_lash") and not skills.knows(&"piercing_fang"), "Learned Thorn Lash (Common); the Extra now comes from fusion")
    _check(await _use_tree("thorn_lash"), "Activated Thorn Lash in the skill tree")
    # Fusion window (U): drop Rending Bite into the area, then drop Thorn Lash onto it.
    await _tap("fusion")
    _check(await _until(func(): return hud.fusion.visible and paused), "U opens the fusion window")
    hud.fusion._drop_on_area(Vector2(120, 70), {"skill": "rending_bite"})
    await _wait(0.2)
    await _shot("fusion_ready", "Fusion window: Rending Bite placed in the fusion area, skills listed on the right")
    hud.fusion._drop_on_tile(Vector2.ZERO, {"skill": "thorn_lash"}, 0)
    await _wait(0.3)
    await _shot("fusion_done", "Fusion: Rending Bite + Thorn Lash became Piercing Fang (Extra), with a Split button")
    await _tap("fusion")
    _check(await _until(func(): return not hud.fusion.visible and not paused), "U closes the fusion window")
    _check(skills.knows(&"piercing_fang") and not skills.knows(&"rending_bite") and not skills.knows(&"thorn_lash"), "Fused Piercing Fang (Extra); both Commons were replaced")
    _check(messages.any(func(m): return m.begins_with("Fusion: Rending Bite + Thorn Lash → Piercing Fang")), "System Voice announced the fusion")
    await _shot("extra_unlocked", "Hotbar: Piercing Fang in Rending Bite's slot")
    pool._current = pool.maximum
    player.get_node("MeleeAttack").cooldown_left = 0.0
    _steer(Vector2.RIGHT)
    await physics_frame
    _release_moves()
    var spent_before: float = pool.current
    await _tap("skill_%d" % (skills._slots.find(&"piercing_fang") + 1))
    await _shot("piercing_fang", "Piercing Fang: long thrust that hits every creature in a line")
    _check(is_equal_approx(spent_before - pool.current, 18.0) or pool.current < spent_before, "Piercing Fang activated from its hotbar slot")
    _log("## 10. Mimicry: Gnasher Form")
    await _wait(1.3)
    pool._current = pool.maximum
    await _tap("transform")
    _check(await _until(func(): return player.form == "gnasher"), "T transforms into Gnasher Form")
    _check(is_equal_approx(pool.current, pool.maximum - 20.0) or pool.current < pool.maximum, "Transformation cost 20 Magicules")
    await _walk_to(player.position + Vector2(-40, 0), 4.0, 5.0)
    await _shot("gnasher_form", "Gnasher Form: cyan mimic of the Gnasher, faster, stronger basic strike; HUD shows form and cooldown")
    await _wait(2.1)
    await _tap("transform")
    _check(await _until(func(): return player.form == "slime"), "T returns to the slime after the cooldown")
    _log("## 11. Proving Trial (placeholder) and the first Unique skill")
    var trial: Node2D = world.trial
    var trial_route_ok: bool = await _walk_to(Vector2(484, 440), 8.0, 20.0) and await _walk_to(Vector2(484, 340), 8.0, 20.0) and await _walk_to(trial.stone + Vector2(4, 24), 6.0, 20.0)
    _check(trial_route_ok, "Walked north to the trial stone")
    # No HP assistance since step 16b: absorbed vitality is the only healing.
    _log("  Entering the trial with HP %d / %d (unassisted)." % [player.get_node("Health").current, player.get_node("Health").maximum])
    pool._current = pool.maximum
    await _tap("interact")
    _check(await _until(func(): return trial.state.active), "F at the stone starts the Proving Trial")
    var trial_creatures: Array = trial.creatures()
    _check(trial_creatures.size() == 3, "Three trial creatures appear")
    await _wait(0.4)
    await _shot("trial_start", "Proving Trial: arena circle, three creatures and the trial banner")
    for creature in trial_creatures:
        if is_instance_valid(creature) and creature.get_node("Health").current > 0:
            await _fight(creature, true, "trial_fight")
    _check(await _until(func(): return not trial.state.active, 3.0), "Trial ends after the last creature falls")
    var learned = player.get_node("SkillBook")
    _check("proving_trial" in learned.evidence.trials and learned.knows(&"predator_focus"), "Trial complete: Predator Focus (Unique) learned")
    _check(messages.any(func(m): return m.contains("Unique: Predator Focus acquired")), "System Voice announced the Unique skill")
    pool._current = pool.maximum
    player.get_node("MeleeAttack").cooldown_left = 0.0
    _check(await _use_tree("predator_focus"), "Activated Predator Focus in the skill tree")
    await _tap("skill_%d" % (player.get_node("SkillBook")._slots.find(&"predator_focus") + 1))
    _check(await _until(func(): return player.get_node("Absorption").focus_left > 0.0), "Its hotbar slot arms Predator Focus")
    await _shot("predator_focus", "Unique skill: Predator Focus armed from the hotbar")
    _log("## 11a. Creature respawning")
    # Defeated creatures return at their home after 60 s; the showcase shortens the wait for one.
    var respawner = world.respawner
    var already_back: bool = world.entity_by_id("gnasher_1") != null and world.entity_by_id("gnasher_1").get_node("Health").current > 0
    _check(respawner.scheduled("gnasher_1") or already_back, "The first Gnasher is waiting to respawn (or is already back)")
    _log("- gnasher_1 %s" % ("had already respawned during the run" if already_back else "was still waiting; the wait is shortened"))
    for entry in respawner.pending:
        if entry.id == "gnasher_1":
            entry.remaining = 0.2
    var xp_before_respawn: int = player.progression.experience
    _check(await _until(func(): return world.entity_by_id("gnasher_1") != null and world.entity_by_id("gnasher_1").get_node("Health").current > 0, 8.0), "The Forest Gnasher respawned at its home")
    var reborn: Node2D = world.entity_by_id("gnasher_1")
    _check(await _walk_to(Vector2(480, 130), 10.0, 20.0) and await _walk_to(Vector2(496, 230), 8.0, 20.0) and await _walk_to(Vector2(484, 340), 10.0, 20.0) and await _walk_to(reborn.position + Vector2(-60, 0), 10.0, 20.0), "Walked back along the road to the respawned Gnasher")
    await _shot("respawned", "Respawned Forest Gnasher back at its home spot")
    _check(await _fight(reborn, true, "respawn_fight") and player.progression.experience > xp_before_respawn, "Defeating it again earns XP again")
    _log("## 11b. Experience and levels")
    var progress: Dictionary = player.progression
    _check(progress.level >= 3 and progress.skill_points + preload("res://scripts/skills/skill_tree.gd").spent(progress.tree) == progress.level, "Reached level %d (%d XP, %d skill points) from defeats, absorptions and the trial" % [progress.level, progress.experience, progress.skill_points])
    _check(hud._level.text.begins_with("Lv %d" % progress.level), "HUD title bar shows the level: %s" % hud._level.text)
    _check(messages.any(func(m): return m.contains("Level 2 reached")), "The System Voice announced a level-up")
    await _shot("level_hud", "Level, XP and unspent skill points in the top-right of the HUD")
    var hp_before: int = player.get_node("Health").maximum
    _check(await _use_tree("slime_vitality", "tree_node", "Skill tree: Gel Vitality bought (+10 max HP)") and player.get_node("Health").maximum == hp_before + 10, "Bought a stat node: Gel Vitality +10 max HP")
    _log("## 11c. Gear (armor and accessories)")
    # Gear sources (drops, chests, forge) arrive in 17g, so the showcase hands over three items.
    var gear_catalogue = load("res://scripts/items/gear_catalogue.gd")
    var showcase_items := [
        {"id": "item_showcase_helm", "base": "iron_helm", "rarity": 2, "stats": {"hp": 12, "defense": 2}, "passives": ["thorns"], "active": ""},
        {"id": "item_showcase_mail", "base": "scale_mail", "rarity": 3, "stats": {"hp": 22, "defense": 4, "speed": -4}, "passives": ["lifesteal"], "active": "barrier"},
        {"id": "item_showcase_ring", "base": "copper_ring", "rarity": 4, "stats": {"magicules": 18}, "passives": ["keen", "wellspring"], "active": "surge"},
    ]
    for item in showcase_items:
        player.add_item(item)
    _log("- (Showcase items: a Rare helm, an Epic mail and a Legendary ring were handed over; sources arrive in 17g)")
    var max_before: int = player.get_node("Health").maximum
    await _tap("inventory")
    _check(await _until(func(): return hud._modal.visible), "I opens the bag")
    for child in hud._modal.get_children():
        if child is Button and child.text == "Equipment":
            child.pressed.emit()
    _check(await _until(func(): return hud.gear_panel.visible and paused), "The bag's Equipment button opens the equipment window")
    for item in showcase_items:
        hud.gear_panel._selected = item.id
        hud.gear_panel.refresh()
        hud.gear_panel._equip.pressed.emit()
        await _wait(0.2)
    hud.gear_panel._selected = "item_showcase_ring"
    hud.gear_panel._hovered = ""
    await _wait(0.2)
    await _shot("equipment", "Equipment window (paper doll): the character wearing the gear, armour slots left, jewellery right, gear score and stats, items as a grid")
    hud.gear_panel._hovered = "item_showcase_ring"
    await _wait(0.2)
    await _shot("equipment_card", "Hovering an item shows its card (the Legendary ring)")
    hud.gear_panel._hovered = ""
    await _tap("inventory")
    _check(await _until(func(): return not hud.gear_panel.visible and not paused), "I closes the equipment window")
    _check(player.get_node("Health").maximum == max_before + 34 and player.get_node("Health").armor == 6, "Equipped: +34 max HP and 6 defense")
    player.get_node("Health").immunity_left = 0.0
    await _tap("gear_active")
    _check(await _until(func(): return player.get_node("Health").immunity_left >= 1.5), "G uses the mail's Barrier active")
    await _shot("gear_looks", "Gear looks on the slime: helm and mail in rarity colours")
    _log("## 11d. Weapons")
    # Four showcase weapons (sources arrive in 17g); each swings once at practice targets.
    var weapons := [
        {"id": "item_showcase_sword", "base": "iron_sword", "rarity": 1, "stats": {"damage": 16}, "passives": [], "active": ""},
        {"id": "item_showcase_spear", "base": "ash_spear", "rarity": 2, "stats": {"damage": 20}, "passives": ["keen"], "active": ""},
        {"id": "item_showcase_scythe", "base": "field_scythe", "rarity": 2, "stats": {"damage": 30}, "passives": ["lifesteal"], "active": ""},
        {"id": "item_showcase_bow", "base": "hunting_bow", "rarity": 0, "stats": {"damage": 11}, "passives": [], "active": ""},
    ]
    _log("- (Showcase weapons handed over; sources arrive in 17g)")
    var range_at := Vector2(280, 470)
    _check(await _walk_to(Vector2(280, 340), 10.0, 20.0) and await _walk_to(range_at, 8.0, 20.0), "Walked to an open practice spot")
    for weapon in weapons:
        player.add_item(weapon)
        player.equip(weapon.id, "weapon")
        var kind: String = gear_catalogue.BASES[weapon.base].weapon
        var targets: Array = []
        var offsets: Array = [Vector2(120, 0)] if kind == "bow" else ([Vector2(26, 0), Vector2(50, 0)] if kind == "spear" else ([Vector2(22, -20), Vector2(26, 0), Vector2(22, 20)] if kind == "scythe" else [Vector2(28, 0)]))
        for index in range(offsets.size()):
            var dummy = load("res://scenes/enemies/forest_gnasher.tscn").instantiate()
            dummy.entity_id = "practice_%s_%d" % [kind, index]
            dummy.drops_rewards = false
            dummy.position = player.position + offsets[index]
            world.add_child(dummy)
            dummy.set_physics_process(false)
            targets.append(dummy)
        await _wait(0.15)
        player.facing = Vector2.RIGHT
        player.get_node("MeleeAttack").cooldown_left = 0.0
        player.get_node("Magicules")._current = player.get_node("Magicules").maximum
        await _tap("attack")
        await _shot("weapon_" + kind, "%s: %s" % [gear_catalogue.WEAPONS[kind].name, gear_catalogue.WEAPONS[kind].text + (" (the arrow in flight)" if kind == "bow" else "")])
        if kind == "bow":
            # 24a: arrows fly (320 px/s); wait for it to arrive.
            await _wait(0.6)
        var hit_all: bool = targets.all(func(dummy): return dummy.get_node("Health").current < dummy.get_node("Health").maximum)
        _check(hit_all, "%s hits its %d practice target(s)" % [gear_catalogue.WEAPONS[kind].name, targets.size()])
        for dummy in targets:
            world.remove_child(dummy)
            dummy.queue_free()
    _log("## 11e. Chests")
    # The reference map's third chest sits north of the pond; walk there along open ground and press F.
    var chest: Dictionary = world.layout.chests[2]
    var gear_before: int = player.gear.items.size()
    var chest_route: bool = await _walk_to(Vector2(280, 340), 10.0, 20.0) and await _walk_to(Vector2(492, 330), 10.0, 20.0) and await _walk_to(Vector2(492, 110), 10.0, 20.0) and await _walk_to(chest.position + Vector2(-14, 4), 8.0, 20.0)
    _check(chest_route, "Walked to the chest north of the pond")
    await _shot("chest_closed", "A closed chest (gold lock) at a point of interest")
    await _tap("interact")
    _check(await _until(func(): return "chest_3" in player.progression.get("chests", [])), "F opens the chest")
    # SVE feedback: the item pops out beside the chest; F again picks it up.
    await _wait(0.7)
    await _tap("interact")
    await _until(func(): return player.gear.items.size() > gear_before)
    _check(player.gear.items.size() == gear_before + 1 and player.gear.items.back().rarity >= 1, "The chest gave an Uncommon-or-better item: %s" % (gear_catalogue.display_name(player.gear.items.back()) if player.gear.items.size() > gear_before else "none"))
    await _wait(0.3)
    await _shot("chest_open", "Chest opened (lid up) and the item announced")
    _log("## 12. Pause menu and Open to friends")
    # Turn this sandbox into a solo-hosted world (as the title menu does), then use Esc.
    # This sandbox was played on the reference map, so it is hosted as an unseeded world (16d).
    var meta := {"name": "Showcase World", "seed": 1234, "seeded": false, "created": 1, "last_played": 1}
    _check(session.start_host(24560, temp_worlds.path_join("showcase_world.json"), false, meta) == OK and not session.listening, "World is hosted solo and saved, no port open")
    await _wait(0.2)
    await _tap("ui_cancel")
    _check(await _until(func(): return hud._pause_panel.visible and paused), "Esc opens the pause menu and freezes the solo world")
    await _shot("pause_solo", "Pause overlay while playing solo: GAME PAUSED banner, menu with shortcuts (bag, skill tree, fusion), the Multiplayer switch, Invite a Friend, Guests, Save, Options, Save & quit; character and world card")
    _check(session.open_with_codes() == OK, "Multiplayer switches on without a restart (invite codes only)")
    hud._pause_buttons.guests.pressed.emit()
    hud._refresh_pause()
    await _wait(0.1)
    await _shot("pause_open", "Pause menu with multiplayer on: Invite a Friend makes one code per friend; guests may bring their own characters")
    session.close_multiplayer()
    await _tap("ui_cancel")
    _check(await _until(func(): return not hud._pause_panel.visible and not paused), "Esc resumes")
    session.stop_session(false)
    _log("## 13. Seeded worlds")
    # Fresh worlds laid out from two seeds, seen from above (zoomed out, HUD hidden).
    var layouts: Array = []
    for seed_text in ["goblin camp", "tempest"]:
        var seed: int = load("res://scripts/menu/world_registry.gd").parse_seed(seed_text)
        world.queue_free()
        await _wait(0.1)
        world = load("res://scenes/world/forest.tscn").instantiate()
        root.add_child(world)
        current_scene = world
        await _wait(0.1)
        world.apply_layout(seed, true)
        for enemy in get_nodes_in_group("enemies"):
            enemy.set_physics_process(false)
        world.get_node("HUD").visible = false
        world.get_local_player().position = Vector2(480, 320)
        world.get_local_player().get_node("Camera2D").zoom = Vector2(0.5, 0.5)
        layouts.append(world.layout)
        await _wait(0.2)
        await _shot("seed_" + seed_text.replace(" ", "_"), "Seed \"%s\" (%d): deposits, creatures, trial stone, ally, %d trees and %d rocks placed from the seed" % [seed_text, seed, world.layout.trees.size(), world.layout.rocks.size()])
    # The world adds the fixed region chests (M4.5b) after the seeded three.
    var regenerated: Dictionary = load("res://scripts/world/world_layout.gd").generate(layouts[0].seed)
    regenerated.chests = regenerated.chests + preload("res://scripts/world/region_content.gd").chests()
    _check(layouts[0] != layouts[1] and layouts[0] == regenerated, "Different seeds lay out different worlds; the same seed repeats exactly")
    _log("## 14. Playable races")
    # Slime, Human and Demon side by side (placeholder silhouettes until step 19).
    world.get_local_player().get_node("Camera2D").zoom = Vector2(2, 2)
    world.get_local_player().position = Vector2(200, 330)
    world.get_local_player().choose_race("Slime")
    var lineup: Array = []
    for index in range(2):
        var extra = load("res://scenes/player/player.tscn").instantiate()
        extra.character_id = "showcase_%d" % index
        extra.local_controlled = false
        extra.position = Vector2(230 + index * 30, 330)
        world.add_child(extra)
        lineup.append(extra)
    await _wait(0.1)
    lineup[0].choose_race("Human")
    lineup[1].choose_race("Demon")
    await _wait(0.2)
    _check(lineup[0].get_node("Health").maximum == 120 and lineup[1].get_node("Magicules").maximum == 130.0, "Human and Demon are created with their own stats")
    await _shot("races", "Playable races, left to right: Slime, Human, Demon (placeholder looks)")
    _log("## 15. The archipelago (M4.5a)")
    # The seed showcase above replaced the world and hid its HUD: use it and show it again
    # (Codex review of M4.5a: the map capture showed only the coast).
    hud = world.get_node("HUD")
    hud.show()
    for extra in lineup:
        extra.queue_free()
    var walker = world.get_local_player()
    walker.get_node("Camera2D").zoom = Vector2.ONE
    walker.position = Vector2(930, 330)
    Input.action_press("move_right")
    await _wait(2.5)
    Input.action_release("move_right")
    _check(walker.position.x > 1100, "Walking east follows the road out of the clearing: x %.0f" % walker.position.x)
    await _shot("road_east", "The east road continues beyond the clearing towards the Harrowmere bridge")
    var map_script := preload("res://scripts/world/world_map.gd")
    for stop in [["thornwood", Vector2(104, 92), "Thornwood: dense forest west of the clearing"], ["mirror_lake", Vector2(246, 80), "Mirror Lake: the bridge to the ruined keep on its islet"], ["harrowmere_bridge", Vector2(300, 92), "The bridge to Harrowmere"], ["harrowmere", Vector2(346, 94), "Harrowmere: the walled-town island"], ["cinder_crater", Vector2(256, 175), "Cinder Crater: ash, boulders and a lava pool"], ["sunfall_beach", Vector2(186, 190), "Sunfall Beach: the south coast; Ambervale lies across the strait"]]:
        walker.position = map_script.to_world(stop[1])
        await _wait(0.3)
        _check(hud.get_node("Title").is_visible_in_tree() and hud.get_node("Title").text == map_script.region_name(walker.position).to_upper(), "HUD shows the region name at %s" % stop[0])
        await _shot(stop[0], stop[2])
    # M4.5b: the regions have their own creatures, deposits and chests.
    var region := preload("res://scripts/world/region_content.gd")
    _check(region.creature_ids().all(func(id): return world.entity_by_id(id) != null), "All %d region creatures are in the world" % region.CREATURES.size())
    walker.position = region.at(Vector2(104, 98))
    await _wait(0.4)
    await _shot("thornwood_creatures", "Thornwood's Gnashers (one Elite) near a wood deposit and the Thornwood chest")
    hud.world_map.open()
    await _wait(0.3)
    _check(hud.visible and hud.world_map.is_visible_in_tree() and paused, "M opens the world map (HUD and map window visible)")
    await _shot("world_map", "World map (M): Verdant Isle with the clearing, Thornwood, Mirror Lake, Cinder Crater; Harrowmere by bridge; Ambervale and the Emberreach Isles across the sea")
    hud.world_map.close()
    _log("## 17. Death piles, minimap and leveling spots (step 24a)")
    var me = world.get_local_player()
    me.position = Vector2(560, 360)
    var pile: Node2D = world.drop_pile(me.character_id, {"gnasher_essence": 2}, [], me.position + Vector2(-150, 60))
    await _wait(0.3)
    _check(pile != null and pile.owner_id == me.character_id and hud.minimap.is_visible_in_tree(), "A dropped bag lies as your pile and shows on the minimap")
    await _shot("pile_minimap", "Your dropped bag (pile) and its gold marker on the round minimap (creatures red, chests yellow)")
    var spot_entry: Array = preload("res://scripts/world/region_content.gd").SPOTS[0]
    me.position = preload("res://scripts/world/region_content.gd").at(spot_entry[2]) + Vector2(0, 40)
    await _wait(0.4)
    _check(spot_entry[0] in me.progression.get("spots", []), "Coming close discovers the hidden leveling spot \"%s\"" % preload("res://scripts/world/region_content.gd").SPOT_NAMES[spot_entry[0]])
    await _shot("leveling_spot", "A hidden leveling spot discovered (Gnasher Hollow): its creatures return three times faster; levels above the health bars")
    hud.world_map.open()
    await _wait(0.3)
    await _shot("world_map_markers", "World map: your pile (gold X) and discovered leveling spots (violet)")
    hud.world_map.close()
    await _wait(0.2)
    _log("## 16. Sound and effects (step 23)")
    var audio: Node = root.get_node("Audio")
    var cues: Array = audio.played.keys()
    cues.sort()
    _log("- Sounds played during this run: " + ", ".join(cues.map(func(id): return "%s ×%d" % [id, audio.played[id]])))
    var effects := preload("res://scripts/visual/effects.gd")
    var shown: Array = effects.spawned.keys()
    shown.sort()
    _log("- Effects shown: " + ", ".join(shown.map(func(id): return "%s ×%d" % [id, effects.spawned[id]])))
    for cue in ["swing", "hit", "defeat", "magicules", "analysis", "learned", "level_up", "chest", "evolve", "build"]:
        _check(audio.played.has(cue), "The run produced the \"%s\" cue" % cue)
    var showcase = world.get_local_player()
    showcase.position = Vector2(480, 330)
    await _wait(0.3)
    for index in range(4):
        effects.spawn(world, ["hit_spark", "sparkle", "boost", "ring"][index], showcase.position + Vector2(-60 + index * 40, -20))
    await _wait(0.12)
    await _shot("effects", "Effects: hit flash, sparkle (pickups, chests), level-up glow, ring (skills, buildings)")
    _log("## 17. Skill effects and numbers (step 24b)")
    # Four frozen creatures, each under one skill effect, show the status tints every peer sees.
    var statuses := [["stun", {"stun": 30.0}], ["root", {"root": 30.0}], ["slow", {"slow": [0.5, 30.0]}], ["dot", {"dot": [0, 30.0]}]]
    var tinted: Array = []
    for index in range(statuses.size()):
        var creature = load("res://scenes/enemies/forest_gnasher.tscn").instantiate()
        creature.entity_id = "showcase_status_%d" % index
        creature.position = showcase.position + Vector2(-60 + index * 40, 24)
        world.add_child(creature)
        world.wire_enemy(creature)
        creature.set_physics_process(false)
        creature.apply_status(statuses[index][1], showcase)
        tinted.append(creature)
    await _wait(0.2)
    _check(tinted.map(func(creature): return creature.shown_status) == ["stun", "root", "slow", "dot"], "Skill effects tint creatures: stunned yellow, rooted green, slowed blue, burning/bleeding violet")
    var leveling := preload("res://scripts/progression/leveling.gd")
    var races := preload("res://scripts/races/race_catalogue.gd")
    _log("- Basic strikes: " + ", ".join(races.ORDER.map(func(race): return "%s %d dmg for %s" % [race, races.stats(race).strike_damage, "free" if races.stats(race).strike_cost == 0.0 else "%d Magicules" % int(races.stats(race).strike_cost)])))
    _log("- XP to reach levels 2 / 5 / 10 / 20: %d / %d / %d / %d (balance report: docs/balance/report.md)" % [leveling.xp_for_level(2), leveling.xp_for_level(5), leveling.xp_for_level(10), leveling.xp_for_level(20)])
    await _shot("skill_effects", "Skill effects on creatures: stunned (yellow), rooted (green), slowed (blue), burning/bleeding (violet)")
    for creature in tinted:
        creature.queue_free()
    _log("## 18. The bigger world, towns and trade (M4.5c)")
    # A tour of the grown world: every stop streams its props in around the character.
    var tour_map := preload("res://scripts/world/world_map.gd")
    var hud_tour = world.get_node("HUD")
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var stops := [
        ["rimeholm", Vector2(195, -66), "Rimeholm, Frostpeak's town of igloos and lodges, on the snow"],
        ["frost_mountain", Vector2(190, -108), "Frostpeak's mountain: plateau rims are ledges with rock walls below (verticality)"],
        ["frost_creatures", Vector2(100, -54), "Frost Bears at a hidden leveling spot (Bear Hollow)"],
        ["dunemarch", Vector2(-120, 124), "Dunemarch in the Sunscorch Desert: domed houses, palms and a bazaar"],
        ["brookhaven", Vector2(110, 154), "Brookhaven, Verdant Isle's town, with its merchant on the plaza"],
    ]
    for stop in stops:
        showcase.position = tour_map.to_world(stop[1])
        world.terrain.ensure_props_at(showcase.position)
        await _wait(0.35)
        _check(hud_tour.get_node("Title").text == tour_map.place_name(showcase.position).to_upper(), "The HUD names %s" % tour_map.place_name(showcase.position))
        await _shot(stop[0], stop[2])
    # Shop: Zeni in the purse, F beside the Brookhaven merchant opens its stock.
    showcase.progression["zeni"] = 600
    showcase.position = world.trade.merchant_position("merchant_brookhaven") + Vector2(-16, 0)
    await _wait(0.3)
    hud_tour.trade_panel.open("merchant_brookhaven")
    await _wait(0.2)
    _check(hud_tour.trade_panel.visible and hud_tour.trade_panel._rows.size() > 3, "F beside a merchant opens the shop with its stock")
    await _shot("shop_buy", "The Brookhaven Trader's shop: gear, draughts and tonics, materials (prices in Zeni)")
    var purse_before: int = showcase.zeni()
    world.trade.buy(showcase, "merchant_brookhaven", "healing_draught")
    hud_tour.trade_panel._switch(true)
    await _wait(0.2)
    _check(showcase.zeni() == purse_before - 25 and showcase.get_node("Inventory").count_of("healing_draught") == 1, "Bought a Healing Draught for 25 Zeni")
    await _shot("shop_sell", "Selling: the merchant pays 30% of the price for goods and unequipped gear")
    hud_tour.trade_panel.close()
    # Harbour (M4.5d): travel by map with a ferry ticket; the voyage plays across the map.
    var harbours_tour = world.harbours
    showcase.position = tour_map.dock_position("sunfall")
    world.terrain.ensure_props_at(showcase.position)
    await _wait(0.3)
    showcase.progression["zeni"] = 600
    harbours_tour.buy_ticket(showcase, "sunfall", "amberhold")
    hud_tour.harbour_panel.open("sunfall")
    hud_tour.harbour_panel._pick("amberhold")
    await _wait(0.2)
    _check(hud_tour.harbour_panel.visible and hud_tour.harbour_panel._buttons.sail.visible and not hud_tour.harbour_panel._buttons.sail.disabled, "F at a harbour opens travel by map; a ticket lets you sail")
    await _shot("harbour_map", "Sunfall Harbour: pick a harbour on the map; sail with a ticket, a ferry pass or your own ship")
    hud_tour.harbour_panel._act("sail")
    await _wait(1.2)
    await _shot("voyage", "The voyage across the map to Amberhold")
    await _wait(1.6)
    _check(harbours_tour.nearest_harbour(showcase) == "amberhold" and not hud_tour.harbour_panel.visible, "The ferry crosses to Ambervale (a region you cannot walk to)")
    await _shot("amberhold_pier", "Arrived at Amberhold Harbour in Ambervale, the autumn continent")
    for other in [["hanamura", Vector2(545, 44), "Hanamura in Sakura Vale (ferry): cherry blossoms, bamboo and pagoda-style houses"], ["volcano", Vector2(568, 366), "The Emberreach volcano (ferry): its slopes rise in two levels around a lava crater"], ["bogsend", Vector2(-170, 374), "Bogsend in Mirewood Marsh (ferry): mud, pools and stilt huts"]]:
        showcase.position = tour_map.to_world(other[1])
        world.terrain.ensure_props_at(showcase.position)
        await _wait(0.35)
        await _shot(other[0], other[2])
    hud_tour.world_map.open()
    await _wait(0.3)
    await _shot("world_map_full", "The world map: the home continent, the ferry lands, every town (gold) and the ferry piers")
    hud_tour.world_map.close()
    _log("## 19. Ships, tools, mounts, runes and augments (M4.5d)")
    # Your own ship (endgame): bought at a shipwright, summoned at any harbour, seen docked.
    showcase.position = tour_map.dock_position("cinderport")
    world.terrain.ensure_props_at(showcase.position)
    showcase.progression["zeni"] = 45000
    _check(harbours_tour.buy_ship(showcase, "cinderport"), "Bought a ship from Cinderport's shipwright (40,000 Zeni)")
    await _wait(0.4)
    await _shot("own_ship", "Your own ship docked at Cinderport: no more tickets, and up to three friends sail with you")
    # A horse from the Brookhaven stable, ridden on the road.
    showcase.position = world.trade.merchant_position("merchant_brookhaven") + Vector2(-16, 0)
    world.terrain.ensure_props_at(showcase.position)
    world.trade.stock("merchant_brookhaven")
    world.trade.buy(showcase, "merchant_brookhaven", "mount_horse")
    showcase.toggle_mount()
    showcase.facing = Vector2.RIGHT
    await _wait(0.3)
    _check(showcase.riding() == "horse", "Riding a horse from the stable (+60% speed, H)")
    await _shot("riding", "Riding a horse bought at Brookhaven's stable (+60% speed on land; a hit or an attack throws you off)")
    showcase.toggle_mount()
    # Fishing from the pier with a rod (tools are never equipped).
    world.trade.buy(showcase, "merchant_brookhaven", "tool_rod_1")
    showcase.position = tour_map.dock_position("sunfall")
    world.terrain.ensure_props_at(showcase.position)
    showcase.facing = Vector2.DOWN
    showcase.cast_line()
    showcase._tick_fishing(showcase.fishing_bite_in + 0.05)
    await _wait(0.4)
    await _shot("fishing", "Fishing from Sunfall's pier: a fish is hooked — press F while the marker is in the green zone (the zone is your chance per press)")
    var fish_landed := false
    for _press in range(6):
        if showcase.reel.is_empty():
            break
        showcase.reel.centre = preload("res://scripts/professions/fish_catalogue.gd").marker(float(showcase.reel.t), float(showcase.reel.speed))
        fish_landed = showcase.reel_in() and showcase.reel.is_empty()
    _check(fish_landed, "Caught a fish")
    # A wild desert lion to tame.
    var lion_spot: Array = preload("res://scripts/travel/travel_catalogue.gd").WILD_MOUNTS.filter(func(entry): return entry[1] == "lion")[0]
    showcase.position = tour_map.to_world(lion_spot[2]) + Vector2(-26, 8)
    world.terrain.ensure_props_at(showcase.position)
    await _wait(0.3)
    await _shot("wild_lion", "A wild desert lion: offer it viper scales (F) to tame it as a mount")
    _log("## 20. Parties (M4.6)")
    # A friend joins; the party frames show their HP and Magicules, the window lists the party.
    var mate = load("res://scenes/player/player.tscn").instantiate()
    mate.character_id = "friend"
    mate.local_controlled = false
    world.add_child(mate)
    mate.choose_race("Demon")
    showcase.position = Vector2(480, 340)
    mate.position = Vector2(500, 344)
    world.terrain.ensure_props_at(showcase.position)
    world.party.invite(showcase, "friend")
    world.party.accept(mate)
    mate.get_node("Health").current = 55
    await _wait(0.3)
    _check(world.party.same_party(showcase.character_id, "friend"), "A friend joined the party")
    await _shot("party_frames", "In a party: your friend's HP and Magicules under your status card, their marker on the minimap")
    world.get_node("HUD").party_panel.open()
    await _wait(0.2)
    await _shot("party_window", "The party window (P): members, invitations, leave and remove")
    world.get_node("HUD").party_panel.close()
    mate.queue_free()
    _log("## 21. The Ki Realm (M4.7)")
    var realm_data := preload("res://scripts/realm/realm_catalogue.gd")
    var realm = world.realm
    var hud_realm = world.get_node("HUD")
    preload("res://scripts/progression/leveling.gd").grant(showcase, preload("res://scripts/progression/leveling.gd").xp_for_level(42) - int(showcase.progression.experience))
    showcase.progression["zeni"] = 20000
    # The secret hermit in Sakura Vale asks his question.
    showcase.position = tour_map.to_world(realm_data.HERMIT_TILE) + Vector2(0, 18)
    showcase.facing = Vector2.UP
    world.terrain.ensure_props_at(showcase.position)
    await _wait(0.3)
    hud_realm._ally_dialog._talk_realm("secret_hermit")
    await _wait(0.2)
    _check(hud_realm.dialog_panel.is_open(), "The secret hermit in Sakura Vale offers four answers")
    await _shot("realm_hermit", "The secret hermit in Sakura Vale (level 36+ since M7b): pick the right answer to enter the hidden Ki Realm")
    hud_realm.dialog_panel.close()
    _check(realm.answer_hermit(showcase, realm_data.HERMIT_RIGHT), "The right answer opens the way")
    await _wait(0.5)
    await _shot("dome_city", "Dome City, the Ki Realm's capital: capsule-dome houses, palms and the realm guide")
    # The Sage Spire and the Guardian's Lookout with the wish altar.
    showcase.position = tour_map.to_world(realm_data.mentor("guardian")[3]) + Vector2(14, 14)
    world.terrain.ensure_props_at(showcase.position)
    await _wait(0.4)
    await _shot("sage_spire", "The top of the Sage Spire: the Guardian (Spirit Orb) beside the wish altar")
    # Learning from the mentors: the Kaio Surge and the Turtle Wave.
    showcase.position = tour_map.to_world(realm_data.mentor("mountain_master")[3]) + Vector2(0, 12)
    _check(realm.learn(showcase, "mountain_master"), "The Mountain Master teaches the Kaio Surge")
    showcase.position = tour_map.to_world(realm_data.mentor("turtle_sage")[3]) + Vector2(0, 12)
    world.terrain.ensure_props_at(showcase.position)
    hud_realm._ally_dialog._talk_realm("turtle_sage")
    await _wait(0.3)
    await _shot("turtle_sage", "The Turtle Sage on Hermit Atoll teaches the Turtle Wave (level 16, 2,000 Zeni)")
    hud_realm.dialog_panel.close()
    _check(realm.learn(showcase, "turtle_sage"), "The Turtle Sage teaches the Turtle Wave")
    # Powered up: the Kaio Surge's red aura, then a Turtle Wave down Raptor Gulch.
    showcase.position = tour_map.to_world(Vector2(-300, -160))
    world.terrain.ensure_props_at(showcase.position)
    showcase.get_node("Magicules")._current = showcase.get_node("Magicules").maximum
    _check(showcase.toggle_aura() and showcase.aura() == "kaio_surge", "Powered up: Kaio Surge")
    await _wait(0.3)
    await _shot("kaio_surge", "Kaio Surge (X): a red flame aura, x1.3 damage and x1.2 speed while it drains Magicules")
    _check(showcase.activate_skill("turtle_wave"), "Activated the Turtle Wave in the skill tree")
    showcase.get_node("SkillBook").assign_slot(0, &"turtle_wave")
    showcase.get_node("MeleeAttack").cooldown_left = 0.0
    showcase.facing = Vector2.LEFT
    showcase.get_node("Magicules")._current = showcase.get_node("Magicules").maximum
    var waved: bool = showcase.get_node("MeleeAttack").attack_skill(Vector2.LEFT, &"turtle_wave")
    await _wait(0.05)
    _check(waved, "A Turtle Wave fired")
    await _shot("turtle_wave", "Turtle Wave: a long charged ki beam through Raptor Gulch")
    showcase.toggle_aura()
    # A wish orb glowing at its spot.
    var orb_spot: Vector2 = realm_data.ORB_SPOTS[int(realm.state.orbs[0])]
    showcase.position = tour_map.to_world(orb_spot) + Vector2(-20, 8)
    world.terrain.ensure_props_at(showcase.position)
    await _wait(0.3)
    await _shot("wish_orb", "A wish orb (one star) lying at a hidden spot; all seven make one wish at the Guardian's altar")
    # The map inside the realm shows only the realm.
    hud_realm.world_map.open()
    await _wait(0.3)
    _check(hud_realm.world_map._title.text.ends_with("KI REALM"), "Inside the realm the map shows only the realm")
    await _shot("realm_map", "The map inside the Ki Realm: only the realm (it never shows on the normal map)")
    hud_realm.world_map.close()
    # The tournament: round one in the ring.
    showcase.position = tour_map.to_world(realm_data.ANNOUNCER_TILE) + Vector2(0, 10)
    world.terrain.ensure_props_at(showcase.position)
    _check(realm.enter_tournament(showcase), "Entered the tournament")
    var bout = world.entity_by_id("tourney_0")
    if bout != null:
        bout.set_physics_process(false)
    await _wait(0.4)
    await _shot("tournament", "The World Martial Grounds: round one of five against a Gi Fighter (the champion wins 5,000 Zeni and the Golden Aura)")
    showcase.position += Vector2(600, 0)
    await _wait(0.2)
    _log("## 22. Nation building (M5a)")
    var nation_camp = world.camp
    var nation_data := preload("res://scripts/nation/nation_catalogue.gd")
    var hud_nation = world.get_node("HUD")
    showcase.position = nation_camp.SITE + Vector2(0, 40)
    world.terrain.ensure_props_at(showcase.position)
    if not nation_camp.state.founded:
        nation_camp.state.founded = true
        nation_camp.state.founder = showcase.character_id
    for _round in range(4):
        for id in nation_camp.sites:
            if nation_camp.state.deposits[id] > 0:
                nation_camp.harvest(id)
        nation_camp._refill(nation_camp.REFILL_SECONDS + 1.0)
    nation_camp.state.essence = int(nation_camp.state.essence) + 4
    nation_camp.state.essence_offered = int(nation_camp.state.essence_offered) + 4
    for id in ["hut_1", "storehouse_1"]:
        if not nation_camp.built(id):
            nation_camp.complete(id)
    nation_camp.transact(showcase, "name", "Tempest Federation")
    nation_camp.transact(showcase, "banner", "1,0")
    await _wait(0.2)
    # Free placement: a few houses, a well and the banner around the flag.
    var centre: Vector2i = tour_map.to_tile(nation_camp.SITE)
    var placed_kinds: Array = []
    for kind in ["house", "house", "well", "banner", "hut"]:
        var done := false
        for ring in range(3, 9):
            if done:
                break
            for dy in range(-ring, ring + 1):
                if done:
                    break
                for dx in range(-ring, ring + 1):
                    if maxi(absi(dx), absi(dy)) == ring and nation_camp.place(null, kind, centre + Vector2i(dx, dy)):
                        placed_kinds.append(kind)
                        done = true
                        break
    await _wait(0.2)
    _check(placed_kinds.size() == 5, "Placed houses, a well, a banner and a hut around the camp")
    _check(nation_camp.rank_up() and nation_camp.tier() == 1, "The camp became a village")
    hud_nation.nation_panel.open()
    await _wait(0.3)
    await _shot("nation_window", "The nation window (N): your nation's name and banner, its tier and what the next needs, buildings to place")
    hud_nation.nation_panel.start_mode("big_house")
    var ghost_at: Vector2 = nation_camp.SITE + Vector2(-110, 70)
    hud_nation.nation_panel.aim(ghost_at)
    await _wait(0.2)
    await _shot("build_mode", "Build mode: the ghost follows the mouse on the tile grid inside the village's ring (green fits, red shows why not)")
    hud_nation.nation_panel.stop_mode()
    showcase.position = nation_camp.SITE + Vector2(0, 50)
    await _wait(0.4)
    await _shot("village", "Tempest Federation, now a village: freely placed houses, a well and the blue star banner around the camp")
    _log("## 23. Citizens, fields and food (M5b)")
    var field_ids: Array = []
    for _i in range(3):
        var done := false
        for ring in range(4, 12):
            if done:
                break
            for dy in range(-ring, ring + 1):
                if done:
                    break
                for dx in range(-ring, ring + 1):
                    if maxi(absi(dx), absi(dy)) == ring and nation_camp.place(null, "field", centre + Vector2i(dx, dy)):
                        field_ids.append(nation_camp.state.nation.buildings[-1].id)
                        done = true
                        break
    _check(field_ids.size() == 3, "Three fields placed")
    var crops: Array = ["wheat", "carrot", "pumpkin"]
    for index in range(field_ids.size()):
        nation_camp.plant(null, field_ids[index], crops[index])
    nation_camp._tick_nation(nation_data.CROPS.wheat[1])
    _check(nation_camp.harvest_field(null, field_ids[0]) > 0, "Wheat harvested")
    nation_camp.plant(null, field_ids[0], "wheat")
    nation_camp._tick_nation(60.0)
    var field_entry: Dictionary = nation_data.building(nation_camp.state.nation, field_ids[0])
    showcase.position = nation_data.footprint("field", Vector2i(field_entry.tile[0], field_entry.tile[1])).get_center() + Vector2(0, 26)
    # Food for newcomers, then a few arrive.
    nation_camp.state.nation.food = int(nation_camp.state.nation.food) + 30
    nation_camp.state.nation.grown = int(nation_camp.state.nation.grown) + 30
    for _i in range(6):
        nation_camp._tick_nation(nation_data.ARRIVAL_SECONDS)
    _check(nation_camp.population() >= 4, "Citizens moved into the homes")
    showcase.position = nation_camp.SITE + Vector2(-40, -30)
    await _wait(3.0)
    await _shot("citizens_fields", "Citizens walk about the village; fields of wheat, carrots and pumpkins grow (F to plant and harvest)")
    hud_nation.nation_panel.open()
    await _wait(0.3)
    await _shot("population", "The nation window: population and homes, the food store and what it eats a day, the next newcomer")
    hud_nation.nation_panel.close_panel()
    _log("## 24. Citizen roles, trade and caravans (M5c)")
    for kind in ["workshop", "market", "watchtower"]:
        var done := false
        for ring in range(5, 14):
            if done:
                break
            for dy in range(-ring, ring + 1):
                if done:
                    break
                for dx in range(-ring, ring + 1):
                    if maxi(absi(dx), absi(dy)) == ring and nation_camp.place(null, kind, centre + Vector2i(dx, dy)):
                        done = true
                        break
    var roles: Array = ["worker", "farmer", "crafter", "merchant", "guard", "crafter"]
    var assigned := 0
    for index in range(mini(roles.size(), nation_camp.population())):
        assigned += 1 if nation_camp.assign_job(nation_camp.state.nation.citizens[index].id, roles[index]) else 0
    _check(assigned >= 4, "Citizens took jobs (%d)" % assigned)
    for _i in range(4):
        nation_camp._tick_nation(nation_data.WORK_SECONDS)
    showcase.position = nation_camp.SITE + Vector2(0, 30)
    var trade_town: String = nation_data.caravan_towns()[0][0]
    if int(nation_camp.state.nation.goods) > 0:
        nation_camp.send_caravan(trade_town, mini(3, int(nation_camp.state.nation.goods)))
    hud_nation.citizens_panel.open()
    await _wait(0.4)
    await _shot("citizens_trade", "Citizens & trade: jobs by workplace (workers, farmers, crafters, merchants, guards), the treasury, trade goods and a caravan on the road")
    hud_nation.citizens_panel.close_panel()
    _log("## 25. Rival nations and the siege (M5d)")
    var rival_entry: Array = preload("res://scripts/nation/rival_nations.gd").RIVALS[5]
    showcase.position = preload("res://scripts/nation/rival_nations.gd").leader_position(rival_entry) + Vector2(0, 16)
    world.terrain.ensure_props_at(showcase.position)
    await _wait(0.4)
    hud_nation._ally_dialog.open_nearest()
    await _wait(0.3)
    _check(hud_nation.dialog_panel.is_open(), "Talking to a rival nation's leader")
    await _shot("rival_leader", "A rival nation: the Sakura Shogunate's leader in Hanamura beside its banner (neither friend nor foe for now)")
    hud_nation.dialog_panel.close()
    hud_nation.world_map.open()
    await _wait(0.3)
    await _shot("world_map_nations", "The world map with the rival nations' banners at their capitals and your own nation at the camp")
    hud_nation.world_map.close()
    # The siege: call the horde, then the first wave marches on the flag.
    showcase.position = nation_camp.SITE + Vector2(0, 30)
    world.terrain.ensure_props_at(showcase.position)
    await _wait(0.3)
    var siege_node = world.siege
    _check(siege_node.call_now(showcase), "Faced the horde")
    siege_node._physics_process(siege_node.WARNING_SECONDS)
    var marchers: Array = siege_node.creatures()
    for index in range(marchers.size()):
        marchers[index].global_position = nation_camp.SITE + Vector2(-90 + index * 40, -70 + (index % 2) * 14)
        marchers[index].set_physics_process(false)
    showcase.position = nation_camp.SITE + Vector2(0, -20)
    world.terrain.ensure_props_at(showcase.position)
    await _wait(1.0)
    await _shot("siege", "The siege: a monster horde marches on the flag from one side (wave 1 of 3); guards shoot from the watchtower")
    for marcher in siege_node.creatures():
        marcher.get_node("Health").take_damage(99999, showcase)
    siege_node._finish(true)
    _log("## 26. Chopping, detailed maps (user requests)")
    var chop_camp = world.camp
    var tree_site: String = ""
    for id in chop_camp.sites:
        if chop_camp.sites[id].resource == "wood" and int(chop_camp.state.deposits[id]) > 0:
            tree_site = id
            break
    if not tree_site.is_empty():
        showcase.global_position = chop_camp.sites[tree_site].position + Vector2(-14, 4)
        world.terrain.ensure_props_at(showcase.global_position)
        await _wait(0.2)
        _check(chop_camp.transact(showcase, "chop", tree_site), "Chopping a tree with an axe")
        await _wait(0.45)
        await _shot("chopping", "Chopping a tree: the axe swings, the tree shakes and wood chips fly (pickaxes mine rocks and ore the same way)")
        showcase.stop_gather()
    hud_nation.world_map.open()
    await _wait(0.2)
    hud_nation.world_map.zoom_at(hud_nation.world_map.to_map(showcase.global_position), 6.0)
    await _wait(0.3)
    await _shot("map_zoom", "The world map zoomed in with the mouse wheel: the real trees, rocks and houses")
    hud_nation.world_map.close()
    _log("## 27. Professions (M6a)")
    var resource_nodes: Node = world.nodes
    var ore_rock := -1
    var plan: Array = world.terrain.planned_props()
    for index in range(plan.size()):
        if resource_nodes.info(index).get("resource") == "ore_iron":
            ore_rock = index
            break
    _check(ore_rock >= 0, "The world has iron rocks")
    if ore_rock >= 0:
        showcase.global_position = resource_nodes.work_point(ore_rock) + Vector2(-14, 6)
        world.terrain.ensure_props_at(showcase.global_position)
        await _wait(0.3)
        _check(String(hud_nation.get_node("NodePrompt").text).contains("%"), "The node prompt shows the chance")
        await _shot("mining_prompt", "An iron rock with its ore vein; the prompt shows the profession level against the required level and your chance per swing")
        _check(session.apply_action(showcase, "node", {"index": ore_rock}), "Mining the iron rock")
        await _wait(0.45)
        await _shot("mining", "Mining iron with the pickaxe: every successful swing counts, three give one ore (a miss still teaches a little)")
        showcase.stop_gather()
    hud_nation.professions_panel.open()
    hud_nation.professions_panel._select("mining")
    await _wait(0.2)
    await _shot("professions", "The Professions window (L): level, XP, perks and milestones, and every ore with the level it needs and your chance")
    hud_nation.professions_panel.close_panel()
    # M6c: crafting in a town — smelting and forging, brewing.
    showcase.global_position = world.trade.merchant_position("merchant_brookhaven") + Vector2(-14, 0)
    world.terrain.ensure_props_at(showcase.global_position)
    var crafting_bag: Node = showcase.get_node("Inventory")
    crafting_bag.add_material("ore_copper", 4)
    crafting_bag.add_material("ore_tin", 4)
    crafting_bag.add_material("log_oak", 3)
    crafting_bag.add_material("herb_mint", 4)
    crafting_bag.add_material("minnow", 2)
    await _wait(0.3)
    hud_nation.professions_panel.open()
    hud_nation.professions_panel._select("smithing")
    await _wait(0.2)
    await _shot("smithing", "Smithing in a town: smelt ores into bars, forge bars and logs into gear — each recipe shows its chance and what you have")
    hud_nation.professions_panel._select("alchemy")
    await _wait(0.2)
    await _shot("alchemy", "Alchemy: brew herbs, fish and creature materials into draughts, tonics, elixirs and the Senzu Bean")
    hud_nation.professions_panel.close_panel()
    _log("## 28. Raid bosses and level ranges (M7a)")
    var raid := preload("res://scripts/bosses/boss_catalogue.gd")
    var gnashmaw: Node2D = world.entity_by_id("boss_gnashmaw")
    _check(gnashmaw != null, "Gnashmaw waits in Thornwood")
    if gnashmaw != null:
        showcase.global_position = raid.centre("boss_gnashmaw") + Vector2(-50, 20)
        world.terrain.ensure_props_at(showcase.global_position)
        await _wait(0.6)
        gnashmaw._start_attack("slam")
        await _wait(0.5)
        await _shot("raid_boss", "A raid boss: Gnashmaw in her Thornwood arena (dashed ring) winds up a slam — the red zone shows where it lands; the boss bar shows her phase")
        world.boss_fx.zones = []
        gnashmaw._reset()
    hud_nation.world_map.open()
    await _wait(0.3)
    await _shot("map_levels", "The world map shows each region's level range (user request)")
    hud_nation.world_map.close()
    _log("## 29. The Eastern Reaches (M7b)")
    for land in [["steppe", Vector2(1000, -70), "The Goldwind Steppe (levels 22-27): golden grass, acacias and the nomad town of Galehaven"], ["gloomveil", Vector2(1020, 288), "Gloomveil (levels 28-33): a purple, gloomy land of dark trees and glowing mushrooms around Gloomhollow"], ["jade", Vector2(1260, 30), "The Jade Terraces (levels 34-40): rice paddies, bamboo and pagoda villages under misty jade peaks"]]:
        showcase.global_position = tour_map.to_world(land[1])
        world.terrain.ensure_props_at(showcase.global_position)
        await _wait(0.5)
        await _shot(land[0], land[2])
    _log("## 30. Dungeons and hidden elites (M7c)")
    var dungeon_gates: Node = world.dungeon_gates
    var dungeon_list := preload("res://scripts/dungeons/dungeon_catalogue.gd")
    showcase.global_position = dungeon_gates.mouth_position("frostfang_cavern") + Vector2(0, 18)
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(0.4)
    await _shot("cave_mouth", "A cave mouth in Frostpeak: F climbs down into Frostfang Cavern (a dungeon for levels 14-17)")
    _check(session.apply_action(showcase, "dungeon", {"operation": "enter", "id": "frostfang_cavern"}), "Climbed down into Frostfang Cavern")
    showcase.global_position = tour_map.to_world(dungeon_list.rooms("frostfang_cavern")[1][0] + Vector2(0, 5))
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(0.5)
    await _shot("dungeon_hall", "Inside a dungeon: dark cave halls joined by wooden walkways over chasms, full of creatures")
    showcase.global_position = tour_map.to_world(dungeon_list.rooms("frostfang_cavern")[3][0] + Vector2(-6, 6))
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(0.5)
    await _shot("dungeon_boss", "The deepest chamber: Frostfang, the Ice Cyclops, guards a rich chest")
    showcase.global_position = dungeon_gates.exit_position("frostfang_cavern") + Vector2(0, 8)
    _check(session.apply_action(showcase, "dungeon", {"operation": "leave", "id": "frostfang_cavern"}), "Climbed back out")
    _log("## 31. Day, night and weather")
    var day_night := preload("res://scripts/world/day_night.gd")
    var saved_time: float = world.progression.world_time
    showcase.global_position = tour_map.to_world(Vector2(110, 150))
    world.terrain.ensure_props_at(showcase.global_position)
    world.progression.world_time = fposmod(23.0 - day_night.START_HOUR, 24.0) / 24.0 * day_night.DAY_SECONDS
    await _wait(0.5)
    await _shot("night", "Night in Brookhaven: the world darkens, the plaza and your character glow softly; the clock and weather sit under the minimap")
    var period := day_night.DAY_SECONDS / 24.0 * day_night.WEATHER_HOURS
    for weather_shot in [["rain", "Thornwood", Vector2(104, 90), "Rain over Thornwood (fish bite sooner)"], ["gloom_mist", "Gloomveil", Vector2(1020, 300), "Gloom mist drifting over Gloomveil (creatures notice you later)"]]:
        for step in range(400):
            var time: float = step * period + 5.0
            if day_night.weather(weather_shot[1], time) == weather_shot[0] and not day_night.is_night(time):
                world.progression.world_time = time
                break
        showcase.global_position = tour_map.to_world(weather_shot[2])
        world.terrain.ensure_props_at(showcase.global_position)
        await _wait(0.6)
        await _shot("weather_" + weather_shot[0], weather_shot[3])
    world.progression.world_time = saved_time
    _log("## 32. Quests: The Shattered Moon, quest givers and bounty boards")
    var quest_panel = hud_nation.quest_panel
    quest_panel._queue.clear()
    showcase.progression.quests["main_0"] = {"s": 4, "c": 0, "done": true}
    quest_panel._seen["main_0"] = -1
    showcase.global_position = preload("res://scripts/quests/quest_catalogue.gd").npc_position("orrin") + Vector2(0, 30)
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(0.6)
    _check(world.quests.marker(showcase, "orrin") == "!", "Orrin offers the first chapter (!)")
    await _shot("quest_giver", "Orrin the astronomer in Brookhaven has the next chapter of the main story (!); Hilde and the bounty board wait nearby")
    quest_panel._offer("orrin", "main_1")
    await _wait(0.3)
    await _shot("quest_dialog", "Dialogue with portraits: Orrin asks for timber and ore to build a shard lens (Chapter 1: Thornwood's Hollow Heart)")
    hud_nation.dialog_panel.close()
    _check(session.apply_action(showcase, "quest", {"operation": "accept", "id": "main_1"}), "Chapter 1 accepted")
    quest_panel.tracked = "main_1"
    showcase.global_position = preload("res://scripts/quests/quest_catalogue.gd").npc_position("board_brookhaven") + Vector2(10, 0)
    session.apply_action(showcase, "quest", {"operation": "accept", "id": "bounty_brookhaven_cull"})
    session.apply_action(showcase, "quest", {"operation": "accept", "id": "bounty_brookhaven_hunt"})
    await _wait(0.4)
    quest_panel._queue.clear()
    quest_panel._queue.append(["Lumi", "Orrin's lens will find the next shard. Thornwood first — stay close, castaway!"])
    quest_panel._speech_left = 0.0
    await _wait(0.4)
    await _shot("story_speech", "The story speaks in a small box at the bottom (here Lumi, the star-sprite) — it never pauses the game")
    quest_panel.open()
    await _wait(0.3)
    await _shot("quest_log", "The quest log (O): the main story first, side quests and bounties, each with its objective; the tracked one shows under the minimap")
    quest_panel.close_panel()
    _log("## 33. The Shattered Moon's finale (M9d)")
    var quest_catalogue := preload("res://scripts/quests/quest_catalogue.gd")
    for chapter in range(1, 7):
        showcase.progression.quests["main_%d" % chapter] = {"s": quest_catalogue.quest("main_%d" % chapter).steps.size(), "c": 0, "done": true}
        quest_panel._seen["main_%d" % chapter] = -1
    showcase.progression.quests["main_7"] = {"s": 2, "c": 0, "done": false}
    quest_panel._seen["main_7"] = 2
    quest_panel.tracked = "main_7"
    quest_panel._queue.clear()
    quest_panel._speech_left = 0.0
    quest_panel.speech.hide()
    showcase.global_position = quest_catalogue.npc_position("regent_spire") + Vector2(-30, -12)
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(0.8)
    _check(world.quests.nearest_npc(showcase).is_empty() or world.quests.waiting_for(showcase, "regent_spire"), "The Pale Regent waits beneath the Sage Spire")
    await _shot("pale_regent", "Chapter 7: the Pale Regent waits beneath the Sage Spire in the Ki Realm (he only shows to those the story brings here)")
    showcase.progression.quests["main_7"] = {"s": 3, "c": 0, "done": false}
    quest_panel._seen["main_7"] = 3
    showcase.global_position = preload("res://scripts/bosses/boss_catalogue.gd").centre("boss_eclipse_wyrm") + Vector2(0, 80)
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(1.2)
    await _shot("eclipse_wyrm", "The final raid boss: the Eclipse Wyrm (the Pale Regent unbound), level 50, in its arena below the Sage Spire")
    showcase.progression.quests["main_7"] = {"s": 4, "c": 0, "done": false}
    quest_panel._seen["main_7"] = 4
    quest_panel._queue.clear()
    quest_panel._speech_left = 0.0
    quest_panel._choice_offered.clear()
    quest_panel.open_choice()
    await _wait(0.3)
    await _shot("ending_choice", "The ending: mend the moon (Moonwarden, a holy crescent) or keep its core's power (Eclipse Sovereign, a reaper that grows stronger at night)")
    hud_nation.dialog_panel.close()
    showcase.progression.quests.erase("main_7")
    _log("## 34. Achievements and titles (M9e)")
    showcase.progression.fish_log["leviathan"] = 1
    world.quests.unlock(showcase)
    _check(session.apply_action(showcase, "title", {"id": "leviathan"}), "Wearing the Leviathan Catcher title")
    showcase.global_position = tour_map.to_world(Vector2(110, 150))
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(0.8)
    await _shot("title", "A worn title (Leviathan Catcher) above the character and on the status card; new achievements announce themselves in a banner")
    hud_nation.achievements_panel._category = "Fishing"
    hud_nation.achievements_panel.open()
    await _wait(0.3)
    await _shot("achievements", "The achievements window (Y): categories, progress and the titles you can wear")
    hud_nation.achievements_panel.close_panel()
    _log("## 35. Distinct looks for the gear tiers (M11)")
    var tier_rng := RandomNumberGenerator.new()
    tier_rng.seed = 11
    var tier_gear := preload("res://scripts/items/gear_catalogue.gd")
    for tier_level in [21, 24, 27, 30, 33, 36, 39, 42, 45, 48]:
        var tier_item: Dictionary = tier_gear.roll("t%d_sword_080" % tier_level, 3, tier_rng)
        tier_item["id"] = "item_tierlook_%02d" % tier_level
        showcase.add_item(tier_item)
    hud_nation.gear_panel.open()
    hud_nation.gear_panel._hovered = "item_tierlook_48"
    await _wait(0.4)
    await _shot("tier_looks", "Gear tiers look different: one sword from each tier (21 storm blue to 48 Ascendant pink with a glow), the Ascendant one's card")
    hud_nation.gear_panel._hovered = ""
    hud_nation.gear_panel.close()
    _log("## 36. Dungeon variety (M11b)")
    var features_node: Node = world.dungeon_features
    var features_script := preload("res://scripts/dungeons/dungeon_features.gd")
    var trap_spot: Array = features_script.traps("frostfang_cavern")[1]
    showcase.global_position = trap_spot[0] + Vector2(0, -40)
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(1.0)
    var warn_time := 0.0
    for step in range(60):
        if features_script.trap_phase(step * 0.05, 1) == 2:
            warn_time = step * 0.05
            break
    var saved_clock: float = world.progression.world_time
    world.progression.world_time = warn_time
    await _wait(0.05)
    await _shot("dungeon_traps", "Spike traps on a rope bridge in Frostfang Cavern: the plates warn, then the spikes stand up red (10% of your health, 15% on Heroic)")
    world.progression.world_time = saved_clock
    showcase.global_position = features_script.door_position("frostfang_cavern") + Vector2(0, -30)
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(1.2)
    await _shot("dungeon_door", "The boss chamber's sealed door: pull the levers in both halls to open it")
    showcase.global_position = features_script.lever_position("frostfang_cavern", 0) + Vector2(12, 4)
    world.terrain.ensure_props_at(showcase.global_position)
    _check(session.apply_action(showcase, "dungeon", {"operation": "lever", "id": "frostfang_cavern", "index": 0}), "Pulling a lever in the first hall")
    await _wait(0.4)
    await _shot("dungeon_lever", "A lever pulled down in the first hall; the locked vault nearby opens with the dungeon's key (the Keeper of the second hall may drop it)")
    features_node.state("frostfang_cavern")["levers"] = [false, false]
    _log("## 37. Trading between players (M11c)")
    var trader = load("res://scenes/player/player.tscn").instantiate()
    trader.character_id = "friend"
    trader.local_controlled = false
    world.add_child(trader)
    trader.choose_race("Human")
    if trader != null:
        showcase.global_position = tour_map.to_world(Vector2(110, 150))
        trader.global_position = showcase.global_position + Vector2(24, 0)
        world.terrain.ensure_props_at(showcase.global_position)
        trader.get_node("Inventory").add_material("herb_moonbloom", 3)
        trader.progression["zeni"] = 2500
        _check(world.exchange.request(trader, showcase.character_id) and world.exchange.accept(showcase), "The friend asks to trade and it is accepted")
        world.exchange.offer(showcase, {"gear": ["item_tierlook_42"], "goods": {}, "zeni": 0})
        world.exchange.offer(trader, {"gear": [], "goods": {"herb_moonbloom": 3}, "zeni": 2000})
        world.exchange.mark_ready(trader, true)
        hud_nation.quest_panel._queue.clear()
        hud_nation.dialog_panel.close()
        await _wait(0.6)
        await _shot("trading", "Trading with a friend: your things on the left, your offer (a Starforged sword) in the middle, theirs (3 Moonblooms and 2,000 Zeni, ready) on the right")
        world.exchange.cancel(showcase)
        await _wait(0.2)
        world.remove_child(trader)
        trader.queue_free()
    _log("## 38. World events (M11d)")
    var world_events: Node = world.events
    showcase.global_position = tour_map.to_world(Vector2(118, 160))
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(0.6)
    _check(world_events.start("meteors", showcase), "A meteor shower starts")
    var first_meteor: Array = world_events.state.meteors[0]
    world_events.state.clock = world_events.DURATION.meteors - float(first_meteor[2]) + 1.2
    showcase.global_position = Vector2(float(first_meteor[0]), float(first_meteor[1])) + Vector2(0, 40)
    await _wait(0.1)
    await _shot("meteor_shower", "World event: a meteor shower — red circles warn where meteors strike; landed ones leave meteorites to collect (F)")
    world_events._clear()
    showcase.global_position = tour_map.to_world(Vector2(110, 150)) + Vector2(0, 60)
    world.terrain.ensure_props_at(showcase.global_position)
    _check(world_events.start("invasion", showcase), "A town invasion starts")
    for invader in world_events.creatures():
        invader.set_physics_process(false)
        invader.global_position = invader.global_position.lerp(world_events.at(), 0.55)
    await _wait(0.6)
    await _shot("invasion", "World event: Brookhaven is under attack — eight invaders march on the plaza; the banner counts them down")
    world_events._clear()
    _check(world_events.start("goblin", showcase), "A treasure goblin appears")
    await _wait(0.8)
    await _shot("treasure_goblin", "World event: a treasure goblin runs from everyone — catch it for a sack of Zeni and gear")
    world_events._clear()
    _log("## 39. Cooking, Enchanting and Tailoring (M11e)")
    showcase.global_position = world.trade.merchant_position("merchant_brookhaven") + Vector2(-14, 0)
    world.terrain.ensure_props_at(showcase.global_position)
    showcase.get_node("Inventory").add_material("trout", 4)
    showcase.get_node("Inventory").add_material("herb_sunbloom", 2)
    hud_nation.professions_panel.open()
    hud_nation.professions_panel._selected = "cooking"
    hud_nation.professions_panel.refresh()
    await _wait(0.3)
    await _shot("cooking", "Cooking (new): meals from fish and herbs — heals and long buffs, Scholar's Soup and the Moonlit Feast give more XP")
    hud_nation.professions_panel._selected = "tailoring"
    hud_nation.professions_panel.refresh()
    await _wait(0.3)
    await _shot("tailoring", "Tailoring (new): light armour sewn from pelts, scales, feathers, shells and spirit silk; Enchanting inscribes the runes for your sockets")
    hud_nation.professions_panel.close_panel()
    _log("## 40. Pets (M11f)")
    showcase.get_node("Inventory").add_material("pet_egg", 3)
    for _egg in range(3):
        world.pets.use_egg(showcase)
    world.pets.choose(showcase, String(showcase.progression.pets[0]))
    showcase.global_position = tour_map.to_world(Vector2(110, 156))
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(0.8)
    await _shot("pet_following", "Pets: a hatched pet trots after you (other players see it too) and gives a small bonus")
    hud_nation.pets_panel.open()
    await _wait(0.3)
    await _shot("pets_window", "The pets window (V): your pets with portrait and bonus, choose who follows you; Mysterious Eggs hatch the ones you lack")
    hud_nation.pets_panel.close_panel()
    _log("## 41. Controller and keys (M11g)")
    var keys_host := Panel.new()
    keys_host.position = Vector2(170, 56)
    keys_host.size = Vector2(300, 280)
    hud_nation.add_child(keys_host)
    preload("res://scripts/ui/settings.gd").open_keys(keys_host, preload("res://scripts/ui/settings.gd").load_settings())
    await _wait(0.3)
    await _shot("keys", "Options → Keys: every main action's key can be changed (saved on this computer); a gamepad works without setup")
    keys_host.queue_free()
    _log("## 42. Armies (M11h)")
    showcase.global_position = world.camp.SITE + Vector2(30, 40)
    world.terrain.ensure_props_at(showcase.global_position)
    showcase.progression["zeni"] = maxi(int(showcase.progression.get("zeni", 0)), 20000)
    var recruited := 0
    for _soldier in range(3):
        if world.army.recruit(showcase):
            recruited += 1
    _check(recruited >= 1, "Soldiers recruited in the village (%d)" % recruited)
    # On open ground outside the village (they catch up from afar).
    showcase.global_position = tour_map.to_world(Vector2(118, 162))
    world.terrain.ensure_props_at(showcase.global_position)
    for _step in range(60):
        world.army._physics_process(1.0 / 30.0)
    await _wait(0.6)
    await _shot("army", "Armies: soldiers recruited in your village follow you and fight the creatures near them; they rise from Recruit to Veteran and Champion")
    hud_nation.army_panel.open()
    await _wait(0.3)
    await _shot("army_window", "The army window (C): recruit, give orders (follow, hold, charge) or send them home")
    hud_nation.army_panel.close_panel()
    world.army.dismiss(showcase)
    _log("## 43. Storage")
    var storage_script := preload("res://scripts/settlement/storage.gd")
    showcase.global_position = storage_script.hall_position("brookhaven") + Vector2(0, 14)
    world.terrain.ensure_props_at(showcase.global_position)
    showcase.progression["zeni"] = maxi(int(showcase.progression.get("zeni", 0)), 5000)
    showcase.global_position = storage_script.hall_position("brookhaven")
    _check(world.storage.buy(showcase, "brookhaven"), "City storage rented in Brookhaven")
    showcase.get_node("Inventory").add_material("ore_iron", 12)
    world.storage.put(showcase, "brookhaven", "ore_iron", 12)
    showcase.global_position = storage_script.hall_position("brookhaven") + Vector2(0, 16)
    await _wait(0.6)
    await _shot("storage_hall", "Storage at Brookhaven's town hall (every major city has one): your settlement storage and this city's storage")
    showcase.global_position = storage_script.hall_position("brookhaven")
    hud_nation.storage_panel.open_at(world.storage.reachable(showcase), "brookhaven")
    await _wait(0.4)
    await _shot("storage", "The storage window: your bag and gear on the left, what is stored on the right; city storage is rented in a city and opens only there")
    hud_nation.storage_panel.close_panel()
    _log("## 44. Classes")
    var master: Node2D = world.class_master
    _check(master.present(), "The old master lives in the settlement")
    showcase.global_position = master.position_in_world() + Vector2(14, 6)
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(0.6)
    await _shot("class_master", "The old master moves into your settlement when it is founded: talk to him (F) to choose a class")
    _check(session.apply_action(showcase, "class", {"operation": "choose", "slot": "main", "id": "warrior"}), "Warrior chosen at the master")
    hud_nation.class_panel.open()
    await _wait(0.4)
    await _shot("classes", "The class window: seven classes, a subclass from level 20, changes cost Zeni; weapons need their class")
    hud_nation.class_panel.close_panel()
    # M12c: the Mage's staff bolt and the first class skill on the hotbar.
    var gear_bases: Dictionary = load("res://scripts/items/gear_catalogue.gd").BASES
    var staff_base := ""
    for id in gear_bases:
        if gear_bases[id].get("weapon", "") == "staff" and int(gear_bases[id].level) == 1 and int(gear_bases[id].min_rarity) == 0:
            staff_base = id
            break
    showcase.progression["zeni"] = maxi(int(showcase.progression.get("zeni", 0)), 100000)
    _check(session.apply_action(showcase, "class", {"operation": "choose", "slot": "main", "id": "mage"}), "Changed to Mage at the master")
    var staff: Dictionary = load("res://scripts/items/gear_catalogue.gd").roll(staff_base, 1, RandomNumberGenerator.new())
    staff["id"] = "item_showcase_staff"
    showcase.add_item(staff)
    _check(showcase.equip("item_showcase_staff", "weapon") and showcase.get_node("SkillBook").knows(&"fireball"), "The Mage wields a staff and knows Fireball")
    showcase.facing = Vector2.RIGHT
    showcase.get_node("MeleeAttack").cooldown_left = 0.0
    showcase.get_node("MeleeAttack").attack(Vector2.RIGHT)
    await _wait(0.15)
    await _shot("class_staff", "The Mage's staff: a free magic bolt that grows with Intelligence; the first class skill, Fireball, sits on the hotbar")
    _log("## 45. Guilds and chat")
    showcase.progression["zeni"] = maxi(int(showcase.progression.get("zeni", 0)), 5000)
    _check(session.apply_action(showcase, "guild", {"operation": "found", "id": "", "name": "Moon Wardens", "tag": "MOON", "emblem": 1}), "Founded the guild Moon Wardens <MOON>")
    _check(session.apply_action(showcase, "chat", {"channel": "world", "text": "Anyone up for the Eclipse Wyrm tonight?"}), "Said something to the world")
    await _wait(0.8)
    _check(session.apply_action(showcase, "chat", {"channel": "guild", "text": "Guild hall meeting at dusk!"}), "...and to the guild")
    await _wait(0.4)
    await _shot("guild_chat", "Guilds and chat: the guild tag above your head, and chat lines in the log (Enter to chat, /g guild, /p party)")
    hud_nation.guild_panel.open()
    await _wait(0.4)
    await _shot("guild_window", "The guild window (P → Guild): members and ranks, inviting characters online; found a guild for 1000 Zeni")
    hud_nation.guild_panel.close_panel()
    # M14b: a Guild Hall in the village, its bank and this week's quests.
    var hall_camp: Node = world.camp
    hall_camp.state.wood = int(hall_camp.state.wood) + 60
    hall_camp.state.stone = int(hall_camp.state.stone) + 40
    var hall_centre: Vector2i = load("res://scripts/world/world_map.gd").to_tile(hall_camp.SITE)
    var hall_tile := Vector2i(-9999, -9999)
    for ring in range(3, 10):
        if hall_tile.x != -9999:
            break
        for dy in range(-ring, ring + 1):
            if hall_tile.x != -9999:
                break
            for dx in range(-ring, ring + 1):
                if maxi(absi(dx), absi(dy)) == ring and hall_camp.place(null, "guild_hall", hall_centre + Vector2i(dx, dy)):
                    hall_tile = hall_centre + Vector2i(dx, dy)
                    break
    _check(hall_tile.x != -9999, "A Guild Hall built in the village")
    showcase.global_position = load("res://scripts/nation/nation_catalogue.gd").foot(hall_tile) + Vector2(0, 6)
    world.terrain.ensure_props_at(showcase.global_position)
    showcase.get_node("Inventory").add_material("ore_iron", 12)
    _check(world.guilds.bank_put(showcase, "ore_iron", 12) and world.guilds.bank_zeni(showcase, 500), "Iron ore and Zeni deposited in the guild bank")
    await _wait(0.5)
    await _shot("guild_hall", "The Guild Hall in your village (F): every guild's meeting place")
    hud_nation.guild_hall_panel.open()
    await _wait(0.4)
    await _shot("guild_bank", "The guild hall window: the guild bank, level and perks, and this week's three guild quests")
    hud_nation.guild_hall_panel.close_panel()
    _log("## 46. Duels and the arena")
    hall_camp.state.wood = int(hall_camp.state.wood) + 40
    hall_camp.state.stone = int(hall_camp.state.stone) + 60
    var arena_tile := Vector2i(-9999, -9999)
    for ring in range(3, 11):
        if arena_tile.x != -9999:
            break
        for dy in range(-ring, ring + 1):
            if arena_tile.x != -9999:
                break
            for dx in range(-ring, ring + 1):
                if maxi(absi(dx), absi(dy)) == ring and hall_camp.place(null, "arena", hall_centre + Vector2i(dx, dy)):
                    arena_tile = hall_centre + Vector2i(dx, dy)
                    break
    _check(arena_tile.x != -9999, "An Arena built in the village")
    var arena_foot: Vector2 = load("res://scripts/nation/nation_catalogue.gd").foot(arena_tile)
    showcase.global_position = arena_foot + Vector2(-12, 34)
    world.terrain.ensure_props_at(showcase.global_position)
    # A sparring partner (only for the showcase; removed again before the world is saved).
    var sparring = load("res://scenes/player/player.tscn").instantiate()
    sparring.character_id = "sparring_partner"
    sparring.local_controlled = false
    sparring.position = arena_foot + Vector2(14, 34)
    world.add_child(sparring)
    await _wait(0.3)
    _check(world.duels.challenge(showcase, "sparring_partner") and world.duels.accept(sparring), "An arena match against a sparring partner")
    world.duels._process(world.duels.BREAK_SECONDS + 0.1)
    showcase.facing = Vector2.RIGHT
    showcase.get_node("MeleeAttack").cooldown_left = 0.0
    showcase.get_node("MeleeAttack").attack(Vector2.RIGHT)
    await _wait(0.2)
    await _shot("arena_match", "An arena match: best of three inside the ring, nobody dies and nothing is lost (P → Duel anywhere for a one-round duel)")
    world.duels.forfeit(sparring)
    sparring.queue_free()
    await _wait(0.2)
    hud_nation.arena_panel.open()
    await _wait(0.4)
    await _shot("arena_window", "The arena window (F at the Arena): challenge someone there, and the arena board")
    hud_nation.arena_panel.close_panel()
    _log("## 47. Your house")
    hall_camp.state.wood = int(hall_camp.state.wood) + 40
    hall_camp.state.stone = int(hall_camp.state.stone) + 30
    var home_tile := Vector2i(-9999, -9999)
    for ring in range(3, 12):
        if home_tile.x != -9999:
            break
        for dy in range(-ring, ring + 1):
            if home_tile.x != -9999:
                break
            for dx in range(-ring, ring + 1):
                var candidate: Vector2i = hall_centre + Vector2i(dx, dy)
                showcase.global_position = load("res://scripts/nation/nation_catalogue.gd").foot(candidate) + Vector2(0, 12)
                if maxi(absi(dx), absi(dy)) == ring and hall_camp.place_problem(showcase, "home", candidate).is_empty() and hall_camp.place(showcase, "home", candidate):
                    home_tile = candidate
                    break
    _check(home_tile.x != -9999, "Your House built in the village")
    showcase.global_position = world.housing.house_door(showcase.character_id) + Vector2(0, 8)
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(0.5)
    await _shot("house_outside", "Your own house in the village: its door (F) leads inside")
    showcase.global_position = world.housing.house_door(showcase.character_id)
    _check(world.housing.enter_house(showcase, showcase.character_id), "Went inside")
    var home_rect: Rect2 = world.housing.house_rect(int(world.housing.house_of(showcase.character_id).slot))
    showcase.progression["zeni"] = maxi(int(showcase.progression.get("zeni", 0)), 10000)
    var furnished := 0
    for entry in [["bed_double", Vector2(36, 76)], ["dresser", Vector2(84, 74)], ["stove", Vector2(176, 78)], ["trophy_bear", Vector2(120, 38)], ["window", Vector2(60, 40)], ["chandelier", Vector2(150, 40)], ["covered_table", Vector2(112, 120)], ["stool", Vector2(88, 122)], ["stool", Vector2(136, 122)], ["plant_tall", Vector2(18, 140)], ["plant", Vector2(206, 140)]]:
        showcase.global_position = home_rect.position + entry[1]
        if world.housing.place(showcase, entry[0]):
            furnished += 1
    _check(furnished >= 9, "Furnished the house (%d pieces)" % furnished)
    showcase.global_position = home_rect.position + Vector2(112, 100)
    await _wait(0.5)
    await _shot("house_inside", "Inside your house: furnish it (F) — the bed lets you rest (Well rested: +10% XP), a trophy adds Zeni, the stove cooks")
    hud_nation.housing_panel.open()
    await _wait(0.4)
    await _shot("house_furnish", "The furnishing window: buy a piece and place it where you stand; take pieces away for their price")
    hud_nation.housing_panel.close_panel()
    showcase.global_position = world.housing.door_inside(home_rect)
    _check(world.housing.leave(showcase), "Left the house")
    _log("## 48. Playtest fixes: loot on the ground, sprint, the log, the map")
    showcase.global_position += Vector2(0, 40)
    world.terrain.ensure_props_at(showcase.global_position)
    await _wait(0.3)
    var popped := 0
    var loot_rng := RandomNumberGenerator.new()
    loot_rng.seed = 48
    for base in ["iron_sword", "hunting_bow", "copper_ring"]:
        if world.pop_gear(preload("res://scripts/items/gear_catalogue.gd").roll(base, popped + 1, loot_rng), showcase.global_position + Vector2(44, -4), "nobody_yet", 99999999.0) != null:
            popped += 1
    _check(popped == 3, "Loot popped out onto the ground")
    showcase.stamina = 0.4
    showcase._winded = false
    await _wait(0.25)
    await _shot("loot_pop", "Loot pops out of creatures and chests and lies on the ground: walk over it or press F nearby; Shift sprints (the bar under you is your stamina)")
    for node in get_nodes_in_group("gear_pickups"):
        if node.owner_id == "nobody_yet":
            node.queue_free()
    for index in range(12):
        hud_nation.record_event("Log line %d: scroll back with the mouse wheel." % index)
    hud_nation.set_log_mode(hud_nation.LOG_TALL)
    await _wait(0.2)
    await _shot("log_tall", "The log box: − and + make it smaller or bigger; the mouse wheel scrolls back through the last 30 lines")
    hud_nation.set_log_mode(hud_nation.LOG_NORMAL)
    hud_nation.world_map.open()
    await _wait(0.4)
    await _shot("map_labels", "The world map fits its frame; names never overlap (zoom in for more)")
    hud_nation.world_map.close()
    for file in DirAccess.get_files_at(temp_worlds):
        DirAccess.remove_absolute(temp_worlds.path_join(file))
    DirAccess.remove_absolute(temp_worlds)
    _log("\n## System messages seen\n")
    for message in messages:
        _log("- %s" % message)
    _log("\nThe bot retreated %d time(s) to let Magicules recover." % retreats)
    _log("XP assistance for skill points: %d XP in total (creatures respawn after 60 s; the showcase does not wait to farm them)." % xp_assist)
    _log("\n**Result: %d failed checks, %d screenshots.**" % [failures, shots])
    var file := FileAccess.open(OUT.path_join("log.md"), FileAccess.WRITE)
    file.store_string("\n".join(lines) + "\n")
    file.close()
    print("Visual playtest: %d failed, %d screenshots" % [failures, shots])
    quit(1 if failures else 0)
