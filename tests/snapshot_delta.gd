extends SceneTree
## Delta snapshots (found during M6b): a guest gets each part only when it changed and each
## creature only when its own entry changed; it rebuilds the whole snapshot from what it kept, and
## asks for a full resync when a base is missing.
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

## Same parts with the same contents (key order does not matter).
func _same(a: Dictionary, b: Dictionary) -> bool:
    if a.size() != b.size():
        return false
    for key in a:
        if not b.has(key) or var_to_bytes(a[key]) != var_to_bytes(b[key]):
            return false
    return true

func _send(session: Node, peer: int, data: Dictionary) -> Dictionary:
    var hashes := {}
    for key in data:
        if key != "enemies" and not key in session.ALWAYS_SENT:
            hashes[key] = hash(data[key])
    var enemy_hashes: Array = data.enemies.map(func(entry): return hash(entry))
    return session._delta_for(peer, data, hashes, enemy_hashes)

func _run() -> void:
    var session: Node = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-delta-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24796, dir.path_join("delta.json"), false) == OK, "Solo world hosted")
    await _frames()
    var data: Dictionary = session.document()
    var first := _send(session, 7, data)
    _check(not first.delta and first.omitted.is_empty() and first.enemies_changed.size() == data.enemies.size(), "A new guest gets everything")
    var rebuilt: Dictionary = session._expand_snapshot(first)
    _check(_same(rebuilt, data), "The first snapshot rebuilds the whole document")
    var second := _send(session, 7, data)
    var full_size := var_to_bytes(data).size()
    var delta_size := var_to_bytes(second).size()
    print("Snapshot: %d bytes full, %d bytes on a quiet tick" % [full_size, delta_size])
    _check(second.delta and second.enemies_changed.is_empty() and "trade" in second.omitted, "Unchanged parts and creatures are left out")
    _check(delta_size * 4 < full_size, "A quiet tick is far smaller (%d of %d bytes)" % [delta_size, full_size])
    _check(_same(session._expand_snapshot(second), data), "The guest rebuilds the same document from what it kept")
    # One creature moves, one is gone.
    var moved: Dictionary = data.duplicate(true)
    moved.enemies[0].position = [moved.enemies[0].position[0] + 5.0, moved.enemies[0].position[1]]
    var gone: String = moved.enemies[-1].id
    moved.enemies.pop_back()
    var third := _send(session, 7, moved)
    _check(third.enemies_changed.size() == 1 and third.enemies_changed[0].id == moved.enemies[0].id, "Only the creature that moved is sent")
    var after: Dictionary = session._expand_snapshot(third)
    _check(_same(after, moved) and not session._snapshot_enemies.has(gone), "Moves and removals arrive; the guest forgets removed creatures")
    # A guest without a base asks for a resync; the host then sends everything again.
    session._snapshot_parts = {}
    session._snapshot_enemies = {}
    _check(session._expand_snapshot(_send(session, 7, moved)).is_empty(), "A delta without its base cannot be rebuilt")
    session._peer_parts.erase(7)
    var again := _send(session, 7, moved)
    _check(not again.delta and _same(session._expand_snapshot(again), moved), "After a resync the guest gets everything again")
    # Another guest has its own record.
    _check(not _send(session, 8, moved).delta, "Each guest has its own record")
    world.queue_free()
    await _frames()
    session.stop_session(false)
    _check(session._peer_parts.is_empty() and session._snapshot_parts.is_empty(), "Stopping the session forgets every record")
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Snapshot delta checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
