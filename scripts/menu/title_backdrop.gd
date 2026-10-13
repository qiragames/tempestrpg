extends Control
## Title backdrop after the user's title reference (step 22), drawn in code at 640x360: a stormy
## night sky with a swirling vortex, flashes of lightning, a distant castle, pine forest
## silhouettes and drifting embers. Purely decorative; deterministic apart from the clock.
const SKY_TOP := Color("120d24")
const SKY_BOTTOM := Color("3a2a52")
const CLOUD := Color("2a2140")
const CLOUD_LIGHT := Color("4a3a6a")
const FOREST_FAR := Color("1b2a2e")
const FOREST_NEAR := Color("0f1a1c")
const CASTLE := Color("231a35")
const BOLT := Color("e9dcff")
const EMBER := Color("f0a34a")

var _time := 0.0
var _flash := 0.0
var _bolt: PackedVector2Array = PackedVector2Array()
var _next_bolt := 1.2
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _rng.seed = 7

func _process(delta: float) -> void:
    _time += delta
    _flash = maxf(0.0, _flash - delta * 3.0)
    _next_bolt -= delta
    if _next_bolt <= 0.0:
        _next_bolt = _rng.randf_range(1.5, 4.0)
        _flash = 1.0
        _bolt = _make_bolt(Vector2(_rng.randf_range(380, 600), 20))
    queue_redraw()

func _make_bolt(start: Vector2) -> PackedVector2Array:
    var points := PackedVector2Array([start])
    var at := start
    while at.y < 190:
        at += Vector2(_rng.randf_range(-14, 14), _rng.randf_range(10, 22))
        points.append(at.round())
    return points

func _draw() -> void:
    # Sky in horizontal bands (pixel look), lit up by lightning.
    for band in range(18):
        var t := band / 17.0
        var color := SKY_TOP.lerp(SKY_BOTTOM, t).lerp(Color("6b5a8f"), _flash * 0.25)
        draw_rect(Rect2(0, band * 14, 640, 14), color)
    # A slow cloud band across the top of the sky.
    for index in range(16):
        var x := fmod(index * 53.0 + _time * 6.0, 700.0) - 30.0
        _cloud(Vector2(x, 14 + (index % 3) * 9), 16.0 + (index % 4) * 4.0, CLOUD)
    # Storm vortex: rotating cloud rings around a centre above the castle.
    var centre := Vector2(500, 110)
    for ring in range(6):
        var radius := 30.0 + ring * 22.0
        var turn := _time * (0.25 - ring * 0.03)
        for blob in range(10 + ring * 2):
            var angle := turn + blob * TAU / (10 + ring * 2)
            var at := centre + Vector2(cos(angle) * radius * 1.6, sin(angle) * radius * 0.55)
            _cloud(at, 13.0 - ring, CLOUD_LIGHT if (blob + ring) % 3 == 0 else CLOUD)
    # Funnel down to the ground.
    for step in range(12):
        var y := 130.0 + step * 10.0
        var width := 34.0 - step * 2.2 + sin(_time * 2.0 + step) * 2.0
        draw_rect(Rect2(Vector2(centre.x - width / 2 + sin(_time + step * 0.4) * 4, y).round(), Vector2(width, 8).round()), Color(CLOUD_LIGHT, 0.75))
    # Lightning bolt with a glow while the flash lasts.
    if _flash > 0.3 and _bolt.size() > 1:
        draw_polyline(_bolt, Color(BOLT, _flash * 0.35), 4.0)
        draw_polyline(_bolt, Color(BOLT, _flash), 1.0)
    # Distant hills and the castle silhouette.
    draw_rect(Rect2(0, 230, 640, 130), Color("241c38"))
    var castle := Vector2(500, 236)
    for tower in [[-40, 26, 8], [-24, 40, 10], [-8, 58, 12], [8, 46, 10], [24, 34, 8], [38, 22, 7]]:
        var x: float = castle.x + tower[0]
        draw_rect(Rect2(x, castle.y - tower[1], tower[2], tower[1]), CASTLE)
        draw_colored_polygon(PackedVector2Array([Vector2(x - 1, castle.y - tower[1]), Vector2(x + tower[2] / 2.0, castle.y - tower[1] - 10), Vector2(x + tower[2] + 1, castle.y - tower[1])]), CASTLE)
    draw_rect(Rect2(castle.x - 46, castle.y - 12, 92, 12), CASTLE)
    # Windows glimmer.
    for window in [Vector2(-20, -30), Vector2(-4, -44), Vector2(12, -26), Vector2(28, -18)]:
        draw_rect(Rect2(castle + window, Vector2(2, 3)), Color(EMBER, 0.6 + 0.3 * sin(_time * 3.0 + window.x)))
    # Pine forests: a far row and a near row of triangles.
    _pines(244, 18, 26, FOREST_FAR, 3)
    _pines(300, 26, 44, FOREST_NEAR, 11)
    draw_rect(Rect2(0, 330, 640, 30), FOREST_NEAR)
    # Embers drifting up.
    for index in range(26):
        var seed := float(index) * 37.7
        var x := fmod(seed * 13.0 + sin(_time * 0.7 + index) * 10.0, 640.0)
        var y := 360.0 - fmod(_time * (12.0 + index % 5 * 4.0) + seed * 9.0, 300.0)
        draw_rect(Rect2(Vector2(x, y).round(), Vector2(2, 2) if index % 3 else Vector2(1, 1)), Color(EMBER, 0.55 + 0.35 * sin(_time * 4.0 + index)))

## A flat cloud streak (an ellipse twice as wide as tall).
func _cloud(at: Vector2, radius: float, color: Color) -> void:
    draw_set_transform(at.round(), 0.0, Vector2(2.0, 0.6))
    draw_circle(Vector2.ZERO, radius, Color(color, 0.9))
    draw_set_transform(Vector2.ZERO)

func _pines(base: float, width: float, height: float, color: Color, offset: int) -> void:
    var x := -width
    var index := 0
    while x < 640 + width:
        var tall := height * (0.75 + 0.25 * float((index * 7 + offset) % 5) / 4.0)
        draw_colored_polygon(PackedVector2Array([Vector2(x, base + 60), Vector2(x + width / 2, base + 60 - tall - 30), Vector2(x + width, base + 60)]), color)
        x += width * 0.7
        index += 1
