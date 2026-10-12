extends RefCounted
## Validate before applying; temp + rename replaces the primary atomically.

const VERSION := 1
const MAX_BYTES := 4 * 1024 * 1024
const CODEC := preload("res://scripts/persistence/state_codec.gd")

static func _number(value: Variant, low: float, high: float, whole: bool = false) -> bool:
    if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
        return false
    return is_finite(float(value)) and value >= low and value <= high and (not whole or value == floor(value))

static func _position(value: Variant) -> bool:
    return value is Array and value.size() == 2 and _number(value[0], 0, 960) and _number(value[1], 0, 640)

static func _id(value: Variant, empty: bool = false) -> bool:
    if not value is String or value.length() > 64 or (value.is_empty() and not empty):
        return false
    for character in value:
        if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":
            return false
    return true

static func _plain(value: Variant, depth: int = 0) -> bool:
    if depth > 8:
        return false
    if value is Dictionary:
        if value.size() > 256:
            return false
        for key in value:
            if not key is String or key.length() > 128 or not _plain(value[key], depth + 1):
                return false
        return true
    if value is Array:
        if value.size() > 1024:
            return false
        for item in value:
            if not _plain(item, depth + 1):
                return false
        return true
    if value is String:
        return value.length() <= 512
    return value == null or value is bool or _number(value, -1000000000, 1000000000)

static func validate_player(state: Variant, id: String) -> bool:
    if not state is Dictionary or state.get("id") != id or not _id(id):
        return false
    if not _position(state.get("position")) or not _number(state.get("move_speed"), 1, 1000):
        return false
    var facing = state.get("facing")
    if not facing is Array or facing.size() != 2 or not _number(facing[0], -1, 1) or not _number(facing[1], -1, 1):
        return false
    var health = state.get("health")
    var pool = state.get("magicules")
    if not health is Dictionary or not pool is Dictionary:
        return false
    if not _number(health.get("maximum"), 1, 1000000, true) or not _number(health.get("current"), 0, health.maximum, true) or not _number(health.get("immunity"), 0, 60) or not _number(health.get("immunity_seconds"), 0, 60):
        return false
    if not _number(pool.get("maximum"), 1, 1000000) or not _number(pool.get("current"), 0, pool.maximum) or not _number(pool.get("regen"), 0, 1000) or not _number(pool.get("regen_delay"), 0, 60) or not _number(pool.get("delay"), 0, 60) or not pool.get("enabled") is bool:
        return false
    var known = state.get("skill_ids")
    var slots = state.get("slots")
    if not known is Array or known.size() > CODEC.SKILLS.size() or not slots is Array or slots.size() != 3:
        return false
    var seen: Dictionary = {}
    for skill in known:
        if not skill is String or not CODEC.SKILLS.has(skill) or seen.has(skill):
            return false
        seen[skill] = true
    for slot in slots:
        if not slot is String or (slot != "" and not seen.has(slot)):
            return false
    var bag = state.get("inventory")
    if not bag is Dictionary or not _number(bag.get("capacity"), 1, 10000, true) or not bag.get("counts") is Dictionary:
        return false
    var total: int = 0
    for item in bag.counts:
        if item != "gnasher_essence" or not _number(bag.counts[item], 1, bag.capacity, true):
            return false
        total += int(bag.counts[item])
    if total > bag.capacity or not _number(state.get("attack_recovery"), 0, 60):
        return false
    var analysis = state.get("analysis")
    if not analysis is Dictionary or not _id(analysis.get("target"), true) or not _number(analysis.get("remaining"), 0, 60):
        return false
    var progression = state.get("progression")
    if not progression is Dictionary or not _plain(progression) or not _number(progression.get("level"), 1, 1000, true) or not _number(progression.get("experience"), 0, 1000000000, true):
        return false
    if not progression.get("quests") is Dictionary or not progression.get("equipment") is Dictionary:
        return false
    return true

static func validate(data: Variant) -> bool:
    if not data is Dictionary or data.get("version") != VERSION or not _id(data.get("world_id")):
        return false
    if not data.get("players") is Dictionary or not data.players.has("host") or data.players.size() > 256:
        return false
    for id in data.players:
        if not validate_player(data.players[id], id):
            return false
        var hash_value = data.players[id].get("token_hash", "")
        if not hash_value is String or (id != "host" and (hash_value.length() != 64 or not hash_value.is_valid_hex_number(false))):
            return false
    if not data.get("progression") is Dictionary or not _plain(data.progression):
        return false
    if not data.get("enemies") is Array or data.enemies.size() > 1024 or not data.get("pickups") is Array or data.pickups.size() > 1024:
        return false
    var ids: Dictionary = {}
    for enemy in data.enemies:
        if not enemy is Dictionary or not _id(enemy.get("id")) or ids.has(enemy.id) or enemy.get("kind") != "gnasher" or not _position(enemy.get("position")) or not _position(enemy.get("home")):
            return false
        ids[enemy.id] = true
        if not _number(enemy.get("difficulty"), 0, 2, true) or not _number(enemy.get("maximum_hp"), 1, 1000000, true) or not _number(enemy.get("hp"), 0, enemy.maximum_hp, true) or not _number(enemy.get("immunity"), 0, 60) or not _number(enemy.get("state"), 0, 4, true) or not _number(enemy.get("state_time"), 0, 60) or not _id(enemy.get("target"), true):
            return false
        if (enemy.hp == 0) != (enemy.state == 4):
            return false
    for pickup in data.pickups:
        if not pickup is Dictionary or not _id(pickup.get("id")) or ids.has(pickup.id) or not _position(pickup.get("position")) or not _number(pickup.get("amount"), 0.000001, 1000000):
            return false
        ids[pickup.id] = true
    return true

static func migrate(data: Variant) -> Variant:
    if not data is Dictionary:
        return null
    # The first draft schema lacked progression dictionaries and loadout state.
    if data.get("version") == 0:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = VERSION
        data["progression"] = data.get("progression", {"quests": {}, "settlements": {}, "world_time": 0.0})
        for state in data.get("players", {}).values():
            if not state is Dictionary or not state.get("skill_ids", []) is Array:
                return null
            state["progression"] = state.get("progression", {"level": 1, "experience": 0, "race": "Slime", "quests": {}, "equipment": {}})
            state["slots"] = state.get("slots", [state.get("skill_ids", [])[0] if not state.get("skill_ids", []).is_empty() else "", "", ""])
    return data

static func _read(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null or file.get_length() > MAX_BYTES:
        return {}
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK:
        return {}
    var data: Variant = migrate(parser.data)
    return data if validate(data) else {}

static func load_world(path: String) -> Dictionary:
    var primary := _read(path)
    if not primary.is_empty():
        return {"ok": true, "data": primary, "recovered": false}
    var backup := _read(path + ".bak")
    if not backup.is_empty():
        return {"ok": true, "data": backup, "recovered": true}
    return {"ok": false, "data": {}, "recovered": false}

static func write_world(path: String, data: Dictionary) -> Error:
    if not validate(data):
        return ERR_INVALID_DATA
    var absolute := ProjectSettings.globalize_path(path)
    var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
    if error != OK:
        return error
    var temporary := absolute + ".tmp"
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(data))
    file.flush()
    error = file.get_error()
    file.close()
    if error != OK:
        return error
    if FileAccess.file_exists(absolute):
        # Preserve a valid previous save; never replace a good backup with corrupt data.
        if not _read(absolute).is_empty():
            error = DirAccess.copy_absolute(absolute, absolute + ".bak.tmp")
            if error == OK:
                error = DirAccess.rename_absolute(absolute + ".bak.tmp", absolute + ".bak")
            if error != OK:
                return error
        elif _read(absolute + ".bak").is_empty():
            return ERR_FILE_CORRUPT
    return DirAccess.rename_absolute(temporary, absolute)
