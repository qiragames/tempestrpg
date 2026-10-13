extends Node2D
## A fixed first camp: shared stock and finite deposits, transacted only on the host.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const SITE := Vector2(350, 350)
const HUT_SITE := Vector2(380, 390)
## Near deposits feed allied workers; outlying ones reward players who explore past the Gnashers.
## Reference (seed 0) table. Each world's actual table comes from its seed (WorldLayout) as `sites`;
## the IDs, resources and near/outlying split are the same in every world.
const DEPOSITS := {
    "wood_1": {"position": Vector2(300, 350), "resource": "wood", "amount": 8, "outlying": false},
    "wood_2": {"position": Vector2(350, 300), "resource": "wood", "amount": 8, "outlying": false},
    "stone_1": {"position": Vector2(410, 350), "resource": "stone", "amount": 8, "outlying": false},
    "wood_3": {"position": Vector2(700, 440), "resource": "wood", "amount": 8, "outlying": true},
    "stone_2": {"position": Vector2(860, 200), "resource": "stone", "amount": 8, "outlying": true},
    "stone_3": {"position": Vector2(200, 540), "resource": "stone", "amount": 8, "outlying": true},
}
const HUT_COST := {"wood": 12, "stone": 6}
## Build order is the dictionary order. `key` is the boolean field in the saved camp state.
const STRUCTURES := {
    "hut_1": {"key": "hut", "name": "Goblin Hut", "site": HUT_SITE, "size": Vector2(36, 24), "cost": HUT_COST, "requires": ""},
    "storehouse_1": {"key": "storehouse", "name": "Storehouse", "site": Vector2(400, 300), "size": Vector2(30, 20), "cost": {"wood": 10, "stone": 6}, "requires": "hut_1"},
    "shrine_1": {"key": "shrine", "name": "Essence Shrine", "site": Vector2(300, 292), "size": Vector2(18, 18), "cost": {"stone": 8, "essence": 2}, "requires": "hut_1"},
    # 17g: south of the camp, outside the seeded deposit ring and inside the tree-free radius.
    "forge_1": {"key": "forge", "name": "Forge", "site": Vector2(350, 455), "size": Vector2(28, 20), "cost": {"stone": 4, "essence": 3}, "requires": "hut_1"},
}
const FORGE_REACH := 50.0
const SOURCES := preload("res://scripts/items/gear_sources.gd")
const RESOURCES := ["wood", "stone", "essence"]
const OFFER_ITEM := "gnasher_essence"
const SHRINE_RANGE := 60.0
## Extra regeneration near the shrine, as a multiple of the character's own rate.
const SHRINE_BONUS := 1.0
const STOREHOUSE_WORK_FACTOR := 0.5
## This world's deposits (positions/amounts depend on the seed).
var sites: Dictionary = DEPOSITS
var state: Dictionary = initial_state()
var _shapes: Dictionary = {}

static func initial_state(table: Dictionary = DEPOSITS) -> Dictionary:
    var deposits: Dictionary = {}
    for id in table:
        deposits[id] = table[id].amount
    return {"id": "camp_1", "founded": false, "founder": "", "wood": 0, "stone": 0, "essence": 0, "essence_offered": 0, "hut": false, "storehouse": false, "shrine": false, "forge": false, "deposits": deposits}

static func _whole(value: Variant, high: float = 1000000) -> bool:
    return (value is float or value is int) and value >= 0 and value <= high and value == floor(value)

static func valid_state(value: Variant, players: Dictionary, table: Dictionary = DEPOSITS) -> bool:
    if not value is Dictionary or value.size() != 12 or value.get("id") != "camp_1" or not value.get("founded") is bool or not value.get("founder") is String:
        return false
    for id in STRUCTURES:
        if not value.get(STRUCTURES[id].key) is bool:
            return false
    if value.founded:
        if not players.has(value.founder):
            return false
    elif not value.founder.is_empty() or value.hut or value.storehouse or value.shrine or value.forge:
        return false
    for id in STRUCTURES:
        var requires: String = STRUCTURES[id].requires
        if value[STRUCTURES[id].key] and not requires.is_empty() and not value[STRUCTURES[requires].key]:
            return false
    if not value.get("deposits") is Dictionary or value.deposits.size() != table.size():
        return false
    for id in table:
        var remaining: Variant = value.deposits.get(id)
        if not remaining is float and not remaining is int:
            return false
        if remaining != 0 and remaining != table[id].amount:
            return false
    if not _whole(value.get("essence_offered")) or (not value.founded and value.essence_offered != 0):
        return false
    for resource in RESOURCES:
        var stock: Variant = value.get(resource)
        if not stock is float and not stock is int:
            return false
        var income: int = int(value.essence_offered) if resource == "essence" else 0
        for id in table:
            if table[id].resource == resource:
                income += table[id].amount - int(value.deposits[id])
        for id in STRUCTURES:
            if value[STRUCTURES[id].key]:
                income -= STRUCTURES[id].cost.get(resource, 0)
        # Prevent edited/corrupt saves from duplicating finite resources.
        if stock != income or stock < 0:
            return false
    return true

func _ready() -> void:
    for id in STRUCTURES:
        var body := StaticBody2D.new()
        body.position = STRUCTURES[id].site
        var collider := CollisionShape2D.new()
        var shape := RectangleShape2D.new()
        shape.size = STRUCTURES[id].size
        collider.shape = shape
        collider.disabled = not state[STRUCTURES[id].key]
        body.add_child(collider)
        add_child(body)
        _shapes[id] = collider

## Switch to this world's deposit table (from its seed). Restore or reset `state` afterwards.
func set_sites(table: Dictionary) -> void:
    sites = table
    queue_redraw()

func restore(value: Dictionary) -> void:
    state = value.duplicate(true)
    for id in STRUCTURES:
        _shapes[id].set_deferred("disabled", not state[STRUCTURES[id].key])
    queue_redraw()

func built(id: String) -> bool:
    return STRUCTURES.has(id) and state[STRUCTURES[id].key]

func level() -> int:
    if not state.founded:
        return 0
    var total := 1
    for id in STRUCTURES:
        total += 1 if built(id) else 0
    return total

func work_factor() -> float:
    return STOREHOUSE_WORK_FACTOR if state.storehouse else 1.0

static func cost_text(id: String) -> String:
    var parts: Array = []
    for resource in RESOURCES:
        if STRUCTURES[id].cost.has(resource):
            parts.append("%d %s" % [STRUCTURES[id].cost[resource], resource])
    return " + ".join(parts)

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
    for id in sites:
        var current: float = actor.global_position.distance_to(sites[id].position)
        if state.deposits[id] > 0 and current < distance and can_reach(actor, sites[id].position, 36):
            closest = id
            distance = current
    return closest

func affordable(id: String) -> bool:
    if not STRUCTURES.has(id) or not state.founded or built(id):
        return false
    var requires: String = STRUCTURES[id].requires
    if not requires.is_empty() and not built(requires):
        return false
    for resource in STRUCTURES[id].cost:
        if state[resource] < STRUCTURES[id].cost[resource]:
            return false
    return true

## First structure in build order that is unlocked and funded; footprint is checked at completion.
func next_buildable() -> String:
    for id in STRUCTURES:
        if affordable(id):
            return id
    return ""

func can_build(actor: Node2D, id: String = "hut_1") -> bool:
    return can_reach(actor, SITE, 55) and build_ready(id)

func build_ready(id: String = "hut_1") -> bool:
    if not affordable(id):
        return false
    # Placement cannot trap a character or citizen. Dead players still respawn elsewhere.
    var footprint := Rect2(STRUCTURES[id].site - STRUCTURES[id].size / 2 - Vector2(6, 8), STRUCTURES[id].size + Vector2(12, 16))
    for node in get_parent().get_children():
        if (node.is_in_group("player") or node.is_in_group("allies") or node.is_in_group("enemies")) and footprint.has_point(node.position):
            if not node.is_in_group("enemies") or node.get_node("Health").current > 0:
                return false
    return true

func can_offer(actor: Node2D) -> bool:
    return state.founded and can_reach(actor, SITE, 55) and actor.get_node("Inventory").entries().any(func(entry): return String(entry.id) == OFFER_ITEM)

func transact(actor: Node2D, operation: String, id: String) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    var message := ""
    match operation:
        "found":
            if id != state.id or not can_found(actor):
                return false
            state.founded = true
            state.founder = actor.character_id
            message = "Camp founded."
        "gather":
            if not sites.has(id) or state.deposits[id] <= 0 or not can_reach(actor, sites[id].position, 36):
                return false
            harvest(id)
            message = "Materials added to shared camp stock."
        "build":
            if not STRUCTURES.has(id) or not can_build(actor, id):
                return false
            complete(id)
            message = "%s built. Shared materials consumed." % STRUCTURES[id].name
        "craft":
            # Forge recipes turn absorbed materials from the crafter's bag into a random item.
            if not SOURCES.RECIPES.has(id) or not state.forge or not can_reach(actor, STRUCTURES.forge_1.site, FORGE_REACH):
                return false
            var bag = actor.get_node("Inventory")
            var have := {}
            for entry in bag.entries():
                have[String(entry.id)] = entry.count
            for material in SOURCES.RECIPES[id].materials:
                if have.get(material, 0) < SOURCES.RECIPES[id].materials[material]:
                    get_node("/root/GameSession").notify_character(actor.character_id, "The forge needs %s." % SOURCES.recipe_text(id))
                    return false
            if actor.gear.items.size() >= actor.GEAR.MAX_ITEMS:
                get_node("/root/GameSession").notify_character(actor.character_id, "Gear bag full.")
                return false
            for material in SOURCES.RECIPES[id].materials:
                for count in range(SOURCES.RECIPES[id].materials[material]):
                    bag.discard(StringName(material))
            var item: Dictionary = SOURCES.roll_forge(id, get_parent().loot_rng)
            actor.add_item(item)
            message = "Forged: %s." % actor.GEAR.display_name(item)
        "offer":
            # Discard and credit together on the host so an essence is never lost or counted twice.
            if id != OFFER_ITEM or not can_offer(actor) or not actor.get_node("Inventory").discard(StringName(OFFER_ITEM)):
                return false
            state.essence += 1
            state.essence_offered += 1
            message = "Gnasher Essence offered to the camp."
        _:
            return false
    queue_redraw()
    var session := get_node("/root/GameSession")
    session.notify_character(actor.character_id, message)
    session.queue_save()
    return true

func harvest(id: String) -> bool:
    if not AUTHORITY.can_mutate(self) or not sites.has(id) or state.deposits[id] <= 0:
        return false
    state[sites[id].resource] += state.deposits[id]
    state.deposits[id] = 0
    queue_redraw()
    get_node("/root/GameSession").queue_save()
    return true

func complete(id: String) -> bool:
    if not AUTHORITY.can_mutate(self) or not build_ready(id):
        return false
    for resource in STRUCTURES[id].cost:
        state[resource] -= STRUCTURES[id].cost[resource]
    state[STRUCTURES[id].key] = true
    _shapes[id].set_deferred("disabled", false)
    queue_redraw()
    get_node("/root/GameSession").queue_save()
    return true

func complete_hut() -> bool:
    return complete("hut_1")

func _physics_process(delta: float) -> void:
    if not state.shrine or not AUTHORITY.can_mutate(self):
        return
    # Resting at the shrine doubles recovery once the character's normal regeneration delay has passed.
    for actor in get_tree().get_nodes_in_group("player"):
        var pool = actor.get_node("Magicules")
        if actor.get_node("Health").current > 0 and pool.enabled and pool._delay_left <= 0 and actor.global_position.distance_to(STRUCTURES.shrine_1.site) <= SHRINE_RANGE:
            pool.restore(pool.regeneration_per_second * SHRINE_BONUS * delta)

func _draw() -> void:
    draw_arc(SITE, 21, 0, TAU, 20, Color("e1bf79") if state.founded else Color("a1a99b"), 2)
    if state.founded:
        draw_rect(Rect2(SITE - Vector2(11, 3), Vector2(22, 6)), Color("75523a"))
        draw_colored_polygon(PackedVector2Array([SITE+Vector2(-7, 0), SITE+Vector2(0, -17), SITE+Vector2(7, 0)]), Color("eba65c"))
    else:
        draw_line(SITE+Vector2(0, 7), SITE+Vector2(0, -21), Color("b6a378"), 2)
        draw_rect(Rect2(SITE+Vector2(1, -21), Vector2(14, 9)), Color("8da69d"))
    for id in sites:
        var point: Vector2 = sites[id].position
        if state.deposits[id] == 0:
            draw_rect(Rect2(point-Vector2(4, 2), Vector2(8, 4)), Color("514c3b"))
        elif sites[id].resource == "wood":
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
    if state.storehouse:
        var store: Vector2 = STRUCTURES.storehouse_1.site
        draw_rect(Rect2(store-Vector2(15, 10), Vector2(30, 20)), Color("5f4a35"))
        draw_rect(Rect2(store-Vector2(17, 13), Vector2(34, 5)), Color("8c7552"))
        for x in [-10, -2, 6]:
            draw_rect(Rect2(store+Vector2(x, -4), Vector2(5, 12)), Color("3e3024"))
    if state.shrine:
        var shrine: Vector2 = STRUCTURES.shrine_1.site
        draw_arc(shrine, SHRINE_RANGE, 0, TAU, 32, Color(0.44, 0.89, 0.83, 0.25), 1)
        draw_rect(Rect2(shrine-Vector2(9, 9), Vector2(18, 18)), Color("6f7a7e"))
        draw_rect(Rect2(shrine-Vector2(5, 15), Vector2(10, 10)), Color("8e9b9f"))
        draw_circle(shrine-Vector2(0, 10), 3, Color("71e4d4"))
    if state.get("forge", false):
        var forge: Vector2 = STRUCTURES.forge_1.site
        draw_rect(Rect2(forge - Vector2(14, 10), Vector2(28, 20)), Color("4b4a4f"))
        draw_rect(Rect2(forge - Vector2(10, 14), Vector2(8, 6)), Color("6c6a70"))
        draw_rect(Rect2(forge + Vector2(-4, 0), Vector2(8, 6)), Color("f08a3c"))
        draw_rect(Rect2(forge + Vector2(-2, 2), Vector2(4, 3)), Color("ffd27a"))
