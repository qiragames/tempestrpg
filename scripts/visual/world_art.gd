extends RefCounted
## World tiles and props from the prepared sheets in assets/game/world (step 20).
## Presentation only: every collision shape, ID and saved position stays where the rules put it;
## art is placed around that geometry (foot of a prop = bottom of its collision footprint).
const TILE := 16
const FLOOR := preload("res://assets/game/world/terrain_floor.png")
const WATER := preload("res://assets/game/world/water.png")
const NATURE := preload("res://assets/game/world/nature.png")
const HOUSE := preload("res://assets/game/world/house.png")
const CAMP := preload("res://assets/game/world/camp.png")
const ANVIL := preload("res://assets/game/world/station_anvil.png")
const BONFIRE := preload("res://assets/game/world/station_bonfire.png")
const CHEST := preload("res://assets/game/ui/icons/chest_closed.png")

## Ground: plain grass and four tuft variants (one row of the light-grass floor set).
const GRASS := Rect2(0, 192, 16, 16)
const TUFTS: Array[Rect2] = [Rect2(16, 192, 16, 16), Rect2(32, 192, 16, 16), Rect2(48, 192, 16, 16), Rect2(64, 192, 16, 16)]
## Nine-slice origins (3x3 tiles: corners, edges, centre) on grass.
const DIRT_PATCH := Vector2(0, 112)
const POND_PATCH := Vector2(0, 96)

## Props: [sheet, region]. Each is drawn with its bottom-centre on the prop's foot.
const PROPS := {
    "tree": [NATURE, Rect2(48, 288, 48, 48)],
    "rock": [NATURE, Rect2(256, 128, 32, 32)],
    "hut": [HOUSE, Rect2(48, 128, 48, 32)],
    "storehouse": [HOUSE, Rect2(0, 120, 48, 40)],
    "shrine": [HOUSE, Rect2(48, 240, 32, 32)],
    "forge": [ANVIL, Rect2(0, 34, 60, 44)],
    "trial_stone": [HOUSE, Rect2(0, 240, 16, 32)],
    "campfire": [BONFIRE, Rect2(0, 16, 32, 32)],
    "camp_post": [CAMP, Rect2(96, 80, 16, 32)],
    "logs": [CAMP, Rect2(0, 0, 32, 16)],
    "stones": [NATURE, Rect2(272, 272, 48, 16)],
    "pebbles": [NATURE, Rect2(240, 288, 32, 16)],
    "chest": [CHEST, Rect2(0, 0, 16, 16)],
    "chest_open": [CHEST, Rect2(16, 0, 16, 16)],
}

static func atlas(id: String) -> AtlasTexture:
    var texture := AtlasTexture.new()
    texture.atlas = PROPS[id][0]
    texture.region = PROPS[id][1]
    return texture

## A prop sprite whose node position is its foot, for y-sorted depth against characters.
static func prop(id: String, foot: Vector2) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = id.capitalize().replace(" ", "")
    sprite.texture = atlas(id)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = foot
    sprite.offset = Vector2(0, -PROPS[id][1].size.y / 2.0)
    return sprite

## Draw a prop flat (no depth sorting), bottom-centre at `foot`.
static func draw_prop(canvas: CanvasItem, id: String, foot: Vector2, tint: Color = Color.WHITE) -> void:
    var region: Rect2 = PROPS[id][1]
    canvas.draw_texture_rect_region(PROPS[id][0], Rect2((foot - Vector2(region.size.x / 2.0, region.size.y)).round(), region.size), region, tint)

## Grass over the whole area, with a deterministic sprinkle of tufts.
static func draw_grass(canvas: CanvasItem, area: Rect2) -> void:
    for y in range(int(area.position.y), int(area.end.y), TILE):
        for x in range(int(area.position.x), int(area.end.x), TILE):
            var pick: int = (x * 7 + y * 13 + (x / TILE) * (y / TILE)) % 23
            var region: Rect2 = TUFTS[pick % TUFTS.size()] if pick < 5 else GRASS
            canvas.draw_texture_rect_region(FLOOR, Rect2(x, y, TILE, TILE), region)

## Nine-slice patch filling `rect` (any size >= 32x32). Edge and centre tiles repeat; the last one
## in a row/column is pulled back so it ends exactly on the rect edge. `open_top` continues the
## sides to the top edge instead of drawing a border (for road junctions).
static func draw_patch(canvas: CanvasItem, sheet: Texture2D, origin: Vector2, rect: Rect2, open_top: bool = false) -> void:
    var xs := _steps(rect.position.x, rect.end.x)
    var ys := _steps(rect.position.y, rect.end.y)
    for row in range(ys.size()):
        var tile_row: int = 0 if row == 0 else (2 if row == ys.size() - 1 else 1)
        if open_top and tile_row == 0:
            tile_row = 1
        for column in range(xs.size()):
            var tile_column: int = 0 if column == 0 else (2 if column == xs.size() - 1 else 1)
            var source := Rect2(origin + Vector2(tile_column, tile_row) * TILE, Vector2(TILE, TILE))
            canvas.draw_texture_rect_region(sheet, Rect2(xs[column], ys[row], TILE, TILE), source)

static func _steps(from: float, to: float) -> Array:
    var steps: Array = []
    var at := from
    while at < to - TILE:
        steps.append(at)
        at += TILE
    steps.append(to - TILE)
    return steps
