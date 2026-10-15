extends SceneTree
## Saves live in the game's own folder (user request); earlier versions' saves are copied over
## once (never overwriting newer files) and the originals stay.
const FOLDER := preload("res://scripts/persistence/save_folder.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("_run")
func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func _write(path: String, text: String) -> void:
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(text)
    file.close()
func _run() -> void:
    _check(OS.get_user_data_dir().replace("\\", "/").ends_with("/TempestRPG") and not OS.get_user_data_dir().contains("app_userdata"), "Saves live in the game's own folder (%s)" % OS.get_user_data_dir())
    var base := OS.get_temp_dir().path_join("tempestrpg-folder-" + Crypto.new().generate_random_bytes(6).hex_encode())
    var old := base.path_join("old")
    var new := base.path_join("new")
    _write(old.path_join("worlds/alpha.json"), "{\"a\":1}")
    _write(old.path_join("worlds/alpha.json.bak"), "{\"a\":0}")
    _write(old.path_join("profiles/characters.json"), "{}")
    _write(old.path_join("settings.cfg"), "[display]")
    _write(old.path_join("logs/godot.log"), "x")
    _write(new.path_join("worlds/alpha.json"), "{\"a\":2}")
    var copied := FOLDER.adopt_previous(old, new)
    _check(copied == 3 and FileAccess.file_exists(new.path_join("worlds/alpha.json.bak")) and FileAccess.file_exists(new.path_join("profiles/characters.json")) and FileAccess.file_exists(new.path_join("settings.cfg")), "Worlds, profiles and settings are copied (%d files)" % copied)
    _check(FileAccess.get_file_as_string(new.path_join("worlds/alpha.json")) == "{\"a\":2}" and not FileAccess.file_exists(new.path_join("logs/godot.log")), "Newer files are never overwritten; logs stay behind")
    _check(FileAccess.file_exists(old.path_join("worlds/alpha.json")), "The originals stay as a backup")
    _check(FOLDER.adopt_previous(old, new) == 0, "Copied only once")
    print("Save folder checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
