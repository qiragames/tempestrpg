extends Control
## The reel-in bar (M6b): a marker sweeps back and forth; press F while it is inside the green
## zone. The zone's width is your catch chance per press (shown as a percentage); rarer fish need
## more hits, sweep faster and forgive two misses.
const UI := preload("res://scripts/ui/ui_style.gd")
const FISHES := preload("res://scripts/professions/fish_catalogue.gd")

var reel: Dictionary = {}

func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
    if reel.is_empty():
        return
    var rarity: int = int(reel.get("rarity", 0))
    var colour: Color = FISHES.RARITY_COLOURS[rarity]
    var bar := Rect2(Vector2(0, 12), Vector2(size.x, 12))
    draw_rect(bar.grow(2), Color(0.02, 0.03, 0.05, 0.9))
    draw_rect(bar, Color(0.12, 0.16, 0.22))
    var width: float = float(reel.get("width", 0.3))
    var centre: float = float(reel.get("centre", 0.5))
    draw_rect(Rect2(bar.position + Vector2((centre - width / 2.0) * bar.size.x, 0), Vector2(width * bar.size.x, bar.size.y)), Color(0.3, 0.85, 0.4, 0.85))
    var at: float = FISHES.marker(float(reel.get("t", 0.0)), float(reel.get("speed", 1.0)))
    var x: float = bar.position.x + at * bar.size.x
    draw_rect(Rect2(Vector2(x - 1, bar.position.y - 3), Vector2(3, bar.size.y + 6)), Color.WHITE)
    var font := get_theme_default_font()
    var text := "%s bite · %d/%d hits · zone %d%% · misses %d/%d · F" % [FISHES.RARITIES[rarity], int(reel.get("hits", 0)), int(reel.get("need", 1)), int(round(width * 100.0)), int(reel.get("misses", 0)), FISHES.MISSES]
    draw_string_outline(font, Vector2(0, 9), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, 3, Color(0.02, 0.03, 0.05))
    draw_string(font, Vector2(0, 9), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, colour)
    # Time left before the fish escapes.
    var left: float = clampf(1.0 - float(reel.get("t", 0.0)) / FISHES.REEL_SECONDS, 0.0, 1.0)
    draw_rect(Rect2(Vector2(0, bar.end.y + 3), Vector2(size.x * left, 2)), colour)
