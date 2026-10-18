extends SceneTree
## Duels and the arena (M15): challenging (reach, answering), the start (full HP, a short break),
## only the two fighters hurt each other (strikes really land; outsiders' do not), the finishing
## blow wins the round instead of killing, leaving the ring gives the match away, a round that runs
## out goes to whoever has more HP left, arena matches are best of three, records are saved and
## checked, running matches are not saved.
const DUELS := preload("res://scripts/pvp/world_duels.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
var world: Node2D
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

func _friend(id: String, at: Vector2) -> CharacterBody2D:
    var other = load("res://scenes/player/player.tscn").instantiate()
    other.character_id = id
    other.local_controlled = false
    other.position = at
    world.add_child(other)
    return other

func _run() -> void:
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-duels-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24834, dir.path_join("duels.json"), false) == OK, "Solo world hosted")
    await _frames(10)
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var me = world.get_local_player()
    var start := Vector2(300, 600)
    me.global_position = start
    var ann := _friend("ann", start + Vector2(400, 0))
    var bo := _friend("bo", start + Vector2(0, 30))
    await _frames(2)
    var duels: Node = world.duels
    # Challenging.
    _check(not session.apply_action(me, "duel", {"operation": "challenge", "id": "ann"}), "Too far away to challenge")
    ann.global_position = start + Vector2(16, 0)
    me.facing = Vector2.RIGHT
    _check(session.apply_action(me, "duel", {"operation": "challenge", "id": "ann"}) and duels.state.challenges.has("ann"), "Challenging Ann")
    ann.get_node("Health").current = 10
    _check(session.apply_action(ann, "duel", {"operation": "accept"}) and duels.in_match("ann") and duels.opponent("host") == "ann", "Ann accepts: the duel begins")
    _check(ann.get_node("Health").current == ann.get_node("Health").maximum, "Fighters start at full HP")
    _check(not duels.can_hit(me, ann), "...after a short break")
    duels._process(DUELS.BREAK_SECONDS + 0.1)
    _check(duels.can_hit(me, ann) and duels.can_hit(ann, me) and not duels.can_hit(bo, me) and not duels.can_hit(me, bo), "Only the two fighters can hurt each other")
    # A real strike lands on the opponent.
    await _frames(2)
    var before: int = ann.get_node("Health").current
    me.get_node("MeleeAttack").cooldown_left = 0.0
    me.get_node("Magicules")._current = me.get_node("Magicules").maximum
    me.get_node("MeleeAttack").attack(Vector2.RIGHT)
    await _frames(1)
    _check(ann.get_node("Health").current < before, "A strike hits the opponent (%d → %d)" % [before, ann.get_node("Health").current])
    bo.get_node("Health").current = bo.get_node("Health").maximum
    var bo_before: int = bo.get_node("Health").current
    me.get_node("Health").immunity_left = 0.0
    var my_before: int = me.get_node("Health").current
    _check(not me.get_node("Health").take_damage(5, bo) or me.get_node("Health").current == my_before - maxi(1, 5 - me.get_node("Health").armor), "(players outside the duel never strike at all)")
    _check(bo.get_node("Health").current == bo_before, "Outsiders are not hit")
    # The finishing blow wins.
    ann.get_node("Health").immunity_left = 0.0
    ann.get_node("Health").take_damage(100000, me)
    _check(not duels.in_match("host") and ann.get_node("Health").current == ann.get_node("Health").maximum and ann.get_node("Health").current > 0, "The finishing blow wins the duel — nobody dies, both are healed")
    _check(DUELS.record(me.progression, "duels") == [1, 0] and DUELS.record(ann.progression, "duels") == [0, 1], "Duel records: you 1-0, Ann 0-1")
    # Leaving the ring.
    me.global_position = start
    ann.global_position = start + Vector2(16, 0)
    duels.challenge(me, "ann")
    duels.accept(ann)
    ann.global_position = start + Vector2(DUELS.RING + 60, 0)
    duels._process(0.016)
    _check(not duels.in_match("ann") and DUELS.record(me.progression, "duels")[0] == 2, "Leaving the ring gives the duel away")
    # A round that runs out.
    ann.global_position = start + Vector2(16, 0)
    duels.challenge(ann, "host")
    duels.accept(me)
    duels._process(DUELS.BREAK_SECONDS + 0.1)
    ann.get_node("Health").current = 5
    var id: String = duels.match_of("host")
    duels.state.matches[id].until = 0.0
    duels._process(0.016)
    _check(not duels.in_match("host") and DUELS.record(me.progression, "duels")[0] == 3, "Time: more HP left wins the round")
    # The arena: best of three.
    var camp: Node = world.camp
    var camp_before: Dictionary = camp.state.duplicate(true)
    camp.state.founded = true
    camp.state.founder = "host"
    camp.state.nation.tier = 1
    _check(NATION.BUILDINGS.has("arena") and camp.place_problem(null, "arena", Vector2i(30, 30)) != "Unknown building.", "The Arena is a nation building")
    camp.state.nation.buildings.append({"id": "b_arena_1", "kind": "arena", "tile": [24, 24]})
    var foot: Vector2 = NATION.foot(Vector2i(24, 24))
    me.global_position = foot + Vector2(-10, 30)
    ann.global_position = foot + Vector2(10, 30)
    _check(duels.challenge(me, "ann") and duels.state.challenges.ann.arena and duels.accept(ann) and duels.state.matches[duels.match_of("ann")].arena, "At the arena it is an arena match")
    duels._process(DUELS.BREAK_SECONDS + 0.1)
    ann.get_node("Health").immunity_left = 0.0
    ann.get_node("Health").take_damage(100000, me)
    _check(duels.in_match("ann") and duels.state.matches[duels.match_of("ann")].wins == [1, 0], "One round is not enough: 1-0")
    duels._process(DUELS.BREAK_SECONDS + 0.1)
    me.get_node("Health").immunity_left = 0.0
    me.get_node("Health").take_damage(100000, ann)
    duels._process(DUELS.BREAK_SECONDS + 0.1)
    ann.get_node("Health").immunity_left = 0.0
    ann.get_node("Health").take_damage(100000, me)
    _check(not duels.in_match("ann") and DUELS.record(me.progression, "arena") == [1, 0] and DUELS.record(ann.progression, "arena") == [0, 1], "Best of three: you win 2-1 — the arena record")
    # The window.
    var hud: CanvasLayer = world.get_node("HUD")
    hud.quest_panel._queue.clear()
    hud.dialog_panel.close()
    hud.arena_panel.open()
    await _frames(3)
    _check(hud.arena_panel.visible and hud.arena_panel.board().size() >= 2 and hud.arena_panel.board()[0][0] == "host", "The arena window shows the board (you lead)")
    hud.arena_panel.close_panel()
    # Saves.
    duels.challenge(me, "ann")
    duels.accept(ann)
    camp.state = camp_before
    _check(session.save_world() == OK, "Saved during a running match")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("duels.json")))
    _check(not raw.has("duels") and int(raw.players.host.progression.pvp.arena[0]) == 1 and int(raw.players.host.progression.pvp.arena[1]) == 0 and STORE.validate(raw), "Records are saved; running matches are not")
    var bad: Dictionary = raw.duplicate(true)
    bad.players.host.progression.pvp.arena = [-1, 0]
    _check(not STORE.validate(bad), "A broken record is rejected")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Duel checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
