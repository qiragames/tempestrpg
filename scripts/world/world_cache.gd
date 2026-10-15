extends RefCounted
## Precomputed world (M4.5c): the map masks, collision rectangles, terrain tile layers, prop list
## and world-map picture of WorldMap/WorldTerrain, stored compressed in one file. Building them
## takes several seconds at the grown map size; loading takes a fraction of that. The file is
## keyed by a hash of the sources it is built from (line endings normalised, so Windows and Linux
## checkouts agree); when they change, the world is computed from scratch (correct, only slower)
## until `tools/build_world_cache.gd` is run again — `tests/world_map.gd` checks the file is current.
const PATH := "res://assets/game/world/world_cache.bin"
const SOURCES := [
    "res://scripts/world/world_map.gd",
    "res://scripts/world/world_terrain.gd",
    "res://scripts/world/world_layout.gd",
    "res://scripts/world/region_content.gd",
    "res://scripts/bosses/boss_catalogue.gd",
    "res://scripts/dungeons/dungeon_catalogue.gd",
]

static var _parts: Dictionary = {}
static var _tried := false

static func key() -> String:
    var text := ""
    for path in SOURCES:
        text += FileAccess.get_file_as_string(path).replace("\r", "")
    return text.md5_text()

## Whether the stored file matches the current sources.
static func current() -> bool:
    _load()
    return not _parts.is_empty()

## One stored part ("map", "rects", "layers", "props", "image"), or null when there is no
## current cache.
static func load_part(part: String) -> Variant:
    _load()
    return _parts.get(part)

static func _load() -> void:
    if _tried:
        return
    _tried = true
    if not FileAccess.file_exists(PATH):
        return
    var file := FileAccess.open_compressed(PATH, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
    if file == null:
        return
    var stored: Variant = file.get_var()
    file.close()
    # An exported game ships compiled scripts (no sources to hash): it trusts the cache built
    # with it (the release is exported right after the cache is rebuilt and checked).
    if stored is Dictionary and (OS.has_feature("template") or stored.get("key") == key()):
        _parts = stored

## Writes the parts (called by the builder tool).
static func save(parts: Dictionary) -> int:
    parts["key"] = key()
    var file := FileAccess.open_compressed(ProjectSettings.globalize_path(PATH), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
    if file == null:
        return FileAccess.get_open_error()
    file.store_var(parts)
    file.close()
    _parts = parts
    _tried = true
    return OK

## Forget what was loaded (tests and the builder).
static func reset() -> void:
    _parts = {}
    _tried = false
