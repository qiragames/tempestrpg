extends Control
## World map (M4.5a, key M or the pause menu): the whole archipelago drawn from WorldMap at one
## pixel per tile, region names (regions across the sea are marked as reachable by ship later),
## your position (blinking) and the other characters. Opens like the other windows: solo play
## pauses, online only this character stops.
const MAP := preload("res://scripts/world/world_map.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const FRAME := Rect2(20, 12, 600, 336)
const IMAGE_AT := Vector2(120, 58)
## Map colours by terrain.
const COLORS := {
    "ocean": Color("2f6fa8"), "shore": Color("6fc3dc"), "lake": Color("5fb8d8"), "lava": Color("e0642a"),
    "path": Color("b8784f"), "bridge": Color("d79a55"),
    0: Color("f2cf8f"), 1: Color("a7bb3c"), 2: Color("5f9a3a"), 3: Color("f0a35a"), 4: Color("7a7072"),
}
## Label anchors (tiles) per region.
const LABELS := {
    MAP.Region.CLEARING: Vector2(190, 116), MAP.Region.THORNWOOD: Vector2(104, 84), MAP.Region.MIRROR_LAKE: Vector2(246, 56),
    MAP.Region.CINDER_CRATER: Vector2(256, 180), MAP.Region.HARROWMERE: Vector2(346, 74), MAP.Region.AMBERVALE: Vector2(180, 244),
    MAP.Region.EMBERREACH: Vector2(364, 220), MAP.Region.SEA: Vector2(330, 140),
}

var hud: CanvasLayer
var map_texture: ImageTexture
var _close: Button
var _canvas: Control
var _time := 0.0
var _paused_before_open: bool = false

static func image() -> Image:
    var map: Dictionary = MAP.data()
    var picture := Image.create(MAP.COLS, MAP.ROWS, false, Image.FORMAT_RGBA8)
    for y in range(MAP.ROWS):
        for x in range(MAP.COLS):
            var color: Color
            var ocean: int = MAP.corners(map.ocean, x, y)
            if map.bridge[MAP.tile_index(x, y)] == 1:
                color = COLORS.bridge
            elif ocean == 15:
                color = COLORS.ocean
            elif ocean > 0:
                color = COLORS.shore
            elif MAP.corners(map.lake, x, y) >= 8:
                color = COLORS.lake
            elif MAP.corners(map.lava, x, y) >= 8:
                color = COLORS.lava
            elif map.dirt[MAP.vertex_index(x, y)] == 1:
                color = COLORS.path
            else:
                color = COLORS[int(map.ground[MAP.vertex_index(x, y)])]
            picture.set_pixel(x, y, color)
    return picture

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "WorldMapPanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.8)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var frame := Panel.new()
    frame.position = FRAME.position
    frame.size = FRAME.size
    frame.add_theme_stylebox_override("panel", UI.ornate())
    add_child(frame)
    UI.heading(hud._label("WORLD MAP · THE ARCHIPELAGO", FRAME.position + Vector2(14, 10), Vector2(400, 20), self, 14))
    _close = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    _close.pressed.connect(close)
    _canvas = Control.new()
    _canvas.position = IMAGE_AT
    _canvas.size = Vector2(MAP.COLS, MAP.ROWS)
    _canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _canvas.draw.connect(_draw_map)
    add_child(_canvas)
    hud._label("Faded names: across the sea — ferries and ships come later. M / Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(560, 14), self, 9).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func _process(delta: float) -> void:
    if visible:
        _time += delta
        _canvas.queue_redraw()

## Map pixel for a world position.
static func to_map(world: Vector2) -> Vector2:
    return (world - MAP.ORIGIN) / MAP.TILE

func _draw_map() -> void:
    if map_texture == null:
        map_texture = ImageTexture.create_from_image(image())
    _canvas.draw_texture(map_texture, Vector2.ZERO)
    _canvas.draw_rect(Rect2(Vector2(-1, -1), _canvas.size + Vector2(2, 2)), UI.GOLD_DARK, false, 1.0)
    var font: Font = _canvas.get_theme_default_font()
    for region in LABELS:
        var name: String = MAP.REGION_NAMES[region]
        var size := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
        var at: Vector2 = LABELS[region] - Vector2(size.x / 2.0, 0)
        var reachable: bool = region in MAP.REACHABLE or region == MAP.Region.SEA
        _canvas.draw_string_outline(font, at.round(), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0.03, 0.04, 0.06))
        _canvas.draw_string(font, at.round(), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.TEXT if reachable else Color(UI.TEXT, 0.55))
    # Other characters, then you (blinking).
    for child in hud.get_parent().get_children():
        if child is CharacterBody2D and child.has_method("race") and child != hud.player:
            _canvas.draw_rect(Rect2(to_map(child.global_position).round() - Vector2(1, 1), Vector2(3, 3)), Color.WHITE)
    var me := to_map(hud.player.global_position).round()
    if fmod(_time, 0.8) < 0.55:
        _canvas.draw_circle(me, 3.5, Color(0.03, 0.04, 0.06))
        _canvas.draw_circle(me, 2.5, UI.CYAN)

func open() -> void:
    if hud.menu_open():
        return
    _paused_before_open = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    _time = 0.0
    show()
    _close.grab_focus()

func close() -> void:
    if not visible:
        return
    hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before_open
