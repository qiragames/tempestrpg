extends RefCounted
## Where the game keeps saves (user request): its own folder per player, %APPDATA%\TempestRPG on
## Windows (project setting `application/config/use_custom_user_dir`), never next to the game.
## Worlds, character profiles, the server key and settings that earlier versions kept in Godot's
## shared folder (%APPDATA%\Godot\app_userdata\TempestRPG) are copied over once, on the first
## start — the old copies stay as a backup.
const MARKER := "user://moved_from_godot_folder.txt"
const KEEP := ["worlds", "profiles", "server", "settings.cfg"]

## The folder of earlier versions (empty if it does not apply).
static func previous_folder() -> String:
    var base := OS.get_data_dir()
    if base.is_empty():
        return ""
    var folder := base.path_join("Godot").path_join("app_userdata").path_join(ProjectSettings.get_setting("application/config/name", "TempestRPG"))
    return folder if folder != OS.get_user_data_dir() and DirAccess.dir_exists_absolute(folder) else ""

## Copy the previous folder's saves once. Returns how many files were copied.
static func adopt_previous(from: String = previous_folder(), to: String = OS.get_user_data_dir()) -> int:
    if from.is_empty() or FileAccess.file_exists(to.path_join(MARKER.trim_prefix("user://"))):
        return 0
    DirAccess.make_dir_recursive_absolute(to)
    var copied := 0
    for entry in KEEP:
        var source := from.path_join(entry)
        var target := to.path_join(entry)
        if DirAccess.dir_exists_absolute(source):
            copied += _copy_tree(source, target)
        elif FileAccess.file_exists(source) and not FileAccess.file_exists(target):
            if DirAccess.copy_absolute(source, target) == OK:
                copied += 1
    var note := FileAccess.open(to.path_join(MARKER.trim_prefix("user://")), FileAccess.WRITE)
    if note != null:
        note.store_string("Saves copied on %s from:\n%s\n(%d files; the originals were left in place.)\n" % [Time.get_datetime_string_from_system(), from, copied])
        note.close()
    return copied

## Copy a folder; files already in the target are kept (never overwritten).
static func _copy_tree(source: String, target: String) -> int:
    DirAccess.make_dir_recursive_absolute(target)
    var copied := 0
    for file in DirAccess.get_files_at(source):
        if not FileAccess.file_exists(target.path_join(file)) and DirAccess.copy_absolute(source.path_join(file), target.path_join(file)) == OK:
            copied += 1
    for folder in DirAccess.get_directories_at(source):
        copied += _copy_tree(source.path_join(folder), target.path_join(folder))
    return copied
