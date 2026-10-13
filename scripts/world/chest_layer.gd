extends Node2D
## Draws the world's seeded chests (17g): closed, or open for the local character once it opened
## them (each character opens each chest once).
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
        draw_rect(Rect2(at + Vector2(-8, 4), Vector2(16, 3)), Color(0.03, 0.12, 0.14, 0.45))
        draw_rect(Rect2(at + Vector2(-7, -4), Vector2(14, 9)), Color("7a5530"))
        if chest.id in opened:
            draw_rect(Rect2(at + Vector2(-7, -9), Vector2(14, 3)), Color("5e4126"))
            draw_rect(Rect2(at + Vector2(-5, -3), Vector2(10, 3)), Color("2a1d12"))
        else:
            draw_rect(Rect2(at + Vector2(-7, -6), Vector2(14, 3)), Color("8f6a3c"))
            draw_rect(Rect2(at + Vector2(-1, -3), Vector2(2, 3)), Color("f0c75a"))
