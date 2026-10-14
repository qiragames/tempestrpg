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
## Minimal mix (user feedback after 24b: "short durations, lower volume, lower frequency"). Per
## sound: [volume dB, longest it may ring in seconds (cut with a short fade), minimum seconds
## before the same sound plays again anywhere]. The bus volumes from the settings apply on top.
const PROFILES := {
    "ui_accept": [-12.0, 0.18, 0.1], "ui_cancel": [-12.0, 0.2, 0.1], "ui_move": [-20.0, 0.1, 0.12],
    "swing": [-14.0, 0.2, 0.3], "bow": [-12.0, 0.25, 0.3], "hit": [-12.0, 0.2, 0.25],
    "hurt": [-10.0, 0.24, 0.45], "defeat": [-10.0, 0.35, 0.3], "magicules": [-16.0, 0.3, 0.8],
    "item": [-12.0, 0.4, 0.5], "gather": [-14.0, 0.3, 0.6], "analysis": [-12.0, 0.4, 1.5],
    "exhausted": [-10.0, 0.45, 3.0], "learned": [-10.0, 0.7, 1.0], "level_up": [-8.0, 0.9, 1.0],
    "chest": [-10.0, 0.7, 1.0], "form": [-12.0, 0.6, 1.0], "evolve": [-8.0, 0.45, 1.0],
    "build": [-10.0, 0.7, 1.0], "game_over": [-8.0, 1.4, 2.0], "shrine": [-12.0, 0.31, 1.0],
}
const DEFAULT_PROFILE := [-12.0, 0.4, 0.3]
## At most this many effect sounds ring at once; further ones are skipped.
const MAX_VOICES := 4
## World sounds fade out within this distance (px) of the listener.
const HEARING := 320.0
## Music sits under the effects.
const MUSIC_DB := -10.0
const CUT_FADE := 0.06

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
var _voices: Array = []

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
    var profile: Array = PROFILES.get(id, DEFAULT_PROFILE)
    var key := id + (str((at / 32.0).round()) if at is Vector2 else "")
    if now - float(_last_played.get(key, -1.0)) < REPEAT_GAP or now - float(_last_played.get(id, -100.0)) < float(profile[2]):
        return
    _voices = _voices.filter(func(voice): return is_instance_valid(voice) and voice.playing)
    if bus == "SFX" and _voices.size() >= MAX_VOICES:
        return
    var stream: AudioStream = null if silent else _stream(SFX_DIR + id + ".wav")
    if stream == null and not silent:
        return
    _last_played[key] = now
    _last_played[id] = now
    played[id] = int(played.get(id, 0)) + 1
    if silent:
        return
    if at is Vector2 and get_tree().current_scene is Node2D:
        var spatial := AudioStreamPlayer2D.new()
        spatial.stream = stream
        spatial.bus = bus
        spatial.max_distance = HEARING
        spatial.attenuation = 2.0
        spatial.volume_db = float(profile[0])
        spatial.position = at
        spatial.finished.connect(spatial.queue_free)
        get_tree().current_scene.add_child(spatial)
        spatial.play()
        _cut(spatial, float(profile[1]), float(profile[0]), true)
        return
    var player: AudioStreamPlayer = _pool[_next_player]
    _next_player = (_next_player + 1) % _pool.size()
    player.stream = stream
    player.bus = bus
    player.volume_db = float(profile[0])
    player.play()
    _cut(player, float(profile[1]), float(profile[0]), false)

## Ends a sound after `seconds` with a short fade (long samples become short cues).
func _cut(voice: Node, seconds: float, volume: float, free: bool) -> void:
    if voice.get("bus") == "SFX":
        _voices.append(voice)
    # A pooled player may be reused before an earlier cut ran: that cut no longer applies.
    if voice.has_meta("cut") and voice.get_meta("cut") is Tween and voice.get_meta("cut").is_valid():
        voice.get_meta("cut").kill()
    if voice.stream.get_length() <= seconds + 0.01:
        return
    var stop := create_tween()
    voice.set_meta("cut", stop)
    stop.tween_interval(maxf(0.0, seconds - CUT_FADE))
    stop.tween_property(voice, "volume_db", -60.0, CUT_FADE)
    stop.tween_callback(func():
        if is_instance_valid(voice):
            voice.stop()
            if free:
                voice.queue_free()
    )

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
    fade.tween_property(incoming, "volume_db", MUSIC_DB, FADE_SECONDS)

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
