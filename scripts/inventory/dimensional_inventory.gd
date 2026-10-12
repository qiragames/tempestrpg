extends Node
const AUTHORITY := preload("res://scripts/network/authority.gd")
## Session-local analyzed materials, with bounded stacks and stable item IDs.

signal changed
@export var capacity: int = 20
var _entries: Dictionary = {}

func total_units() -> int:
    var total: int = 0
    for entry in _entries.values():
        total += entry.count
    return total

func can_store() -> bool:
    return total_units() < capacity

func add_specimen(specimen: Resource) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    if specimen == null or specimen.material_id == &"" or not can_store():
        return false
    var id: StringName = specimen.material_id
    if not _entries.has(id):
        _entries[id] = {"id": id, "name": specimen.material_name, "description": specimen.material_description, "category": "Materials", "count": 0}
    _entries[id].count += 1
    changed.emit()
    return true

func entries() -> Array:
    # UI callers receive a copy so they cannot silently mutate inventory state.
    return _entries.values().duplicate(true)

func discard(id: StringName, quantity: int = 1) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    if quantity <= 0 or not _entries.has(id) or quantity > _entries[id].count:
        return false
    _entries[id].count -= quantity
    if _entries[id].count == 0:
        _entries.erase(id)
    changed.emit()
    return true
