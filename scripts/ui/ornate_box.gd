extends StyleBox
## Ornamented frame (step 22, user request: "not just a straight box"): a dark fill under a
## white Kenney Fantasy UI border (CC0, assets/game/ui/frames/) tinted per use — gold panels,
## cyan analysis, rarity colours on item cards. The corners keep their pixel ornaments; the
## straight edges stretch.
@export var texture: Texture2D
@export var bg_color := Color(0.07, 0.09, 0.12, 0.94)
@export var border_color := Color("c49a52")
## Size of the ornamented corner in the 48x48 source.
@export var corner := 16
## The fill stops inside the outer line so nothing pokes past the ornaments.
@export var inset := 2.0
## A small gem on the top edge (windows and banners, as in the user's references).
@export var crest := false
## The ornaments are drawn this far outside the box, so corner knots sit around the content
## instead of on top of it.
@export var outset := 0.0

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
    RenderingServer.canvas_item_add_rect(to_canvas_item, rect.grow(-inset), bg_color)
    if texture == null:
        return
    var size := texture.get_size()
    var edge := Vector2(corner, corner)
    var frame := rect.grow(outset)
    RenderingServer.canvas_item_add_nine_patch(to_canvas_item, frame, Rect2(Vector2.ZERO, size), texture.get_rid(), edge, edge, RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, false, border_color)
    if crest:
        var top := Vector2(roundf(frame.get_center().x), frame.position.y + 1)
        var outer := PackedVector2Array([top + Vector2(0, -5), top + Vector2(6, 1), top + Vector2(0, 7), top + Vector2(-6, 1)])
        var inner := PackedVector2Array([top + Vector2(0, -2), top + Vector2(3, 1), top + Vector2(0, 4), top + Vector2(-3, 1)])
        RenderingServer.canvas_item_add_polygon(to_canvas_item, outer, PackedColorArray([border_color]))
        RenderingServer.canvas_item_add_polygon(to_canvas_item, inner, PackedColorArray([bg_color.lightened(0.15)]))

func _get_draw_rect(rect: Rect2) -> Rect2:
    return rect.grow(outset + 8.0)
