extends Control
## The little slime that marks the focused menu entry (title and pause references, step 22).
## It follows whichever of the given buttons has keyboard focus or the mouse.
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
var buttons: Array = []
var target: Button
var _sprite: AnimatedSprite2D

func _init(menu_buttons: Array = []) -> void:
    name = "MenuMarker"
    buttons = menu_buttons
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _sprite = AnimatedSprite2D.new()
    _sprite.sprite_frames = SPRITES.frames("slime")
    _sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _sprite.scale = Vector2(2, 2)
    add_child(_sprite)
    _sprite.play("walk_right")

func _process(_delta: float) -> void:
    var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
    var hovered: Control = get_viewport().gui_get_hovered_control() if is_inside_tree() else null
    var next: Button = null
    if hovered in buttons and not (hovered as Button).disabled:
        next = hovered
    elif focused in buttons:
        next = focused
    if next != null:
        target = next
    visible = target != null and target.is_visible_in_tree()
    if visible:
        global_position = target.global_position + Vector2(-14, target.size.y / 2.0)
