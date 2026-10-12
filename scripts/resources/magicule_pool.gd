extends Node
const AUTHORITY := preload("res://scripts/network/authority.gd")
## Shared spending/recovery contract for attacks, future skills, and naming.

signal changed(current: float, maximum: float)
signal depleted
signal spend_rejected(cost: float)

@export_range(1.0, 100000.0) var maximum: float = 100.0
@export_range(0.0, 1000.0) var regeneration_per_second: float = 6.0
@export_range(0.0, 60.0) var regeneration_delay: float = 1.5
var enabled: bool = true
var _current: float
var _delay_left: float = 0.0
var current: float:
    get:
        return _current

func _ready() -> void:
    _current = maximum

func try_spend(cost: float) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    if not enabled or not is_finite(cost) or cost <= 0.0:
        return false
    if cost > _current:
        spend_rejected.emit(cost)
        return false
    _current = maxf(0.0, _current - cost)
    _delay_left = regeneration_delay
    changed.emit(_current, maximum)
    if is_zero_approx(_current):
        depleted.emit()
    return true

func restore(amount: float) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    if not enabled or not is_finite(amount) or amount <= 0.0 or _current >= maximum:
        return false
    _current = minf(maximum, _current + amount)
    changed.emit(_current, maximum)
    return true

func _process(delta: float) -> void:
    if not AUTHORITY.can_mutate(self):
        return
    if not enabled or _current >= maximum:
        return
    # Only time after the recovery delay contributes, even in a long frame.
    var waiting := minf(delta, _delay_left)
    _delay_left -= waiting
    var recovering := delta - waiting
    if recovering > 0.0 and regeneration_per_second > 0.0:
        restore(recovering * regeneration_per_second)
