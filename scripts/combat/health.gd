extends Node
## Shared health and immunity rules for actors; no combat logic in the HUD.

signal changed(current: int, maximum: int)
signal defeated

@export var maximum: int = 100
@export var immunity_seconds: float = 0.65
var current: int
var immunity_left: float = 0.0

func _ready() -> void:
    current = maximum

func _process(delta: float) -> void:
    immunity_left = maxf(0.0, immunity_left - delta)

func take_damage(amount: int) -> bool:
    if amount <= 0 or current <= 0 or immunity_left > 0.0:
        return false
    current = maxi(0, current - amount)
    immunity_left = immunity_seconds
    changed.emit(current, maximum)
    if current == 0:
        defeated.emit()
    return true
