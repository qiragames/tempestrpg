extends Node2D
## A fixed first camp: shared stock and finite deposits, transacted only on the host.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const SITE := Vector2(350, 350)
const HUT_SITE := Vector2(380, 390)
const DEPOSITS := {
    "wood_1": {"position": Vector2(300, 350), "resource": "wood", "amount": 8},
    "wood_2": {"position": Vector2(350, 300), "resource": "wood", "amount": 8},
    "stone_1": {"position": Vector2(410, 350), "resource": "stone", "amount": 8},
}
const HUT_COST := {"wood": 12, "stone": 6}
var state: Dictionary = initial_state()
var _hut_shape: CollisionShape2D

static func initial_state() -> Dictionary:
    return {"id": "camp_1", "founded": false, "founder": "", "wood": 0, "stone": 0, "hut": false, "deposits": {"wood_1": 8, "wood_2": 8, "stone_1": 8}}

static func valid_state(value: Variant, players: Dictionary) -> bool:
    if not value is Dictionary or value.size() != 7 or value.get("id") != "camp_1" or not value.get("founded") is bool or not value.get("hut") is bool or not value.get("founder") is String:
        return false
    if value.founded:
        if not players.has(value.founder):
            return false
    elif not value.founder.is_empty() or value.hut:
        return false
    if not value.get("deposits") is Dictionary or value.deposits.size() != DEPOSITS.size():
        return false
    for id in DEPOSITS:
        var remaining: Variant = value.deposits.get(id)
        if not remaining is float and not remaining is int:
            return false
        if remaining != 0 and remaining != DEPOSITS[id].amount:
            return false
    for resource in ["wood", "stone"]:
        var stock: Variant = value.get(resource)
        if not stock is float and not stock is int:
            return false
        var harvested: int = 0
        for id in DEPOSITS:
            if DEPOSITS[id].resource == resource:
                harvested += DEPOSITS[id].amount - int(value.deposits[id])
        # Prevent edited/corrupt saves from duplicating finite resources.
        if stock != harvested - (HUT_COST[resource] if value.hut else 0) or stock < 0:
            return false
    return true

func _ready() -> void:
    var body := StaticBody2D.new()
    body.position = HUT_SITE
    _hut_shape = CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(36, 24)
    _hut_shape.shape = shape
    _hut_shape.disabled = not state.hut
    body.add_child(_hut_shape)
    add_child(body)

func restore(value: Dictionary) -> void:
    state = value.duplicate(true)
    _hut_shape.set_deferred("disabled", not state.hut)
    queue_redraw()

func can_reach(actor: Node2D, target: Vector2, distance: float) -> bool:
    if actor.get_node("Health").current <= 0 or actor.is_exhausted() or actor.global_position.distance_to(target) > distance:
        return false
    var ray := PhysicsRayQueryParameters2D.create(actor.global_position, target, 1)
    return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func can_found(actor: Node2D) -> bool:
    if state.founded or not can_reach(actor, SITE, 55):
        return false
    for ally in get_tree().get_nodes_in_group("allies"):
        if ally.owner_id == actor.character_id and ally.race == "Hobgoblin" and not ally.display_name.is_empty() and ally.global_position.distance_to(SITE) <= 80:
            return true
    return false

func nearest_deposit(actor: Node2D) -> String:
    var closest := ""
    var distance := 36.1
    for id in DEPOSITS:
        var current: float = actor.global_position.distance_to(DEPOSITS[id].position)
        if state.deposits[id] > 0 and current < distance and can_reach(actor, DEPOSITS[id].position, 36):
            closest = id
            distance = current
    return closest

func can_build(actor: Node2D) -> bool:
    return can_reach(actor, SITE, 55) and build_ready()

func build_ready() -> bool:
    if not state.founded or state.hut or state.wood < HUT_COST.wood or state.stone < HUT_COST.stone:
        return false
    # Placement cannot trap a character or citizen. Dead players still respawn elsewhere.
    for node in get_parent().get_children():
        if (node.is_in_group("player") or node.is_in_group("allies") or node.is_in_group("enemies")) and Rect2(HUT_SITE - Vector2(24, 20), Vector2(48, 40)).has_point(node.position):
            if not node.is_in_group("enemies") or node.get_node("Health").current > 0:
                return false
    return true

func transact(actor: Node2D, operation: String, id: String) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    match operation:
        "found":
            if id != state.id or not can_found(actor):
                return false
            state.founded = true
            state.founder = actor.character_id
        "gather":
            if not DEPOSITS.has(id) or state.deposits[id] <= 0 or not can_reach(actor, DEPOSITS[id].position, 36):
                return false
            harvest(id)
        "build":
            if id != "hut_1" or not can_build(actor):
                return false
            complete_hut()
        _:
            return false
    queue_redraw()
    var session := get_node("/root/GameSession")
    session.notify_character(actor.character_id, "Camp founded." if operation == "found" else "Goblin hut built. Shared materials consumed." if operation == "build" else "Materials added to shared camp stock.")
    session.queue_save()
    return true

func harvest(id: String) -> bool:
    if not AUTHORITY.can_mutate(self) or not DEPOSITS.has(id) or state.deposits[id] <= 0:
        return false
    state[DEPOSITS[id].resource] += state.deposits[id]
    state.deposits[id] = 0
    queue_redraw()
    get_node("/root/GameSession").queue_save()
    return true

func complete_hut() -> bool:
    if not AUTHORITY.can_mutate(self) or not build_ready():
        return false
    state.wood -= HUT_COST.wood
    state.stone -= HUT_COST.stone
    state.hut = true
    _hut_shape.set_deferred("disabled", false)
    queue_redraw()
    get_node("/root/GameSession").queue_save()
    return true

func _draw() -> void:
    draw_arc(SITE, 21, 0, TAU, 20, Color("e1bf79") if state.founded else Color("a1a99b"), 2)
    if state.founded:
        draw_rect(Rect2(SITE - Vector2(11, 3), Vector2(22, 6)), Color("75523a"))
        draw_colored_polygon(PackedVector2Array([SITE+Vector2(-7, 0), SITE+Vector2(0, -17), SITE+Vector2(7, 0)]), Color("eba65c"))
    else:
        draw_line(SITE+Vector2(0, 7), SITE+Vector2(0, -21), Color("b6a378"), 2)
        draw_rect(Rect2(SITE+Vector2(1, -21), Vector2(14, 9)), Color("8da69d"))
    for id in DEPOSITS:
        var point: Vector2 = DEPOSITS[id].position
        if state.deposits[id] == 0:
            draw_rect(Rect2(point-Vector2(4, 2), Vector2(8, 4)), Color("514c3b"))
        elif DEPOSITS[id].resource == "wood":
            for offset in [-4, 0, 4]:
                draw_rect(Rect2(point+Vector2(-9, offset-2), Vector2(18, 4)), Color("a48254"))
                draw_rect(Rect2(point+Vector2(-8, offset-1), Vector2(3, 2)), Color("d2b579"))
        else:
            draw_colored_polygon(PackedVector2Array([point+Vector2(-10, 5), point+Vector2(-7, -6), point+Vector2(5, -9), point+Vector2(12, 4)]), Color("8e9b9f"))
    if state.hut:
        draw_rect(Rect2(HUT_SITE-Vector2(18, 12), Vector2(36, 24)), Color("71543a"))
        draw_rect(Rect2(HUT_SITE+Vector2(-5, -2), Vector2(10, 14)), Color("292d2c"))
        draw_colored_polygon(PackedVector2Array([HUT_SITE+Vector2(-24, -10), HUT_SITE+Vector2(0, -34), HUT_SITE+Vector2(24, -10)]), Color("baa56a"))
        draw_line(HUT_SITE+Vector2(0, -32), HUT_SITE+Vector2(0, -11), Color("dec78b"), 2)
