extends Node2D
## Wild animals that can be tamed as mounts (M4.5d): boars in Ambervale, lions in the Sunscorch
## Desert. They graze around their spot (presentation only, the same on every peer); taming is a
## host action on the character (Player.tame). Nothing to save: a tamed animal stays in the wild
## for everyone else.
const TRAVEL := preload("res://scripts/travel/travel_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")

var _bodies: Dictionary = {}

func _ready() -> void:
    name = "WildMounts"
    y_sort_enabled = true
    for entry in TRAVEL.WILD_MOUNTS:
        var body := Sprite2D.new()
        body.name = entry[0]
        body.texture = load("res://assets/game/sprites/%s/side.png" % TRAVEL.MOUNTS[entry[1]][3])
        body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        body.region_enabled = true
        body.region_rect = Rect2(0, 0, body.texture.get_width() / 2, body.texture.get_height())
        body.offset = Vector2(0, -body.texture.get_height() / 2.0)
        body.position = home(entry[0])
        add_child(body)
        _bodies[entry[0]] = body

static func home(id: String) -> Vector2:
    for entry in TRAVEL.WILD_MOUNTS:
        if entry[0] == id:
            return MAP.to_world(entry[2])
    return Vector2.INF

## The wild animal within taming reach of a position ("" if none).
static func nearest(at: Vector2) -> String:
    for entry in TRAVEL.WILD_MOUNTS:
        if at.distance_to(MAP.to_world(entry[2])) <= TRAVEL.TAME_REACH + 24.0:
            return entry[0]
    return ""

func _process(_delta: float) -> void:
    # Slow grazing loops around the home spot (time-based, identical on every peer).
    var t := Time.get_ticks_msec() / 1000.0
    for id in _bodies:
        var phase := float(hash(id) % 100) / 100.0 * TAU
        var body: Sprite2D = _bodies[id]
        var target := home(id) + Vector2(cos(t * 0.25 + phase) * 14.0, sin(t * 0.18 + phase) * 6.0)
        body.flip_h = target.x < body.position.x
        body.region_rect.position.x = (int(t * 4.0) % 2) * body.region_rect.size.x
        body.position = target
