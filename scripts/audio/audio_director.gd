extends Node
## Audio (step 23, autoload "Audio"): Music, SFX and UI buses with the local volume/mute settings,
## crossfading music tracks, pooled one-shot sounds (positional in the world or flat for the UI),
## and UI clicks for every button. Purely local presentation: nothing here is replicated or saved
## with a world; with the headless or dummy audio driver everything still runs silently.
const SETTINGS := preload("res://scripts/ui/settings.gd")
const MUSIC_DIR := "res://assets/game/audio/music/"
const SFX_DIR := "res://assets/game/audio/sfx/"
const BUSES := ["Music", "SFX", "UI"]
const FADE_SECONDS := 1.2
## The same sound from the same spot is not restarted within this many seconds (several hits in
## one frame, etc.); different characters' sounds still play together.
const REPEAT_GAP := 0.06
const POOL := 12

var current_music: String = ""
## Headless runs (tests, the cloud) record cues but start no playback: nothing can be heard there,
## and streams still playing when a test quits would outlive the engine.
var silent: bool = DisplayServer.get_name() == "headless"
## Sounds played (id → count), for tests and the playtest log.
var played: Dictionary = {}
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _music_players: Array = []
var _active_music: int = 0
var _pool: Array = []
var _next_player := 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for bus in BUSES:
        if AudioServer.get_bus_index(bus) == -1:
            AudioServer.add_bus()
            var index := AudioServer.bus_count - 1
            AudioServer.set_bus_name(index, bus)
            AudioServer.set_bus_send(index, "Master")
    for index in range(2):
        var player := AudioStreamPlayer.new()
        player.bus = "Music"
        player.volume_db = -80.0
        add_child(player)
        _music_players.append(player)
    for index in range(POOL):
        var flat := AudioStreamPlayer.new()
        flat.bus = "SFX"
        add_child(flat)
        _pool.append(flat)
    apply_settings(SETTINGS.load_settings())
    get_tree().node_added.connect(_on_node_added)

## Volumes (0..1) and mute from the local settings.
func apply_settings(values: Dictionary) -> void:
    _set_bus("Music", float(values.get("music", 0.7)))
    _set_bus("SFX", float(values.get("sfx", 0.8)))
    _set_bus("UI", float(values.get("sfx", 0.8)))
    AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), bool(values.get("muted", false)))

func _set_bus(bus: String, volume: float) -> void:
    var index := AudioServer.get_bus_index(bus)
    AudioServer.set_bus_volume_db(index, linear_to_db(clampf(volume, 0.0, 1.0)) if volume > 0.0 else -80.0)
    AudioServer.set_bus_mute(index, volume <= 0.0)

func bus_volume(bus: String) -> float:
    var index := AudioServer.get_bus_index(bus)
    return 0.0 if AudioServer.is_bus_mute(index) else db_to_linear(AudioServer.get_bus_volume_db(index))

func _stream(path: String) -> AudioStream:
    if not _streams.has(path):
        _streams[path] = load(path) if ResourceLoader.exists(path) else null
    return _streams[path]

## One-shot sound by id (`assets/game/audio/sfx/<id>.wav`). In the world (`at` given) it is
## positional; otherwise flat on the UI/SFX bus.
func play(id: String, at: Variant = null, bus: String = "SFX") -> void:
    var now := Time.get_ticks_msec() / 1000.0
    var key := id + (str((at / 32.0).round()) if at is Vector2 else "")
    if now - float(_last_played.get(key, -1.0)) < REPEAT_GAP:
        return
    var stream: AudioStream = null if silent else _stream(SFX_DIR + id + ".wav")
    if stream == null and not silent:
        return
    _last_played[key] = now
    played[id] = int(played.get(id, 0)) + 1
    if silent:
        return
    if at is Vector2 and get_tree().current_scene is Node2D:
        var spatial := AudioStreamPlayer2D.new()
        spatial.stream = stream
        spatial.bus = bus
        spatial.max_distance = 700.0
        spatial.position = at
        spatial.finished.connect(spatial.queue_free)
        get_tree().current_scene.add_child(spatial)
        spatial.play()
        return
    var player: AudioStreamPlayer = _pool[_next_player]
    _next_player = (_next_player + 1) % _pool.size()
    player.stream = stream
    player.bus = bus
    player.play()

## Crossfade to a music track by id (`assets/game/audio/music/<id>.ogg`); "" fades out.
func music(id: String) -> void:
    if id == current_music:
        return
    current_music = id
    var outgoing: AudioStreamPlayer = _music_players[_active_music]
    _active_music = 1 - _active_music
    var incoming: AudioStreamPlayer = _music_players[_active_music]
    var fade := create_tween().set_parallel(true)
    fade.tween_property(outgoing, "volume_db", -80.0, FADE_SECONDS)
    if id.is_empty() or silent:
        return
    var stream := _stream(MUSIC_DIR + id + ".ogg")
    if stream is AudioStreamOggVorbis:
        stream.loop = true
    incoming.stream = stream
    incoming.volume_db = -30.0
    incoming.play()
    fade.tween_property(incoming, "volume_db", 0.0, FADE_SECONDS)

## Release playing streams when the game (or a test) quits, so nothing outlives the engine.
func _exit_tree() -> void:
    for player in _music_players + _pool:
        player.stop()
        player.stream = null
    _streams.clear()

## Every button clicks; focus moves tick quietly (UI bus).
func _on_node_added(node: Node) -> void:
    if node is BaseButton:
        node.pressed.connect(func(): play("ui_accept", null, "UI"))
        node.focus_entered.connect(func():
            if node.is_visible_in_tree():
                play("ui_move", null, "UI")
        )
