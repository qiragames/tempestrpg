extends Node2D
## A deterministic placeholder map: visual obstacles and collisions share geometry.

const WORLD_SIZE := Vector2(960, 640)
const POND := Rect2(624, 112, 160, 96)
const ROCKS: Array[Rect2] = [Rect2(440, 250, 32, 24), Rect2(304, 400, 40, 24)]
const TREES: Array[Vector2] = [Vector2(160, 144), Vector2(240, 192), Vector2(352, 112), Vector2(544, 160), Vector2(816, 288), Vector2(176, 464), Vector2(576, 496), Vector2(752, 480)]

func _ready() -> void:
    $Player/Health.changed.connect(_health_changed)
    $Player/Health.defeated.connect(func():
        $HUD/SystemVoice.text = "[System] Vital signs depleted. Press R to retry."
        $Player.queue_redraw()
    )
    $ForestGnasher/Health.defeated.connect(func():
        if $Player/Health.current > 0:
            $HUD/SystemVoice.text = "[System] Threat neutralized. Specimen retained."
    )
    _add_obstacle(POND)
    for rock in ROCKS:
        _add_obstacle(rock)
    for tree in TREES:
        _add_obstacle(Rect2(tree + Vector2(-6, 4), Vector2(12, 12)))
    for border in [Rect2(-16, 0, 16, 640), Rect2(960, 0, 16, 640), Rect2(0, -16, 960, 16), Rect2(0, 640, 960, 16)]:
        _add_obstacle(border)

func _health_changed(current: int, maximum: int) -> void:
    $HUD/Health.text = "HP %d / %d" % [current, maximum]

func _add_obstacle(rect: Rect2) -> void:
    var body := StaticBody2D.new()
    body.position = rect.get_center()
    var collider := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = rect.size
    collider.shape = shape
    body.add_child(collider)
    add_child(body)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("restart"):
        get_tree().reload_current_scene()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("294b40"))
    # Integer-aligned accents keep the placeholder readable at the base resolution.
    for y in range(0, 640, 16):
        for x in range(0, 960, 16):
            if (x * 7 + y * 11) % 13 < 3:
                draw_rect(Rect2(x + 3, y + 5, 3, 2), Color("376451"))
                draw_rect(Rect2(x + 6, y + 3, 2, 4), Color("376451"))
    draw_rect(Rect2(0, 304, 960, 56), Color("82765a"))
    draw_rect(Rect2(464, 304, 40, 336), Color("82765a"))
    draw_rect(POND.grow(5), Color("4d8270"))
    draw_rect(POND, Color("315e79"))
    for x in range(640, 770, 32):
        draw_rect(Rect2(x, 144, 12, 2), Color("57909d"))
        draw_rect(Rect2(x + 8, 176, 16, 2), Color("57909d"))
    for rock in ROCKS:
        draw_rect(rock.grow(2), Color("243c3a"))
        draw_rect(rock, Color("72817b"))
        draw_rect(Rect2(rock.position + Vector2(4, 3), Vector2(rock.size.x - 8, 5)), Color("a0aaa0"))
    for tree in TREES:
        draw_rect(Rect2(tree + Vector2(-6, 0), Vector2(12, 16)), Color("655348"))
        draw_rect(Rect2(tree + Vector2(-20, -20), Vector2(40, 26)), Color("193d34"))
        draw_rect(Rect2(tree + Vector2(-15, -30), Vector2(30, 24)), Color("32634b"))
        draw_rect(Rect2(tree + Vector2(-9, -27), Vector2(18, 6)), Color("518366"))
