extends Panel
## SVE feedback 2026-10-22 (the bag should look like the equipment window): one cell of the bag's
## icon grid — the good's icon, its count in the corner, the full name and description on hover;
## a click selects it, a double click uses it.
const UI := preload("res://scripts/ui/ui_style.gd")

signal picked(id: StringName)
signal used(id: StringName)

var item_id: StringName = &""
var icon: Texture2D
var count := 0
var selected := false

func _ready() -> void:
    custom_minimum_size = Vector2(32, 32)
    mouse_filter = Control.MOUSE_FILTER_STOP
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_theme_stylebox_override("panel", UI.round_slot("slot"))

func set_entry(entry: Dictionary, is_selected: bool) -> void:
    item_id = StringName(entry.get("id", ""))
    icon = UI.icon(String(item_id)) if item_id != &"" else null
    count = int(entry.get("count", 0))
    selected = is_selected
    tooltip_text = "%s ×%d\n%s\n%s" % [entry.name, count, entry.get("category", ""), entry.get("description", "")] if item_id != &"" else ""
    queue_redraw()

func _draw() -> void:
    if item_id == &"":
        return
    if icon != null:
        draw_texture_rect(icon, Rect2(Vector2(3, 3), size - Vector2(6, 6)), false)
    else:
        draw_string(get_theme_default_font(), Vector2(0, size.y / 2.0 + 3), String(item_id).left(4), HORIZONTAL_ALIGNMENT_CENTER, size.x, 7, UI.TEXT)
    if count > 1:
        var font := get_theme_default_font()
        var text := str(count) if count < 1000 else "999+"
        var at := Vector2(size.x - 2 - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x, size.y - 2)
        draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0, 0, 0, 0.9))
        draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UI.GOLD_LIGHT)
    if selected:
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), UI.CYAN, false, 1.0)

func _gui_input(event: InputEvent) -> void:
    if item_id == &"" or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
        return
    if event.double_click:
        used.emit(item_id)
    else:
        picked.emit(item_id)
    accept_event()
