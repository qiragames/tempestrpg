extends Control
## Round minimap (step 24a, user decision; the HUD reference's top-right map): the archipelago
## around the local character at two pixels per tile, clipped to a circle with a gold ring.
## Dots: you (cyan), other characters (white), allies (green), living creatures (red), your
## dropped item piles (gold), discovered leveling spots (violet ring) and chests you have not
## opened yet (yellow). Local presentation of state every peer already has.
const MAP := preload("res://scripts/world/world_map.gd")
const REGION := preload("res://scripts/world/region_content.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const RADIUS := 40.0
## Map pixels per tile on the minimap.
const ZOOM := 2.0
static var _texture: ImageTexture

var hud: CanvasLayer
var _view: Control

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "Minimap"
    size = Vector2(RADIUS * 2, RADIUS * 2)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    # The circle drawn here masks the map drawn by the child.
    clip_children = CanvasItem.CLIP_CHILDREN_ONLY
    _view = Control.new()
    _view.size = size
    _view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _view.draw.connect(_draw_view)
    add_child(_view)
    var ring := Control.new()
    ring.size = size
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ring.draw.connect(func():
        ring.draw_arc(size / 2, RADIUS - 1, 0, TAU, 48, UI.GOLD_DARK, 3.0)
        ring.draw_arc(size / 2, RADIUS - 1, 0, TAU, 48, UI.GOLD, 1.0)
        ring.draw_colored_polygon(PackedVector2Array([size / 2 + Vector2(0, -RADIUS - 3), size / 2 + Vector2(3, -RADIUS + 2), size / 2 + Vector2(-3, -RADIUS + 2)]), UI.GOLD_LIGHT)
    )
    # The ring sits outside the clip (drawn by a sibling above this node, see `ring_node`).
    ring.name = "Ring"
    set_meta("ring", ring)

static func texture() -> ImageTexture:
    # The detailed picture appears once the world has planned its props (cached there).
    _texture = preload("res://scripts/ui/world_map_panel.gd").full_texture()
    return _texture

func _draw() -> void:
    draw_circle(size / 2, RADIUS, Color(0.02, 0.03, 0.06))

func _process(_delta: float) -> void:
    if is_visible_in_tree():
        _view.queue_redraw()

## World position → minimap pixel, relative to the local character.
func to_minimap(world: Vector2, centre: Vector2) -> Vector2:
    return size / 2 + (world - centre) / MAP.TILE * ZOOM

func _dot(at: Vector2, color: Color, radius: float = 1.5) -> void:
    if at.distance_to(size / 2) <= RADIUS - 2:
        _view.draw_circle(at.round(), radius + 1.0, Color(0.02, 0.03, 0.06, 0.85))
        _view.draw_circle(at.round(), radius, color)

func _draw_view() -> void:
    var me: Node2D = hud.player
    if not is_instance_valid(me):
        return
    var centre: Vector2 = me.global_position
    var tile: Vector2 = (centre - MAP.ORIGIN) / MAP.TILE - Vector2(MAP.MIN)
    var span: float = size.x / ZOOM
    _view.draw_texture_rect_region(texture(), Rect2(Vector2.ZERO, size), Rect2(tile - Vector2(span, span) / 2.0, Vector2(span, span)))
    # The real trees, rocks and buildings around you, drawn small (user feedback).
    var terrain := preload("res://scripts/world/world_terrain.gd")
    var map_panel := preload("res://scripts/ui/world_map_panel.gd")
    var here: Vector2i = terrain.chunk_of(centre)
    var shrink := ZOOM / MAP.TILE
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            for index in terrain._chunks.get(here + Vector2i(dx, dy), []):
                var prop: Array = terrain.planned_props()[index]
                var spec: Array = terrain.PROPS.get(String(prop[0]), [])
                if spec.is_empty():
                    continue
                var at := to_minimap(prop[1], centre)
                if at.distance_to(size / 2) > RADIUS - 4:
                    continue
                var region: Rect2 = spec[1]
                _view.draw_texture_rect_region(map_panel.sheet(spec[0]), Rect2(at - Vector2(region.size.x / 2.0, region.size.y) * shrink, region.size * shrink), region)
    # The clearing's own seeded trees and rocks.
    var art := preload("res://scripts/visual/world_art.gd")
    for entry in [["tree", hud.get_parent().layout.get("trees", [])], ["rock", hud.get_parent().layout.get("rocks", [])]]:
        var spec: Array = art.PROPS[entry[0]]
        for spot in entry[1]:
            var at := to_minimap(spot.get_center() + Vector2(0, spot.size.y / 2.0) if spot is Rect2 else spot, centre)
            if at.distance_to(size / 2) <= RADIUS - 4:
                var region: Rect2 = spec[1]
                _view.draw_texture_rect_region(spec[0], Rect2(at - Vector2(region.size.x / 2.0, region.size.y * 0.75) * shrink, region.size * shrink), region)
    var world: Node = hud.get_parent()
    var known: Array = me.progression.get("spots", [])
    for spot in REGION.SPOTS:
        if spot[0] in known:
            var at := to_minimap(REGION.at(spot[2]), centre)
            if at.distance_to(size / 2) <= RADIUS - 3:
                _view.draw_arc(at, 3.0, 0, TAU, 12, Color("c48bff"), 1.0)
    var opened: Array = me.progression.get("chests", [])
    for chest in world.layout.get("chests", []):
        if not chest.id in opened:
            _dot(to_minimap(chest.position, centre), Color("f0d060"), 1.0)
    for node in world.get_children():
        if node.is_queued_for_deletion():
            continue
        if node.is_in_group("enemies") and node.get_node("Health").current > 0:
            _dot(to_minimap(node.global_position, centre), Color("e0503c"))
        elif node.is_in_group("allies"):
            _dot(to_minimap(node.global_position, centre), Color("7ee08a"))
        elif node.is_in_group("item_piles") and node.owner_id == me.character_id:
            # Your piles are always shown: beyond the edge they sit on the rim, pointing the way.
            var at := to_minimap(node.global_position, centre)
            if at.distance_to(size / 2) > RADIUS - 4:
                at = size / 2 + (at - size / 2).normalized() * (RADIUS - 4)
            _view.draw_rect(Rect2(at.round() - Vector2(4, 4), Vector2(8, 8)), Color(0.02, 0.03, 0.06, 0.9))
            _view.draw_line(at.round() + Vector2(-3, -3), at.round() + Vector2(3, 3), Color("f0a34a"), 2.0)
            _view.draw_line(at.round() + Vector2(-3, 3), at.round() + Vector2(3, -3), Color("f0a34a"), 2.0)
        elif node is CharacterBody2D and node.has_method("race") and node != me:
            # M4.6: party members in their own colour, pinned to the rim when far away.
            var party: Node = world.get("party")
            if party != null and party.same_party(me.character_id, node.character_id):
                var at := to_minimap(node.global_position, centre)
                if at.distance_to(size / 2) > RADIUS - 4:
                    at = size / 2 + (at - size / 2).normalized() * (RADIUS - 4)
                _view.draw_circle(at.round(), 3.0, Color(0.02, 0.03, 0.06, 0.9))
                _view.draw_circle(at.round(), 2.0, Color("ff8adf"))
            else:
                _dot(to_minimap(node.global_position, centre), Color.WHITE)
    _view.draw_circle(size / 2, 2.5, Color(0.02, 0.03, 0.06))
    _view.draw_circle(size / 2, 1.8, UI.CYAN)
