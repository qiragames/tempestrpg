extends RefCounted
## Save slots: one world file per slot in user://worlds/, each carrying its own meta
## (name, seed, created, last played). Listing validates and migrates like loading does.
const STORE := preload("res://scripts/persistence/save_store.gd")
const DEFAULT_DIR := "user://worlds"
const MAX_SEED := 2147483647
const NAME_LENGTH := 32

static func clean_name(value: String) -> String:
    var text := ""
    for character in value.strip_edges():
        if character.unicode_at(0) >= 32:
            text += character
    return text.substr(0, NAME_LENGTH).strip_edges()

## Seeds like Minecraft: numbers are used directly, any other text is hashed, empty is random.
static func parse_seed(value: String) -> int:
    var text := value.strip_edges()
    if text.is_empty():
        var rng := RandomNumberGenerator.new()
        rng.randomize()
        return rng.randi() & MAX_SEED
    if text.is_valid_int():
        return absi(text.to_int()) % (MAX_SEED + 1)
    return text.hash() & MAX_SEED

## A new, unused file path derived from the world name.
static func new_world_path(name: String, directory: String = DEFAULT_DIR) -> String:
    var slug := ""
    for character in clean_name(name).to_lower():
        if character in "abcdefghijklmnopqrstuvwxyz0123456789":
            slug += character
        elif character in " -_" and not slug.ends_with("_"):
            slug += "_"
    slug = slug.trim_suffix("_").trim_prefix("_")
    if slug.is_empty():
        slug = "world"
    var path := directory.path_join(slug + ".json")
    var index := 2
    while FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
        path = directory.path_join("%s_%d.json" % [slug, index])
        index += 1
    return path

static func new_meta(name: String, seed: int) -> Dictionary:
    var now := int(Time.get_unix_time_from_system())
    return {"name": clean_name(name) if not clean_name(name).is_empty() else "New World", "seed": seed, "created": now, "last_played": now}

## Every world file, newest first. Unreadable files are listed as damaged instead of hidden.
static func list(directory: String = DEFAULT_DIR) -> Array:
    var worlds: Array = []
    var dir := DirAccess.open(directory)
    if dir == null:
        return worlds
    for file in dir.get_files():
        if not file.ends_with(".json"):
            continue
        var path := directory.path_join(file)
        var result: Dictionary = STORE.load_world(path)
        if not result.ok:
            worlds.append({"path": path, "file": file, "ok": false, "name": file.get_basename(), "seed": 0, "last_played": 0})
            continue
        var meta: Dictionary = result.data.get("meta", {})
        worlds.append({"path": path, "file": file, "ok": true, "recovered": result.recovered, "name": meta.get("name", file.get_basename()), "seed": int(meta.get("seed", 0)), "last_played": int(meta.get("last_played", 0))})
    worlds.sort_custom(func(a, b): return a.last_played > b.last_played)
    return worlds
