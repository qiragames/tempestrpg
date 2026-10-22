extends RefCounted
## SVE feedback 2026-10-22 (animated effects look good, also in the inventory): Epic and better
## items twinkle in their cells: small sparks rise through the icon in the rarity colour (more for
## Legendary and Mythic), and a Mythic icon gets a slow light sweep.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")

## Whether a cell with this rarity animates (it then redraws every frame).
static func animates(rarity: int) -> bool:
    return rarity >= 3 and not preload("res://scripts/visual/effects.gd").reduced

## Draws the sparks over an icon drawn in `rect` on `canvas`.
static func draw(canvas: CanvasItem, rect: Rect2, rarity: int, seed_value: int = 0) -> void:
    if not animates(rarity):
        return
    var colour := Color(GEAR.RARITY_COLORS[clampi(rarity, 0, GEAR.RARITY_COLORS.size() - 1)])
    var now := Time.get_ticks_msec() / 1000.0
    var count: int = [0, 0, 0, 3, 5, 7][clampi(rarity, 0, 5)]
    for index in range(count):
        var offset := fposmod(sin(float(index * 12.9898 + seed_value) * 43758.5453), 1.0)
        var phase := fmod(now * (0.45 + 0.12 * (index % 3)) + offset, 1.0)
        var x := rect.position.x + rect.size.x * fposmod(offset * 3.7 + index * 0.31, 1.0)
        var y := rect.end.y - rect.size.y * phase
        var alpha := sin(PI * phase)
        var spark := 1.0 if index % 2 == 0 else 1.5
        canvas.draw_rect(Rect2(Vector2(x, y).round(), Vector2(spark, spark)), Color(colour.lightened(0.4), 0.85 * alpha))
    if rarity >= 5:
        var sweep := fmod(now * 0.5, 2.0)
        if sweep < 1.0:
            var x := rect.position.x + rect.size.x * sweep
            canvas.draw_line(Vector2(x, rect.position.y), Vector2(x - rect.size.x * 0.25, rect.end.y), Color(1, 1, 1, 0.22 * sin(PI * sweep)), 2.0)
