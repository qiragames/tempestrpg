extends Node
const AUTHORITY := preload("res://scripts/network/authority.gd")
## Session-local analyzed materials, with bounded stacks and stable item IDs.

signal changed
## M6a: 100 units (gathering fills the bag quickly); older saves are raised by the v32 migration.
@export var capacity: int = 100
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

## Add up to `count` of a known material (24a: recovering a pile); returns how many fitted.
func add_material(id: String, count: int) -> int:
    if not AUTHORITY.can_mutate(self) or count <= 0:
        return 0
    var catalogue := preload("res://scripts/skills/skill_catalogue.gd")
    var trade := preload("res://scripts/trade/trade_catalogue.gd")
    if not catalogue.MATERIALS.has(id) and not trade.is_good(id):
        return 0
    var added: int = mini(count, capacity - total_units())
    if added <= 0:
        return 0
    var key := StringName(id)
    if not _entries.has(key):
        if trade.is_good(id):
            # Consumables and scrolls (M4.5c).
            var info: Array = trade.good_info(id)
            _entries[key] = {"id": key, "name": info[0], "description": info[2], "category": info[1], "count": 0}
        else:
            var specimen: Resource = load(catalogue.SPECIMENS[catalogue.MATERIALS[id]])
            _entries[key] = {"id": key, "name": specimen.material_name, "description": specimen.material_description, "category": "Materials", "count": 0}
    _entries[key].count += added
    changed.emit()
    return added

## Empty the bag (24a: a defeated character drops it); returns material id → count.
func take_all() -> Dictionary:
    var counts := {}
    if not AUTHORITY.can_mutate(self):
        return counts
    for id in _entries:
        counts[String(id)] = int(_entries[id].count)
    _entries.clear()
    changed.emit()
    return counts

## Restore a saved stack (materials and goods alike).
func restore_stack(id: String, count: int) -> void:
    var trade := preload("res://scripts/trade/trade_catalogue.gd")
    var catalogue := preload("res://scripts/skills/skill_catalogue.gd")
    if trade.is_good(id):
        var info: Array = trade.good_info(id)
        _entries[StringName(id)] = {"id": StringName(id), "name": info[0], "description": info[2], "category": info[1], "count": count}
    elif catalogue.MATERIALS.has(id):
        var specimen: Resource = load(catalogue.SPECIMENS[catalogue.MATERIALS[id]])
        _entries[StringName(id)] = {"id": StringName(id), "name": specimen.material_name, "description": specimen.material_description, "category": "Materials", "count": count}

func count_of(id: String) -> int:
    return int(_entries.get(StringName(id), {}).get("count", 0))

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
