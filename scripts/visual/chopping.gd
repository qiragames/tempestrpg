extends RefCounted
## Chopping and mining (user request: characters should really hack down trees with an axe and
## mine stones and ores with a pickaxe, with a good animation). The tool swings in a wind-up and
## a fast strike; at the impact the tree or rock shakes and wood chips or stone sparks fly.
## Presentation only: the host decides the swings (see Player.start_gather).
const AXE := preload("res://assets/game/ui/tools/axe.png")
const PICKAXE := preload("res://assets/game/ui/tools/pickaxe.png")
const EFFECTS := preload("res://scripts/visual/effects.gd")
## Seconds per swing, and the part of a swing where the tool hits (0..1).
const SWING := 0.55
const IMPACT := 0.72

static func tool_for(resource: String) -> String:
    return "axe" if resource == "wood" else "pickaxe"

## Draw the tool at `phase` (0 = start of the wind-up, 1 = end of the swing).
static func draw_tool(canvas: CanvasItem, tool: String, phase: float, facing: Vector2, hand: Vector2 = Vector2(0, -2), scale: float = 1.0) -> void:
    var side := 1.0 if facing.x >= -0.1 else -1.0
    # Wind up slowly over the shoulder, then strike down fast.
    var angle: float
    if phase < IMPACT:
        angle = lerpf(0.2, -2.0, ease(phase / IMPACT, 0.6))
    else:
        angle = lerpf(-2.0, 0.9, ease((phase - IMPACT) / (1.0 - IMPACT), 0.25))
    var texture: Texture2D = AXE if tool == "axe" else PICKAXE
    canvas.draw_set_transform(hand + Vector2(5.0 * side, 0), angle * side, Vector2(side * scale, scale))
    canvas.draw_texture(texture, Vector2(-texture.get_width() / 2.0, -texture.get_height() + 2))
    canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The hit: chips (wood) or sparks (stone) at the deposit.
static func impact(world: Node, at: Vector2, resource: String) -> void:
    if world == null or not world.is_inside_tree():
        return
    var wood := resource == "wood"
    var burst := EFFECTS.spawn(world, "hit_spark", at + Vector2(0, -8))
    if burst != null:
        burst.modulate = Color("7ed07e") if resource == "herb" else (Color("c48a4a") if wood else Color("dfe6ee"))
        burst.scale = Vector2.ONE * 0.7
    if EFFECTS.reduced:
        return
    var chips := CPUParticles2D.new()
    chips.one_shot = true
    chips.explosiveness = 0.95
    chips.amount = 8
    chips.lifetime = 0.5
    chips.position = at + Vector2(0, -8)
    chips.direction = Vector2.UP
    chips.spread = 70.0
    chips.gravity = Vector2(0, 220)
    chips.initial_velocity_min = 40.0
    chips.initial_velocity_max = 80.0
    chips.scale_amount_min = 1.0
    chips.scale_amount_max = 2.0
    chips.color = Color("5aa04a") if resource == "herb" else (Color("8a5a2e") if wood else Color("9aa0a8"))
    chips.z_index = 6
    world.add_child(chips)
    chips.emitting = true
    world.get_tree().create_timer(1.0).timeout.connect(chips.queue_free)
