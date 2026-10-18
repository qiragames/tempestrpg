extends RefCounted
## Your own character in a friend's world (M10, user decision): when the world's owner allows it,
## a joining friend brings the character of one of their own worlds — level, skills, gear, bag,
## Zeni, professions, fish log, achievements and titles, quests — instead of starting a new one.
## It stays one character: the host sends its current state back with every autosave (and when
## the friend leaves) and the friend's game writes it into their own world. What belongs to a
## world stays with that world: position, the map's discoveries (leveling spots, hidden elites),
## opened chests, a ferry pass (it counts that world's time) and a docked ship.
const STORE := preload("res://scripts/persistence/save_store.gd")
const REGISTRY := preload("res://scripts/menu/world_registry.gd")

## Parts of a character record that travel with it.
const RECORD_KEYS := ["progression", "gear", "inventory", "skill_ids", "slots", "skill_evidence", "form", "health", "magicules"]
## Progression entries that belong to a world.
const WORLD_PROGRESSION := ["chests", "spots", "elites", "ferry_pass_until", "ship", "storage"]

## What travels of a character record.
static func carried(record: Dictionary) -> Dictionary:
    var result := {}
    for key in RECORD_KEYS:
        if record.has(key):
            result[key] = record[key].duplicate(true) if record[key] is Dictionary or record[key] is Array else record[key]
    if result.get("progression") is Dictionary:
        for key in WORLD_PROGRESSION:
            result.progression.erase(key)
    return result

## A world's record for a character with the travelling parts replaced (the world's own parts kept).
static func merged(base: Dictionary, travelling: Dictionary) -> Dictionary:
    var result := base.duplicate(true)
    for key in RECORD_KEYS:
        if not travelling.has(key):
            continue
        if key == "progression" and travelling.progression is Dictionary:
            var progression: Dictionary = travelling.progression.duplicate(true)
            var own: Dictionary = base.get("progression", {}) if base.get("progression") is Dictionary else {}
            for world_key in WORLD_PROGRESSION:
                if own.has(world_key):
                    progression[world_key] = own[world_key]
                else:
                    progression.erase(world_key)
            result.progression = progression
        else:
            result[key] = travelling[key].duplicate(true) if travelling[key] is Dictionary or travelling[key] is Array else travelling[key]
    # A character in a world's record has no running analysis or cast line from elsewhere.
    result["analysis"] = {"target": "", "remaining": 0.0, "focus": 0.0}
    result["fishing"] = []
    return result

## The characters of this computer's own worlds: [{path, world, race, level}], newest first.
static func own_characters(directory: String = REGISTRY.DEFAULT_DIR) -> Array:
    var result: Array = []
    for entry in REGISTRY.list(directory):
        if not entry.ok:
            continue
        var loaded: Dictionary = STORE.load_world(entry.path)
        var host: Variant = loaded.get("data", {}).get("players", {}).get("host")
        if not host is Dictionary or not host.get("progression") is Dictionary:
            continue
        result.append({"path": entry.path, "world": entry.name, "race": String(host.progression.get("race", "Slime")), "level": int(host.progression.get("level", 1))})
    return result

## The travelling parts of a world's own character ({} if the world cannot be read).
static func load_carried(path: String) -> Dictionary:
    var loaded: Dictionary = STORE.load_world(path)
    var host: Variant = loaded.get("data", {}).get("players", {}).get("host")
    return carried(host) if loaded.get("ok", false) and host is Dictionary else {}

## Write a character's travelling parts back into its own world (the world's own parts kept).
static func write_back(path: String, travelling: Dictionary) -> Error:
    var loaded: Dictionary = STORE.load_world(path)
    if not loaded.get("ok", false) or not loaded.data.get("players", {}).get("host") is Dictionary:
        return ERR_FILE_CANT_READ
    var data: Dictionary = loaded.data.duplicate(true)
    var record := merged(data.players.host, travelling)
    record["id"] = "host"
    if not STORE.validate_player(record, "host"):
        return ERR_INVALID_DATA
    data.players.host = record
    return STORE.write_world(path, data)
