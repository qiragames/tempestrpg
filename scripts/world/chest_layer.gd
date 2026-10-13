extends Node2D
## Draws the world's seeded chests (17g): closed, or open for the local character once it opened
## them (each character opens each chest once).
const ART := preload("res://scripts/visual/world_art.gd")
var world: Node2D
var _time := 0.0

func _process(delta: float) -> void:
    _time += delta
    if _time >= 0.25:
        _time = 0.0
        queue_redraw()

func _draw() -> void:
    if world == null or not is_instance_valid(world.get_local_player()):
        return
    var opened: Array = world.get_local_player().progression.get("chests", [])
    for chest in world.layout.get("chests", []):
        var at: Vector2 = chest.position
        draw_rect(Rect2(at + Vector2(-7, 5), Vector2(14, 2)), Color(0.03, 0.12, 0.14, 0.35))
        ART.draw_prop(self, "chest_open" if chest.id in opened else "chest", at + Vector2(0, 7))
