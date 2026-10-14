extends SceneTree
## Skill fusion (step 17d): recipes, fusing replaces both skills, splitting gives them back,
## activation/point accounting, hotbar, Unique prerequisites, host intent, the U window with
## drag and drop, saves, forged states and the v15→v16 migration.
const CATALOGUE := preload("res://scripts/skills/skill_catalogue.gd")
const TREE := preload("res://scripts/skills/skill_tree.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
var checks := 0
var failures := 0
var world: Node2D
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
func _ids(book: Node) -> Array:
    var ids: Array = book.known_ids()
    ids.sort()
    return ids

func _run() -> void:
    # --- Recipes
    _check(CATALOGUE.fusion_for("rending_bite", "thorn_lash") == "piercing_fang" and CATALOGUE.fusion_for("thorn_lash", "rending_bite") == "piercing_fang", "Rending Bite + Thorn Lash fuse into Piercing Fang (either order)")
    _check(CATALOGUE.fusion_for("rending_bite", "rending_bite") == "" and CATALOGUE.fusion_for("rending_bite", "acid_splash") == "" and CATALOGUE.fusion_for("predator_focus", "thorn_lash") == "", "Other pairs do not fuse")
    _check(CATALOGUE.is_fused("piercing_fang") and not CATALOGUE.is_fused("rending_bite") and CATALOGUE.components("piercing_fang") == ["rending_bite", "thorn_lash"], "Piercing Fang is a fused skill made of its two Commons")
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    world.system_message.connect(func(message: String): messages.append(message))
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var actor = world.get_local_player()
    actor.position = Vector2(100, 600)
    var book = actor.get_node("SkillBook")
    var progression: Dictionary = actor.progression
    # --- Extra skills are no longer automatic
    book.record_analysis(&"forest_gnasher")
    var gained: Array = book.record_analysis(&"thornback_gnasher")
    _check(gained.map(func(skill): return String(skill.id)) == ["thorn_lash"] and not book.knows(&"piercing_fang"), "Knowing both Commons and the Thornback analysis no longer grants Piercing Fang automatically")
    messages.clear()
    _check(not actor.fuse_skills("rending_bite", "thorn_lash") and messages.any(func(m): return m.contains("Activate both")), "Inactive skills cannot be fused")
    actor.gain_experience(preload("res://scripts/progression/leveling.gd").xp_for_level(2), "test")
    _check(actor.activate_skill("rending_bite") and actor.activate_skill("thorn_lash") and progression.skill_points == 0, "Both skills activated (2 points at level 2)")
    _check(book.skill_at_slot(0).id == &"rending_bite" and book.skill_at_slot(1).id == &"thorn_lash", "Activated skills are on the hotbar")
    # --- Fuse
    messages.clear()
    _check(not actor.fuse_skills("rending_bite", "rending_bite") and not actor.fuse_skills("rending_bite", "engulf"), "A skill cannot fuse with itself or with a skill you do not have")
    _check(actor.fuse_skills("thorn_lash", "rending_bite"), "Fusing works in either order")
    _check(_ids(book) == ["piercing_fang"] and book.is_active(&"piercing_fang") and progression.skill_points == 0 and progression.tree.active == ["rending_bite", "thorn_lash"], "Both skills are replaced by Piercing Fang, already active; no points change")
    _check(book.skill_at_slot(1).id == &"piercing_fang" and book.skill_at_slot(0) == null, "The fused skill takes the first skill's hotbar slot; the other slot is freed")
    _check(messages.any(func(m): return m.begins_with("Fusion: Thorn Lash + Rending Bite → Piercing Fang (Extra)")), "The fusion is announced")
    var pool = actor.get_node("Magicules")
    pool._current = pool.maximum
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    _check(actor.get_node("MeleeAttack").attack_skill(Vector2.RIGHT, &"piercing_fang") and not actor.get_node("MeleeAttack").attack_skill(Vector2.RIGHT, &"rending_bite"), "Piercing Fang can be used; the consumed Rending Bite cannot")
    _check(not actor.activate_skill("piercing_fang"), "A fused skill is not activated on its own")
    book.record_analysis(&"thornback_gnasher")
    book.record_analysis(&"forest_gnasher")
    _check(_ids(book) == ["piercing_fang"], "Analyzing again never gives back a part consumed by the fused skill")
    # --- Split
    _check(not actor.split_skill("rending_bite"), "Only fused skills can be split")
    _check(actor.split_skill("piercing_fang") and _ids(book) == ["rending_bite", "thorn_lash"] and book.is_active(&"rending_bite") and book.is_active(&"thorn_lash") and progression.skill_points == 0, "Splitting always gives both skills back, still active")
    _check(book.skill_at_slot(1).id == &"rending_bite" and book.skill_at_slot(0).id == &"thorn_lash", "Split skills return to the hotbar")
    _check(actor.fuse_skills("rending_bite", "thorn_lash") and book.knows(&"piercing_fang"), "They can be fused again")
    # A tree skill never fuses.
    actor.gain_experience(preload("res://scripts/progression/leveling.gd").xp_for_level(5) - int(progression.experience), "test")
    actor.buy_node("slime_vitality")
    actor.buy_node("slime_reserve")
    actor.buy_node("slime_acid_splash")
    messages.clear()
    _check(book.knows(&"acid_splash") and not actor.fuse_skills("acid_splash", "piercing_fang") and messages.any(func(m): return m.contains("do not fuse")), "Tree skills do not fuse")
    # --- Unique prerequisites follow the closure
    var trial = world.trial
    actor.position = trial.stone + Vector2(0, 20)
    pool._current = pool.maximum
    _check(trial.try_start(actor), "Holding the fused Piercing Fang qualifies for the trial")
    for creature in trial.creatures():
        creature.get_node("Health").take_damage(999)
    await _frames()
    trial._physics_process(0.016)
    _check(book.knows(&"predator_focus"), "The trial teaches Predator Focus")
    _check(actor.split_skill("piercing_fang") and book.knows(&"predator_focus"), "Splitting Piercing Fang later keeps Predator Focus")
    # --- Host intent
    var session: Node = root.get_node("GameSession")
    var rejected: int = session.rejected_requests
    _check(session.apply_action(actor, "fusion", {"operation": "fuse", "a": "rending_bite", "b": "thorn_lash"}) and book.knows(&"piercing_fang"), "The host applies a fusion intent")
    _check(session.apply_action(actor, "fusion", {"operation": "split", "id": "piercing_fang"}) and book.knows(&"rending_bite"), "The host applies a split intent")
    session.apply_action(actor, "fusion", {"operation": "fuse", "a": "rending_bite"})
    session.apply_action(actor, "fusion", {"operation": "split"})
    session.apply_action(actor, "fusion", {"operation": "merge", "id": "x"})
    _check(session.rejected_requests == rejected + 3, "Malformed fusion intents are rejected")
    session.replica_world = true
    _check(not actor.fuse_skills("rending_bite", "thorn_lash") and book.knows(&"rending_bite"), "Clients cannot fuse locally")
    session.replica_world = false
    # --- The U window with drag and drop
    var hud = world.get_node("HUD")
    var event := InputEventAction.new()
    event.action = "fusion"
    event.pressed = true
    Input.parse_input_event(event)
    await _frames(1)
    var panel = hud.fusion
    _check(panel.visible and paused, "U opens the fusion window and pauses offline play")
    var held: Array = book.known_ids()
    var visible_buttons: int = panel._list_buttons.filter(func(button): return button.visible).size()
    _check(visible_buttons == held.size(), "Your skills are listed on the right")
    _check(panel._drag_from_list(Vector2.ZERO, held.find("rending_bite")) == {"skill": "rending_bite"}, "Active skills can be dragged from the list")
    panel._drop_on_area(Vector2(80, 60), {"skill": "rending_bite"})
    _check(panel.tiles.size() == 1 and panel.tiles[0].id == "rending_bite", "Dropping a skill in the fusion area places it there")
    panel._drop_on_tile(Vector2.ZERO, {"skill": "acid_splash"}, 0)
    _check(book.knows(&"rending_bite") and panel._detail.text.contains("do not fuse"), "Dropping a non-matching skill on it explains that they do not fuse")
    panel._drop_on_tile(Vector2.ZERO, {"skill": "thorn_lash"}, 0)
    await _frames(1)
    _check(book.knows(&"piercing_fang") and not book.knows(&"rending_bite") and panel.tiles.size() == 1 and panel.tiles[0].id == "piercing_fang" and panel.tiles[0].split.visible, "Dropping Thorn Lash onto Rending Bite fuses them; the area shows Piercing Fang with a Split button")
    panel.tiles[0].split.pressed.emit()
    await _frames(1)
    var tile_ids: Array = panel.tiles.map(func(tile): return tile.id)
    tile_ids.sort()
    _check(book.knows(&"rending_bite") and book.knows(&"thorn_lash") and tile_ids == ["rending_bite", "thorn_lash"], "Split turns the tile back into both skills")
    panel.close()
    await _frames(1)
    _check(not panel.visible and not paused, "Closing resumes")
    # --- Saves
    actor.fuse_skills("rending_bite", "thorn_lash")
    var dir := OS.get_temp_dir().path_join("tempestrpg-fusion-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var path := dir.path_join("fusion.json")
    _check(session.start_host(24660, path, false, {"name": "Fusion", "seed": 0, "created": 1, "last_played": 1}) == OK and session.save_world() == OK, "World with a fused skill saves")
    var saved: Dictionary = STORE.load_world(path)
    var held_saved: Array = saved.data.players.host.skill_ids.duplicate()
    held_saved.sort()
    _check(saved.ok and saved.data.version == STORE.VERSION and held_saved == ["piercing_fang", "predator_focus"], "The save holds the fused skill, not its consumed parts")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24660, path, false) == OK and world.get_local_player().get_node("SkillBook").is_active(&"piercing_fang") and world.get_local_player().split_skill("piercing_fang") and world.get_local_player().get_node("SkillBook").knows(&"thorn_lash"), "After reload the fused skill is active and can still be split")
    session.stop_session(false)
    var data: Dictionary = saved.data
    var forged := []
    var doc: Dictionary
    doc = data.duplicate(true); doc.players.host.skill_ids.append("rending_bite"); forged.append(doc)
    doc = data.duplicate(true); doc.players.host.skill_evidence.analyzed.erase("thornback_gnasher"); forged.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.tree.active.append("piercing_fang"); doc.players.host.progression.skill_points -= 1; forged.append(doc)
    doc = data.duplicate(true); doc.players.host.progression.tree.active.erase("thorn_lash"); doc.players.host.progression.skill_points += 1; forged.append(doc)
    var rejected_all := true
    for index in range(forged.size()):
        if STORE.validate(forged[index]):
            rejected_all = false
            push_error("Forged fusion case %d was accepted" % index)
    _check(rejected_all, "Rejected: fused skill held with a part, fused without its analysis, activating the fused skill itself, slotted fused skill whose part is inactive")
    var legacy: Dictionary = data.duplicate(true)
    legacy.version = 15
    legacy.players.host.skill_ids = ["rending_bite", "thorn_lash", "piercing_fang", "predator_focus"]
    legacy.players.host.slots = ["rending_bite", "thorn_lash", "piercing_fang", "predator_focus"]
    var tree: Dictionary = legacy.players.host.progression.tree
    tree.nodes = []
    tree.active = ["rending_bite", "thorn_lash", "piercing_fang", "predator_focus"]
    tree.free = []
    legacy.players.host.progression.skill_points = legacy.players.host.progression.level - TREE.spent(tree)
    var migrated: Variant = STORE.migrate(legacy)
    _check(migrated is Dictionary and migrated.version == STORE.VERSION and STORE.validate(migrated), "v15 characters with an Extra migrate to a valid v16 save")
    if migrated is Dictionary:
        var ids: Array = migrated.players.host.skill_ids.duplicate()
        ids.sort()
        _check(ids == ["piercing_fang", "predator_focus"] and migrated.players.host.slots == ["", "", "piercing_fang", "predator_focus"] and migrated.players.host.progression.skill_points == legacy.players.host.progression.skill_points + 1, "Migration keeps the Extra as fused, frees its parts' slots and refunds the Extra's own activation point")
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Fusion checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
