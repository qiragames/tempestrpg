extends Node2D
## Day, night and weather on screen (every peer, presentation only): the ambient light of the hour
## (darker underground), soft lights around this peer's character and the towns' plazas at night,
## the weather of the region this peer's character stands in (rain, storms with lightning, snow,
## sandstorms, ash, fog and gloom mist) as particles and a drifting haze. See DayNight for the rules.
const DAY := preload("res://scripts/world/day_night.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const CAVE_TINT := Color(0.62, 0.6, 0.72)

var world: Node2D
var ambient: CanvasModulate
var _player_light: PointLight2D
var _town_lights: Array = []
var _particles: CPUParticles2D
var _haze: ColorRect
var _shown_weather := ""
var _flash := 0.0
var _flash_rng := RandomNumberGenerator.new()
## The weather where this peer's character stands (read by the HUD).
var weather_id := "clear"

func _init(owner_world: Node2D = null) -> void:
    world = owner_world
    name = "Sky"
    z_index = 30

func _ready() -> void:
    _flash_rng.randomize()
    ambient = CanvasModulate.new()
    ambient.name = "Ambient"
    world.add_child.call_deferred(ambient)
    var glow := _light_texture()
    _player_light = PointLight2D.new()
    _player_light.texture = glow
    _player_light.texture_scale = 1.3
    _player_light.color = Color(1.0, 0.9, 0.7)
    _player_light.energy = 0.0
    add_child(_player_light)
    for town in MAP.TOWNS:
        var light := PointLight2D.new()
        light.texture = glow
        light.texture_scale = 2.0 if town[4] == "town" else 1.4
        light.color = Color(1.0, 0.8, 0.5)
        light.energy = 0.0
        light.position = MAP.to_world(town[3])
        add_child(light)
        _town_lights.append(light)
    _particles = CPUParticles2D.new()
    _particles.emitting = false
    _particles.local_coords = false
    _particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    _particles.emission_rect_extents = Vector2(420, 260)
    add_child(_particles)
    _haze = ColorRect.new()
    _haze.size = Vector2(1100, 700)
    _haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _haze.visible = false
    var haze_material := ShaderMaterial.new()
    haze_material.shader = load("res://assets/game/world/haze.gdshader")
    var noise := NoiseTexture2D.new()
    noise.seamless = true
    noise.width = 256
    noise.height = 256
    noise.noise = FastNoiseLite.new()
    noise.noise.frequency = 0.012
    haze_material.set_shader_parameter("noise", noise)
    _haze.material = haze_material
    add_child(_haze)

static func _light_texture() -> GradientTexture2D:
    var texture := GradientTexture2D.new()
    texture.width = 128
    texture.height = 128
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(0.5, 0.5)
    texture.fill_to = Vector2(1.0, 0.5)
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1, 1, 1, 1))
    gradient.set_color(1, Color(1, 1, 1, 0))
    texture.gradient = gradient
    return texture

func _process(delta: float) -> void:
    var me: Node2D = world.get_local_player() if world != null else null
    if not is_instance_valid(me):
        return
    var time: float = float(world.progression.get("world_time", 0.0))
    var underground: bool = not MAP.dungeon_at(me.global_position).is_empty()
    weather_id = "clear" if underground else DAY.weather(MAP.region_name(me.global_position), time)
    var light: Color = CAVE_TINT if underground else DAY.ambient(time) * Color(DAY.WEATHER[weather_id][1])
    # Thunderstorms flash now and then.
    _flash = maxf(0.0, _flash - delta * 3.0)
    if weather_id == "storm" and _flash <= 0.0 and _flash_rng.randf() < delta * 0.12:
        _flash = 1.0
    light = light.lerp(Color(1.4, 1.4, 1.5), _flash * 0.6)
    if is_instance_valid(ambient):
        ambient.color = light
    var dark: float = 0.7 if underground else DAY.darkness(time)
    _player_light.global_position = me.global_position
    _player_light.energy = dark * 0.55
    for town_light in _town_lights:
        town_light.energy = dark * 0.45 if town_light.global_position.distance_to(me.global_position) < 900.0 else 0.0
    _update_weather(me)

func _update_weather(me: Node2D) -> void:
    _particles.global_position = me.global_position + Vector2(0, -80)
    _haze.global_position = me.global_position - _haze.size / 2.0
    if _haze.visible:
        _haze.material.set_shader_parameter("origin", _haze.global_position / _haze.size)
    if weather_id == _shown_weather:
        return
    _shown_weather = weather_id
    # User feedback 2026-10-22 (the rain looked like blue bars): thin, faint streaks that lean
    # with their fall and fade toward the top.
    var falling := {"rain": [Color(0.78, 0.87, 1.0, 0.38), 520, Vector2(70, 460), 0.7, Vector2(1, 7)], "storm": [Color(0.82, 0.88, 1.0, 0.45), 750, Vector2(140, 560), 0.6, Vector2(1, 9)],
        "monsoon": [Color(0.78, 0.92, 0.92, 0.4), 650, Vector2(60, 500), 0.65, Vector2(1, 8)], "snow": [Color(1, 1, 1, 0.95), 450, Vector2(18, 45), 7.0, Vector2(3, 3)],
        "sandstorm": [Color(0.98, 0.82, 0.5, 0.75), 750, Vector2(480, 50), 1.5, Vector2(5, 2)], "ashfall": [Color(0.3, 0.26, 0.26, 0.9), 280, Vector2(12, 40), 7.0, Vector2(3, 3)]}
    if falling.has(weather_id):
        var spec: Array = falling[weather_id]
        _particles.amount = int(spec[1])
        _particles.color = spec[0]
        _particles.gravity = Vector2.ZERO
        _particles.direction = Vector2(spec[2]).normalized()
        _particles.spread = 6.0
        _particles.initial_velocity_min = Vector2(spec[2]).length() * 0.85
        _particles.initial_velocity_max = Vector2(spec[2]).length()
        _particles.lifetime = spec[3]
        var image := Image.create(int(spec[4].x), int(spec[4].y), false, Image.FORMAT_RGBA8)
        image.fill(Color.WHITE)
        var streak: bool = weather_id in ["rain", "storm", "monsoon"]
        if streak:
            for y in range(image.get_height()):
                for x in range(image.get_width()):
                    image.set_pixel(x, y, Color(1, 1, 1, 0.25 + 0.75 * float(y + 1) / image.get_height()))
        _particles.texture = ImageTexture.create_from_image(image)
        # Streaks point along their fall.
        _particles.particle_flag_align_y = streak
        _particles.rotation = 0.0
        _particles.emitting = true
    else:
        _particles.emitting = false
    var hazes := {"fog": Color(0.92, 0.94, 0.97, 0.55), "gloom_mist": Color(0.88, 0.78, 1.0, 0.5), "sandstorm": Color(1.0, 0.86, 0.6, 0.5), "monsoon": Color(0.88, 0.95, 0.93, 0.35)}
    _haze.visible = hazes.has(weather_id)
    if _haze.visible:
        _haze.material.set_shader_parameter("tint", hazes[weather_id])
