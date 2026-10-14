extends Node
const AUTHORITY := preload("res://scripts/network/authority.gd")
## Shared health and immunity rules for actors; no combat logic in the HUD.

signal changed(current: int, maximum: int)
signal defeated
## Host: a hit landed for `amount` (after armor) from `source` (24a damage credit).
signal damaged(amount: int, source: Node)

@export var maximum: int = 100
@export var immunity_seconds: float = 0.65
var current: int
var immunity_left: float = 0.0
## Gradual healing (absorbed vitality): HP per second and seconds left. Host-only, saved.
const REGEN_SECONDS := 10.0
var regen_rate: float = 0.0
var regen_left: float = 0.0
var _regen_carry: float = 0.0

## Who landed the latest hit (host only, never saved).
var last_hit_by: Node
## Flat reduction per hit from equipped gear (derived, never saved). A hit always deals at least 1.
var armor: int = 0
func _ready() -> void:
    current = maximum

func _process(delta: float) -> void:
    if not AUTHORITY.can_mutate(self):
        return
    immunity_left = maxf(0.0, immunity_left - delta)
    if regen_left <= 0.0:
        return
    if current <= 0:
        clear_regen()
        return
    var step := minf(delta, regen_left)
    regen_left -= step
    _regen_carry += regen_rate * step
    # Frame-sized additions can leave an integer heal a few ulps short.
    var whole := int(floor(_regen_carry + 0.000000001))
    if whole > 0:
        _regen_carry = maxf(0.0, _regen_carry - whole)
        current = mini(maximum, current + whole)
        changed.emit(current, maximum)
    if regen_left <= 0.0:
        clear_regen()

## Heal `total` HP over REGEN_SECONDS. A new heal replaces the running one only if it restores more.
func start_regen(total: float) -> bool:
    if not AUTHORITY.can_mutate(self) or total <= 0.0 or current <= 0:
        return false
    if total <= regen_rate * regen_left:
        return false
    regen_rate = total / REGEN_SECONDS
    regen_left = REGEN_SECONDS
    return true

func clear_regen() -> void:
    regen_rate = 0.0
    regen_left = 0.0
    _regen_carry = 0.0

## Instant host-side healing (e.g. a Demon's drain), capped at maximum.
func heal(amount: int) -> void:
    if amount <= 0 or current <= 0 or not AUTHORITY.can_mutate(self):
        return
    current = mini(maximum, current + amount)
    changed.emit(current, maximum)

## `source` is the attacker (a character or creature); the last one to land a hit gets defeat credit.
## `over_time` (damage over time from skills, 24b) ignores immunity and does not start it.
func take_damage(amount: int, source: Node = null, over_time: bool = false) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    if amount <= 0 or current <= 0 or (immunity_left > 0.0 and not over_time):
        return false
    last_hit_by = source
    var dealt: int = mini(current, maxi(1, amount - armor))
    current = maxi(0, current - maxi(1, amount - armor))
    if not over_time:
        immunity_left = immunity_seconds
    damaged.emit(dealt, source)
    changed.emit(current, maximum)
    if current == 0:
        defeated.emit()
    elif is_instance_valid(source) and get_parent().has_method("on_damaged_by"):
        get_parent().on_damaged_by(source)
    return true
