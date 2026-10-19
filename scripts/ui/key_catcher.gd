extends Control
## Catches the next key press for the keys list (M11g) before anything else sees it.
## `on_key` (Callable(int) -> bool) returns true when it used the key.
var on_key: Callable

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and on_key.is_valid():
        var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
        if on_key.call(code):
            get_viewport().set_input_as_handled()
    # User request: mouse buttons can be bound too (the click that started waiting has passed).
    elif event is InputEventMouseButton and event.pressed and on_key.is_valid():
        if on_key.call(preload("res://scripts/ui/key_icons.gd").MOUSE_BASE + int(event.button_index)):
            get_viewport().set_input_as_handled()
