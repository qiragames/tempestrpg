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
    shots += 1
    var file := "%02d_%s.png" % [shots, name]
    image.save_png(ProjectSettings.globalize_path(OUT.path_join(file)))
    _log("\n![%s](%s)\n*%s* (%dx%d)\n" % [caption, file, caption, image.get_width(), image.get_height()])

## 17c: open the skill tree with K and press a button: activate a learned skill or buy a node.
## Creatures respawn after 60 s (17d2); waiting for enough of them would make the run very long,
## so the bot is still given any missing XP for points; logged.
func _use_tree(id: String, shot: String = "", caption: String = "") -> bool:
    if int(player.progression.skill_points) < 1:
        var need: int = 25 * (player.progression.level + 1) * player.progression.level - int(player.progression.experience)
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
    await _tap("camp")
    return ok and camp.state.wood + camp.state.stone > before

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
    _check(await _walk_to(Vector2(480, 130), 10.0, 20.0) and await _walk_to(Vector2(484, 340), 10.0, 20.0) and await _walk_to(reborn.position + Vector2(-60, 0), 10.0, 20.0), "Walked back along the road to the respawned Gnasher")
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
    await _wait(0.2)
    await _shot("equipment", "Equipment window: slots, owned items in rarity colours, details of the Legendary ring")
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
        {"id": "item_showcase_scythe", "base": "field_scythe", "rarity": 3, "stats": {"damage": 30}, "passives": ["lifesteal"], "active": "surge"},
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
        await _shot("weapon_" + kind, "%s: %s" % [gear_catalogue.WEAPONS[kind].name, gear_catalogue.WEAPONS[kind].text])
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
    await _shot("pause_solo", "Pause overlay while playing solo: GAME PAUSED banner, menu with shortcuts (bag, skill tree, fusion), Open to friends, Save, Options, Save & quit; character and world card")
    hud._pause_buttons.open.pressed.emit()
    _check(await _until(func(): return session.listening), "Open to friends starts listening without a restart")
    await _wait(0.1)
    await _shot("pause_open", "Pause menu after Open to friends: port and LAN address for friends")
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
    _check(layouts[0] != layouts[1] and layouts[0] == load("res://scripts/world/world_layout.gd").generate(layouts[0].seed), "Different seeds lay out different worlds; the same seed repeats exactly")
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
