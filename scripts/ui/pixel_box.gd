extends StyleBox
## Pixel frame (M13 UI overhaul, user choice 2026-10-18): a nine-patch from the Dogobongocat UI
## pack (CC0, assets/game/ui/pixel/) — navy panels, parchment, slots, plates — drawn at whole
## pixels. `tint` colours the piece (alpha = transparency); `accent` (e.g. an item's rarity) is
## a two-pixel strip under the top edge.
@export var texture: Texture2D
## Size of the corners in the source piece (they never stretch).
@export var margin := 5
@export var tint := Color.WHITE
@export var accent := Color(0, 0, 0, 0)

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
    if texture == null:
        return
    var frame := Rect2(rect.position.round(), rect.size.round())
    var edge := Vector2(margin, margin)
    RenderingServer.canvas_item_add_nine_patch(to_canvas_item, frame, Rect2(Vector2.ZERO, texture.get_size()), texture.get_rid(), edge, edge, RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, tint)
    if accent.a > 0.0 and frame.size.x > margin * 2 + 4:
        RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(frame.position + Vector2(margin, 2), Vector2(frame.size.x - margin * 2, 2)), accent)
