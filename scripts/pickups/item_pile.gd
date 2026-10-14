extends Area2D
## A defeated character's bag (step 24a, user decision): materials and unequipped gear lie here
## until collected. Never expires; every defeat adds its own pile. The owner may take it at once,
## anyone else after Claim.CLAIM_SECONDS of world time. Walking over it takes what fits (bag
## capacity, gear limit); the rest stays. Host-side; saved with the world; marked on the world
## map and minimap.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const CLAIM := preload("res://scripts/pickups/claim.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const CATALOGUE := preload("res://scripts/skills/skill_catalogue.gd")
const MAX_PILES := 64
const REACH := 24.0

var entity_id: String = ""
var owner_id: String = ""
var claim_until: float = 0.0
## Material id → count, and gear item dictionaries.
var materials: Dictionary = {}
var items: Array = []

func _init() -> void:
    collision_layer = 0
    collision_mask = 2
    monitorable = false
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 12.0
    shape.shape = circle
    add_child(shape)

func _ready() -> void:
    if entity_id.is_empty():
        entity_id = "pile_" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_to_group("item_piles")
    if is_empty():
        queue_free()

func is_empty() -> bool:
    return materials.is_empty() and items.is_empty()

func _physics_process(_delta: float) -> void:
    if not AUTHORITY.can_mutate(self):
        return
    for body in get_overlapping_bodies():
        if not body.is_in_group("player") or not body.has_method("add_item") or body.get_node("Health").current <= 0:
            continue
        if not CLAIM.can_take(get_parent(), owner_id, claim_until, body.character_id):
            continue
        # The overlap list lags one physics step behind teleports (a respawn far away), so the
        # real distance decides.
        if body.global_position.distance_to(global_position) > REACH:
            continue
        if _give(body):
            return

## Move what fits into the character's bag and gear; true when the pile is gone.
func _give(body: Node) -> bool:
    var bag: Node = body.get_node("Inventory")
    var taken := 0
    for id in materials.keys():
        var added: int = bag.add_material(id, int(materials[id]))
        taken += added
        materials[id] = int(materials[id]) - added
        if materials[id] <= 0:
            materials.erase(id)
    for item in items.duplicate():
        if body.add_item(item):
            items.erase(item)
            taken += 1
    var session := get_node("/root/GameSession")
    if taken > 0:
        session.notify_character(body.character_id, "Recovered %d thing%s from %s." % [taken, "" if taken == 1 else "s", "your pile" if body.character_id == owner_id else "a pile"])
        session.queue_save()
        queue_redraw()
    if is_empty():
        set_physics_process(false)
        queue_free()
        return true
    return false

func _draw() -> void:
    draw_circle(Vector2.ZERO, 10.0, Color(0.95, 0.75, 0.3, 0.22))
    draw_rect(Rect2(-6, -3, 12, 7), Color("8b5a2b"))
    draw_rect(Rect2(-4, -6, 8, 4), Color("c8954f"))
    draw_rect(Rect2(-1, -5, 2, 2), Color("f0d38c"))

## Saved / replicated form.
func capture() -> Dictionary:
    return {"id": entity_id, "position": [position.x, position.y], "owner": owner_id, "claim_until": claim_until, "materials": materials.duplicate(), "items": items.duplicate(true)}

static func valid(entry: Variant) -> bool:
    if not entry is Dictionary or entry.size() != 6 or not entry.get("id") is String or not String(entry.id).begins_with("pile_") or String(entry.id).length() > 64:
        return false
    if not entry.get("owner") is String or not (entry.get("claim_until") is float or entry.get("claim_until") is int) or not is_finite(float(entry.claim_until)) or float(entry.claim_until) < 0.0:
        return false
    if not entry.get("materials") is Dictionary or not entry.get("items") is Array or entry.items.size() > GEAR.MAX_ITEMS or (entry.materials.is_empty() and entry.items.is_empty()):
        return false
    for id in entry.materials:
        var count: Variant = entry.materials[id]
        if not CATALOGUE.MATERIALS.has(String(id)) or not (count is int or count is float) or count != floor(count) or count < 1 or count > 1000:
            return false
    for item in entry.items:
        if not GEAR.valid_item(item):
            return false
    return entry.get("position") is Array and entry.position.size() == 2
