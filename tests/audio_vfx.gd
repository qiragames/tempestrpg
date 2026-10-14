extends SceneTree
## Audio and effects (step 23): buses and local settings, region/trial music, one cue per observed
## change (hits, defeats, attacks, level-ups, pickups, chests, evolution, buildings), nothing
## repeated by identical snapshots, other characters' attack frames from the replicated recovery
## timer, reduced effects, and every referenced sound file present.
const EFFECTS := preload("res://scripts/visual/effects.gd")
const SETTINGS := preload("res://scripts/ui/settings.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const PRESENTATION := preload("res://scripts/audio/presentation.gd")
var checks := 0
var failures := 0
var audio: Node
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
func _played(id: String) -> int:
    return int(audio.played.get(id, 0))
func _spawned(id: String) -> int:
    return int(EFFECTS.spawned.get(id, 0))

func _run() -> void:
    audio = root.get_node("Audio")
    # --- Files and buses
    var missing: Array = []
    for id in ["swing", "bow", "hit", "hurt", "defeat", "magicules", "item", "analysis", "learned", "form", "shrine", "gather", "exhausted", "level_up", "chest", "evolve", "build", "game_over", "ui_move", "ui_accept", "ui_cancel"]:
        if not ResourceLoader.exists(audio.SFX_DIR + id + ".wav"):
            missing.append(id)
    for id in PRESENTATION.REGION_MUSIC.values() + ["title", "trial"]:
        if not ResourceLoader.exists(audio.MUSIC_DIR + id + ".ogg"):
            missing.append(id)
    _check(missing.is_empty(), "Every sound and music track exists: %s" % [missing])
    _check(AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0 and AudioServer.get_bus_index("UI") > 0 and audio.silent, "Music, SFX and UI buses exist; headless runs record cues silently")
    audio.apply_settings({"music": 0.5, "sfx": 0.0, "muted": true})
    _check(is_equal_approx(audio.bus_volume("Music"), 0.5) and audio.bus_volume("SFX") == 0.0 and AudioServer.is_bus_mute(0), "Volume sliders and mute act on the buses")
    audio.apply_settings(SETTINGS.DEFAULTS)
    _check(not AudioServer.is_bus_mute(0) and is_equal_approx(audio.bus_volume("SFX"), 0.8), "Default volumes restored")
    # --- World
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    world.get_node("GoblinAlly").set_physics_process(false)
    var actor = world.get_local_player()
    actor.position = Vector2(480, 340)
    await _frames(2)
    _check(audio.current_music == "clearing", "The clearing plays its own music")
    actor.position = MAP.to_world(Vector2(104, 98))
    await _frames(2)
    _check(audio.current_music == "thornwood", "Walking into Thornwood switches the music")
    actor.position = Vector2(480, 340)
    await _frames(2)
    # Hit and defeat: one cue per change.
    var gnasher = world.entity_by_id("gnasher_1")
    var hits := _played("hit")
    var sparks := _spawned("hit_spark")
    gnasher.get_node("Health").take_damage(5)
    await _frames(3)
    _check(_played("hit") == hits + 1 and _spawned("hit_spark") == sparks + 1, "A hit plays one sound and one spark")
    await _frames(5)
    _check(_played("hit") == hits + 1, "Nothing repeats while the state stays the same")
    var snapshot: Dictionary = CODEC.capture_entities(world)
    CODEC.apply_entities(world, snapshot, false)
    await _frames(2)
    CODEC.apply_entities(world, snapshot, false)
    await _frames(2)
    _check(_played("hit") == hits + 1 and _played("defeat") == 0, "Re-applying identical snapshots plays nothing again")
    gnasher.get_node("Health").take_damage(999)
    await _frames(3)
    _check(_played("defeat") == 1 and _spawned("smoke") >= 1, "A defeat plays its sound and a smoke puff")
    # Own attack.
    var swings := _played("swing")
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    actor.get_node("MeleeAttack").attack(Vector2.RIGHT)
    await _frames(2)
    _check(_played("swing") == swings + 1 and _spawned("slash") >= 1, "Your strike swooshes with a slash arc")
    # Another character's attack, seen only through the replicated recovery timer.
    var friend = load("res://scenes/player/player.tscn").instantiate()
    friend.character_id = "friend"
    friend.local_controlled = false
    friend.position = Vector2(440, 340)
    world.add_child(friend)
    friend.configure_replica()
    friend.choose_race("Human")
    await _frames(3)
    _check(_played("swing") == swings + 1, "A newly seen character makes no sound (baseline only)")
    # The minimal mix spaces repeats of one sound; let the gap after our own swing pass.
    audio._last_played.clear()
    friend.get_node("MeleeAttack").cooldown_left = 0.5
    await process_frame
    await process_frame
    _check(friend.get_node("MeleeAttack").flash_left > 0.0 and friend.body_sprite.animation.begins_with("attack_") and _played("swing") == swings + 2, "Other characters' attacks show their attack frame and sound (from the replicated recovery timer)")
    await _frames(12)
    _check(friend.get_node("MeleeAttack").flash_left == 0.0 and not friend.body_sprite.animation.begins_with("attack_") and friend.get_node("MeleeAttack").cooldown_left == 0.5 and _played("swing") == swings + 2, "A replica's attack pose expires without ticking recovery or replaying the cue")
    # Level, chest, form, pickups, evolution, building.
    var levels := _played("level_up")
    actor.progression["level"] = int(actor.progression.get("level", 1)) + 1
    await _frames(2)
    _check(_played("level_up") == levels + 1 and _spawned("boost") >= 1, "A level-up plays the jingle with a glow")
    actor.progression["chests"] = actor.progression.get("chests", []) + ["chest_1"]
    await _frames(2)
    _check(_played("chest") == 1, "Opening a chest plays its jingle")
    var pickup = load("res://scenes/pickups/magicule_pickup.tscn").instantiate()
    pickup.entity_id = "drop_test"
    pickup.amount = 5.0
    pickup.position = actor.position + Vector2(10, 0)
    pickup.set_physics_process(false)
    world.add_child(pickup)
    await _frames(2)
    if is_instance_valid(pickup):
        pickup.queue_free()
    await _frames(2)
    _check(_played("magicules") == 1, "Collecting Magicules nearby chimes")
    var far = load("res://scenes/pickups/magicule_pickup.tscn").instantiate()
    far.entity_id = "drop_far"
    far.position = MAP.to_world(Vector2(300, 85))
    far.set_physics_process(false)
    world.add_child(far)
    await _frames(2)
    if is_instance_valid(far):
        far.queue_free()
    await _frames(2)
    _check(_played("magicules") == 1, "A pickup removed far from everyone is silent")
    var ally = world.get_node("GoblinAlly")
    ally.race = "Hobgoblin"
    await _frames(2)
    _check(_played("evolve") == 1, "Evolution plays its jingle")
    var state: Dictionary = world.camp.state.duplicate(true)
    state.founded = true
    state.founder = actor.character_id
    state.hut = true
    world.camp.restore(state)
    await _frames(2)
    _check(_played("build") >= 1 and _spawned("ring") >= 1, "Founding and building play their cue (once for things finished together)")
    # Trial music.
    # (Checked in place: a trial without creatures ends on its next frame.)
    world.trial.state.active = true
    world.get_node("Presentation")._music(actor)
    _check(audio.current_music == "trial", "A running trial switches to fight music")
    world.trial.state.active = false
    # Reduced effects.
    SETTINGS.apply({"reduced": true})
    var sparkles := _spawned("sparkle")
    var flashes := _spawned("hit_spark")
    EFFECTS.spawn(world, "sparkle", actor.position)
    EFFECTS.spawn(world, "hit_spark", actor.position)
    _check(_spawned("sparkle") == sparkles and _spawned("hit_spark") == flashes + 1, "Reduced effects keep only the essential hit flashes and arcs")
    SETTINGS.apply({"reduced": false})
    # The longest effect (boost, 8 frames at 14 fps) lasts about 0.6 s.
    await _frames(60)
    var leftovers := 0
    for node in world.get_children():
        if node is AnimatedSprite2D and node.has_meta("effect"):
            leftovers += 1
    _check(leftovers == 0, "One-shot effects clean themselves up")
    world.queue_free()
    await _frames()
    # --- Minimal mix (user feedback): quiet, short, spaced sounds
    var loud := false
    for id in audio.PROFILES:
        loud = loud or audio.PROFILES[id][0] > -8.0 or audio.PROFILES[id][1] > 1.5
    _check(not loud and audio.MUSIC_DB <= -8.0 and audio.HEARING <= 400.0, "Every sound is quiet (at most -8 dB) and short (at most 1.5 s); music sits under the effects")
    audio._last_played.clear()
    var pickups := _played("magicules")
    audio.play("magicules", Vector2(10, 10))
    audio.play("magicules", Vector2(900, 900))
    _check(_played("magicules") == pickups + 1, "The same sound is not repeated within its gap, even from elsewhere")
    print("Audio and effects checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
