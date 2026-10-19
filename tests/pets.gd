extends SceneTree
## Pets (M11f): every pet has art and a bonus; eggs hatch pets you lack (never a duplicate); the
## chosen pet follows you on screen and its bonus applies (stats, XP, Zeni); eggs drop from
## creatures; the intents, the window and saves.
const PETS := preload("res://scripts/pets/pet_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
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
    # Exact XP and gathered amounts: no double early XP, no starter tools (see tests/sve_fixes.gd).
    preload("res://scripts/player/player.gd").starter_kit = false
    preload("res://scripts/player/player.gd").early_double_xp = false
    preload("res://scripts/pets/pet_followers.gd").egg_drops = true
    _check(PETS.ORDER.size() == 13 and PETS.ORDER.all(func(id): return PETS.texture(id) != null and PETS.face(id) != null and PETS.PETS[id][2].size() >= 1), "Thirteen pets (with the Chiikawa trio), each with art, a portrait and a bonus")
    var rng := RandomNumberGenerator.new()
    rng.seed = 4
    var progression := {"pets": []}
    for _i in range(PETS.ORDER.size()):
        progression.pets.append(PETS.hatch(progression, rng))
    _check(progression.pets.size() == PETS.ORDER.size() and not "" in progression.pets and PETS.hatch(progression, rng) == "", "Eggs hatch every pet once, then nothing")
    # A world.
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-pets-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24822, dir.path_join("pets.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var bag: Node = me.get_node("Inventory")
    _check(not session.apply_action(me, "pet", {"operation": "hatch"}), "No egg, nothing to hatch")
    bag.add_material(PETS.EGG, 2)
    _check(session.apply_action(me, "pet", {"operation": "hatch"}) and PETS.owned(me.progression).size() == 1 and not PETS.active(me.progression).is_empty() and bag.count_of(PETS.EGG) == 1, "An egg hatches a pet, which follows you at once")
    _check(me.use_good(PETS.EGG) and PETS.owned(me.progression).size() == 2, "Eggs can be used from the bag too")
    _check(preload("res://scripts/progression/achievements.gd").has(me, "pet_first"), "A Friend for the Road")
    await _frames(3)
    var follower: Node = world.pets._followers.get(me.character_id)
    _check(follower != null and follower.global_position.distance_to(me.global_position) < 40.0, "The pet trots beside you")
    # Bonuses.
    me.progression.pets = PETS.ORDER.duplicate()
    _check(session.apply_action(me, "pet", {"operation": "choose", "id": "dog"}) and me.gear_bonus("defense") >= 3.0, "Rufus the Dog: +3 defence")
    session.apply_action(me, "pet", {"operation": "choose", "id": "parrot"})
    var zeni: int = int(me.progression.zeni)
    me.gain_zeni(100, "test")
    _check(int(me.progression.zeni) - zeni == 110, "Captain Squawk: +10% Zeni")
    session.apply_action(me, "pet", {"operation": "choose", "id": "cat"})
    var xp: int = int(me.progression.experience)
    me.gain_experience(100, "test")
    _check(int(me.progression.experience) - xp == 105, "Whiskers: +5% XP")
    _check(not session.apply_action(me, "pet", {"operation": "choose", "id": "dragon"}) and not session.apply_action(me, "pet", {"operation": "pat"}), "Unknown pets and requests are refused")
    _check(session.apply_action(me, "pet", {"operation": "choose", "id": ""}) and PETS.active(me.progression).is_empty(), "Sending your pet home")
    await _frames(3)
    _check(not world.pets._followers.has(me.character_id), "...and it leaves")
    # Eggs from creatures.
    world.pets._rng.seed = 2
    var eggs: int = bag.count_of(PETS.EGG)
    for _i in range(10):
        world.quests.on_event(me, "boss", {"id": "boss_gnashmaw"})
    _check(bag.count_of(PETS.EGG) > eggs, "Bosses drop eggs now and then")
    eggs = bag.count_of(PETS.EGG)
    world.quests.on_event(me, "kill", {"kind": "treasure_goblin", "region": "", "id": "event_treasure_goblin_9", "difficulty": 1})
    _check(bag.count_of(PETS.EGG) == eggs + 1, "A treasure goblin always carries one")
    # The window and saves.
    var hud: CanvasLayer = world.get_node("HUD")
    hud.quest_panel._queue.clear()
    hud.dialog_panel.close()
    hud.pets_panel.open()
    await _frames(2)
    _check(hud.pets_panel.visible and hud.pets_panel._list.get_child_count() == PETS.ORDER.size(), "V opens the pets window with every pet")
    hud.pets_panel.close_panel()
    session.apply_action(me, "pet", {"operation": "choose", "id": "racoon"})
    _check(session.save_world() == OK, "Saved")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("pets.json")))
    _check(raw.players.host.progression.pet == "racoon" and raw.players.host.progression.pets.size() == PETS.ORDER.size(), "Pets are saved")
    var bad: Dictionary = raw.duplicate(true)
    bad.players.host.progression.pets = ["cat", "cat"]
    var bad_pet: Dictionary = raw.duplicate(true)
    bad_pet.players.host.progression.pets = ["cat"]
    _check(not STORE.validate(bad) and not STORE.validate(bad_pet), "Duplicate pets and a following pet you do not own are rejected")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Pet checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
