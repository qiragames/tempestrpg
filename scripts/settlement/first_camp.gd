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
    # M4.5b: deposits in the archipelago's regions (fixed in every world, appended after the
    # seeded ones; positions = RegionContent tiles). Thornwood, Cinder Crater, Mirror Lake, meadow.
    "wood_thornwood_1": {"position": Vector2(-1080, 8), "resource": "wood", "amount": 12, "outlying": true},
    "wood_thornwood_2": {"position": Vector2(-568, -280), "resource": "wood", "amount": 12, "outlying": true},
    "stone_crater_1": {"position": Vector2(1352, 1320), "resource": "stone", "amount": 12, "outlying": true},
    "stone_crater_2": {"position": Vector2(1768, 968), "resource": "stone", "amount": 12, "outlying": true},
    "stone_lakeshore_1": {"position": Vector2(1160, -120), "resource": "stone", "amount": 10, "outlying": true},
    "wood_meadow_1": {"position": Vector2(648, 1320), "resource": "wood", "amount": 10, "outlying": true},
}
## Deposit IDs placed by the world seed (the rest are fixed region deposits).
const SEEDED_DEPOSITS := ["wood_1", "wood_2", "stone_1", "wood_3", "stone_2", "stone_3"]
## 24a (user decision): an emptied region deposit refills completely after this many seconds.
## `refills` counts completed refills per deposit (so the stock check knows the extra income);
## `refill_left` holds the running timers. Clearing deposits stay finite.
const REFILL_SECONDS := 900.0
const HUT_COST := {"wood": 12, "stone": 6}
## Build order is the dictionary order. `key` is the boolean field in the saved camp state.
const STRUCTURES := {
    "hut_1": {"key": "hut", "name": "Goblin Hut", "site": HUT_SITE, "size": Vector2(36, 24), "cost": HUT_COST, "requires": ""},
    "storehouse_1": {"key": "storehouse", "name": "Storehouse", "site": Vector2(400, 300), "size": Vector2(30, 20), "cost": {"wood": 10, "stone": 6}, "requires": "hut_1"},
    "shrine_1": {"key": "shrine", "name": "Essence Shrine", "site": Vector2(300, 292), "size": Vector2(18, 18), "cost": {"stone": 8, "essence": 2}, "requires": "hut_1"},
    # 17g: south of the camp, outside the seeded deposit ring and inside the tree-free radius.
    "forge_1": {"key": "forge", "name": "Forge", "site": Vector2(350, 455), "size": Vector2(28, 20), "cost": {"stone": 4, "essence": 3}, "requires": "hut_1"},
    # M4.5c: places for staff hired with Zeni (a general trader, a gear smith).
    "stall_1": {"key": "stall", "name": "Market Stall", "site": Vector2(398, 452), "size": Vector2(28, 16), "cost": {"wood": 8, "stone": 4}, "requires": "hut_1"},
    "smithy_1": {"key": "smithy", "name": "Smithy", "site": Vector2(302, 452), "size": Vector2(36, 20), "cost": {"stone": 8, "wood": 4}, "requires": "forge_1"},
}
## Staff hired once with Zeni (M4.5c): role → [structure, cost, name].
const STAFF := {"trader": ["stall_1", 150, "general trader"], "smith": ["smithy_1", 250, "gear smith"]}
const HIRE_REACH := 60.0
const FORGE_REACH := 50.0
const SOURCES := preload("res://scripts/items/gear_sources.gd")
const RESOURCES := ["wood", "stone", "essence"]
const OFFER_ITEM := "gnasher_essence"
const SHRINE_RANGE := 60.0
## Extra regeneration near the shrine, as a multiple of the character's own rate.
const SHRINE_BONUS := 1.0
const STOREHOUSE_WORK_FACTOR := 0.5
## M5a: the nation (tiers, freely placed buildings, name and banner); see nation_catalogue.gd.
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
## How far from a character a building may be placed.
const PLACE_REACH := 200.0
## Placed buildings' nodes by building ID (presentation and collision, rebuilt from the state).
var _placed: Dictionary = {}
## This world's deposits (positions/amounts depend on the seed).
var sites: Dictionary = DEPOSITS
var state: Dictionary = initial_state()
var _shapes: Dictionary = {}
const ART := preload("res://scripts/visual/world_art.gd")
## Building art (step 20): y-sorted sprites standing on each footprint's bottom edge, shown once built.
var _art: Dictionary = {}
var _center: Sprite2D

static func initial_state(table: Dictionary = DEPOSITS) -> Dictionary:
    var deposits: Dictionary = {}
    for id in table:
        deposits[id] = table[id].amount
    return {"id": "camp_1", "founded": false, "founder": "", "wood": 0, "stone": 0, "essence": 0, "essence_offered": 0, "hut": false, "storehouse": false, "shrine": false, "forge": false, "stall": false, "smithy": false, "staff": {"trader": false, "smith": false}, "tool_yield": {"wood": 0, "stone": 0}, "deposits": deposits, "refills": {}, "refill_left": {}, "nation": NATION.initial_state()}

static func _whole(value: Variant, high: float = 1000000) -> bool:
    return (value is float or value is int) and value >= 0 and value <= high and value == floor(value)

static func valid_state(value: Variant, players: Dictionary, table: Dictionary = DEPOSITS) -> bool:
    if not value is Dictionary or value.size() != 19 or value.get("id") != "camp_1" or not value.get("founded") is bool or not value.get("founder") is String:
        return false
    for id in STRUCTURES:
        if not value.get(STRUCTURES[id].key) is bool:
            return false
    if value.founded:
        if not players.has(value.founder):
            return false
    elif not value.founder.is_empty() or value.hut or value.storehouse or value.shrine or value.forge:
        return false
    # Extra wood/stone gathered with an axe or pickaxe (M4.5d), part of the camp's books below.
    var tool_yield: Variant = value.get("tool_yield")
    if not tool_yield is Dictionary or tool_yield.size() != 2 or not _whole(tool_yield.get("wood")) or not _whole(tool_yield.get("stone")):
        return false
    # Staff (M4.5c): hired only where their structure stands.
    var staff: Variant = value.get("staff")
    if not staff is Dictionary or staff.size() != STAFF.size():
        return false
    for role in STAFF:
        if not staff.get(role) is bool or (staff[role] and not value[STRUCTURES[STAFF[role][0]].key]):
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
    # M5a: the nation's tiers and buildings (their costs are spent from the stock below).
    if not NATION.valid(value.get("nation"), value.founded):
        return false
    if not value.get("refills") is Dictionary or not value.get("refill_left") is Dictionary:
        return false
    for id in value.refills:
        if not table.has(id) or id in SEEDED_DEPOSITS or not _whole(value.refills[id], 100000):
            return false
    for id in value.refill_left:
        var left: Variant = value.refill_left[id]
        if not table.has(id) or id in SEEDED_DEPOSITS or not (left is float or left is int) or left < 0 or left > REFILL_SECONDS or value.deposits[id] != 0:
            return false
    for resource in RESOURCES:
        var stock: Variant = value.get(resource)
        if not stock is float and not stock is int:
            return false
        var income: int = int(value.essence_offered) if resource == "essence" else int(value.tool_yield.get(resource, 0))
        for id in table:
            if table[id].resource == resource:
                income += table[id].amount * (1 + int(value.refills.get(id, 0))) - int(value.deposits[id])
        for id in STRUCTURES:
            if value[STRUCTURES[id].key]:
                income -= STRUCTURES[id].cost.get(resource, 0)
        income -= int(value.nation.spent[resource])
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
        var art: Sprite2D = ART.prop(STRUCTURES[id].key, STRUCTURES[id].site + Vector2(0, STRUCTURES[id].size.y / 2.0 + 2.0))
        art.visible = state[STRUCTURES[id].key]
        add_child(art)
        _art[id] = art
    _center = ART.prop("camp_post", SITE + Vector2(0, 6))
    add_child(_center)

## Switch to this world's deposit table (from its seed). Restore or reset `state` afterwards.
func set_sites(table: Dictionary) -> void:
    sites = table
    queue_redraw()

func restore(value: Dictionary) -> void:
    state = value.duplicate(true)
    for id in STRUCTURES:
        _shapes[id].set_deferred("disabled", not state[STRUCTURES[id].key])
    _sync_placed()
    queue_redraw()

## --- M5a: the nation
func nation() -> Dictionary:
    return state.nation

func tier() -> int:
    return int(state.nation.tier)

## Is this world position inside the settlement (the founded camp's radius for its tier)?
func in_settlement(world: Vector2) -> bool:
    return state.founded and world.distance_to(SITE) <= NATION.radius(tier())

## Why a building cannot go on this tile ("" when it can); `actor` may be null (tests, previews).
func place_problem(actor: Node2D, kind: String, tile: Vector2i) -> String:
    if not state.founded:
        return "Found the camp first."
    if not NATION.BUILDINGS.has(kind):
        return "Unknown building."
    var spec: Array = NATION.BUILDINGS[kind]
    if int(spec[4]) > tier():
        return "%s needs a %s." % [spec[0], NATION.tier_name(int(spec[4])).to_lower()]
    if spec[5] and NATION.count(state.nation, kind) > 0:
        return "Your nation has a %s already." % spec[0]
    if state.nation.buildings.size() >= NATION.MAX_BUILDINGS:
        return "No more buildings fit the settlement."
    var area := NATION.footprint(kind, tile)
    if area.get_center().distance_to(SITE) + area.size.length() / 2.0 > NATION.radius(tier()):
        return "Outside your %s (grow it to build further out)." % NATION.tier_name(tier()).to_lower()
    if actor != null and actor.global_position.distance_to(NATION.foot(tile)) > PLACE_REACH:
        return "Too far away."
    for resource in spec[3]:
        if int(state[resource]) < int(spec[3][resource]):
            return "%s costs %s." % [spec[0], NATION.cost_text(spec[3])]
    return clear_problem(area)

## Free ground: no water or cliffs, other buildings, the camp's structures (built or not), the
## flag, deposits, chests, the trial stone, trees, rocks, props or anyone standing there.
func clear_problem(area: Rect2) -> String:
    var padded := area.grow(NATION.GAP)
    for y in range(MAP.to_tile(padded.position).y, MAP.to_tile(padded.end).y + 1):
        for x in range(MAP.to_tile(padded.position).x, MAP.to_tile(padded.end).x + 1):
            if MAP.solid(x, y):
                return "Not on water or rock."
    for entry in state.nation.buildings:
        if NATION.footprint(entry.kind, Vector2i(entry.tile[0], entry.tile[1])).grow(NATION.GAP).intersects(area):
            return "Too close to another building."
    for id in STRUCTURES:
        if Rect2(STRUCTURES[id].site - STRUCTURES[id].size / 2.0, STRUCTURES[id].size).grow(NATION.GAP + 4.0).intersects(area):
            return "That ground is kept for the %s." % STRUCTURES[id].name
    var points: Array = [SITE]
    for id in sites:
        points.append(sites[id].position)
    var world: Node = get_parent()
    if world != null and "layout" in world:
        for chest in world.layout.get("chests", []):
            points.append(chest.position)
    if world != null and world.get("trial") != null:
        points.append(world.trial.stone)
    for point in points:
        if padded.grow(NATION.DEPOSIT_CLEARANCE - NATION.GAP).has_point(point):
            return "Too close to the flag, a deposit, a chest or the trial stone."
    if world != null:
        for node in world.get_children():
            if (node.is_in_group("player") or node.is_in_group("allies") or node.is_in_group("enemies")) and padded.grow(6.0).has_point(node.position):
                if not node.is_in_group("enemies") or node.get_node("Health").current > 0:
                    return "Someone is standing there."
    if is_inside_tree():
        var query := PhysicsShapeQueryParameters2D.new()
        var box := RectangleShape2D.new()
        box.size = area.size
        query.shape = box
        query.transform = Transform2D(0.0, area.get_center())
        query.collision_mask = 1
        if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
            return "Something is in the way (a tree, rock or wall)."
    return ""

## Host: build `kind` on a tile from the shared stock.
func place(actor: Node2D, kind: String, tile: Vector2i) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    var problem := place_problem(actor, kind, tile)
    if not problem.is_empty():
        if actor != null:
            get_node("/root/GameSession").notify_character(actor.character_id, problem)
        return false
    var cost: Dictionary = NATION.BUILDINGS[kind][3]
    for resource in cost:
        state[resource] -= int(cost[resource])
        state.nation.spent[resource] = int(state.nation.spent[resource]) + int(cost[resource])
    state.nation.buildings.append({"id": "b_%d" % int(state.nation.next), "kind": kind, "tile": [tile.x, tile.y]})
    state.nation.next = int(state.nation.next) + 1
    _sync_placed()
    queue_redraw()
    return true

## Host: tear a building down (its materials are not returned).
func demolish(id: String) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    for index in range(state.nation.buildings.size()):
        if state.nation.buildings[index].id == id:
            state.nation.buildings.remove_at(index)
            _sync_placed()
            queue_redraw()
            return true
    return false

## The placed building whose footprint holds a world position ("" if none).
func building_at(world: Vector2) -> String:
    for entry in state.nation.buildings:
        if NATION.footprint(entry.kind, Vector2i(entry.tile[0], entry.tile[1])).grow(6.0).has_point(world):
            return entry.id
    return ""

## Host: rank the settlement up (camp → village → town).
func rank_up() -> bool:
    if not AUTHORITY.can_mutate(self) or not state.founded or not NATION.tier_problem(state.nation, state).is_empty():
        return false
    var next: int = tier() + 1
    for resource in NATION.TIERS[next][2]:
        state[resource] -= int(NATION.TIERS[next][2][resource])
        state.nation.spent[resource] = int(state.nation.spent[resource]) + int(NATION.TIERS[next][2][resource])
    state.nation.tier = next
    queue_redraw()
    return true

## Host: the founder names the nation and picks its banner.
static func clean_name(text: String) -> String:
    var cleaned := ""
    for character in text.strip_edges():
        if character.unicode_at(0) >= 32 and character.unicode_at(0) != 127:
            cleaned += character
    return cleaned.substr(0, NATION.NAME_LENGTH)

## Placed buildings as nodes: art standing on its foot with a collision box (or a drawn banner).
func _sync_placed() -> void:
    var wanted := {}
    for entry in state.nation.buildings:
        wanted[entry.id] = entry
    for id in _placed.keys():
        if not wanted.has(id):
            if is_instance_valid(_placed[id]):
                _placed[id].queue_free()
            _placed.erase(id)
    for id in wanted:
        if _placed.has(id) and is_instance_valid(_placed[id]):
            continue
        var entry: Dictionary = wanted[id]
        var tile := Vector2i(entry.tile[0], entry.tile[1])
        var spec: Array = NATION.BUILDINGS[entry.kind]
        var body := StaticBody2D.new()
        body.name = "Building_%s" % id
        body.position = NATION.foot(tile)
        body.set_meta("building", entry.kind)
        var shape := CollisionShape2D.new()
        var box := RectangleShape2D.new()
        box.size = spec[2]
        shape.shape = box
        shape.position = Vector2(0, -spec[2].y / 2.0)
        body.add_child(shape)
        if String(spec[1]).is_empty():
            var flag := Node2D.new()
            flag.name = "Flag"
            flag.draw.connect(_draw_banner.bind(flag))
            body.add_child(flag)
        else:
            var terrain_props: Dictionary = preload("res://scripts/world/world_terrain.gd").PROPS
            var sprite := Sprite2D.new()
            var texture := AtlasTexture.new()
            texture.atlas = load(terrain_props[spec[1]][0])
            texture.region = terrain_props[spec[1]][1]
            sprite.texture = texture
            sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            sprite.offset = Vector2(0, -texture.region.size.y / 2.0)
            body.add_child(sprite)
        get_parent().add_child.call_deferred(body)
        _placed[id] = body

## A pole with the nation's flag in its colour, emblem drawn small.
func _draw_banner(canvas: Node2D) -> void:
    var color: Color = NATION.COLORS[int(state.nation.color)]
    canvas.draw_rect(Rect2(-1, -30, 2, 30), Color("6b4a2b"))
    canvas.draw_rect(Rect2(1, -29, 14, 10), color)
    canvas.draw_rect(Rect2(1, -29, 14, 10), color.darkened(0.4), false, 1.0)
    draw_emblem(canvas, int(state.nation.emblem), Vector2(8, -24), color.darkened(0.5) if color.get_luminance() > 0.6 else Color(1, 1, 1, 0.9))

static func draw_emblem(canvas: CanvasItem, emblem: int, at: Vector2, ink: Color, scale: float = 1.0) -> void:
    match emblem:
        0:
            var star := PackedVector2Array()
            for i in range(10):
                star.append(at + Vector2.from_angle(-PI / 2 + i * PI / 5) * (3.0 if i % 2 == 0 else 1.3) * scale)
            canvas.draw_colored_polygon(star, ink)
        1:
            canvas.draw_arc(at, 2.6 * scale, PI * 0.35, PI * 1.65, 10, ink, 1.4 * scale)
        2:
            canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-2.5, -3) * scale, at + Vector2(2.5, -3) * scale, at + Vector2(0, 3.5) * scale]), ink)
        3:
            canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -3.5) * scale, at + Vector2(2.5, 1) * scale, at + Vector2(0, 3) * scale, at + Vector2(-2.5, 1) * scale]), ink)
        4:
            canvas.draw_circle(at, 2.2 * scale, ink)
            canvas.draw_line(at, at + Vector2(0, 3.5) * scale, ink, 1.0)
        _:
            canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-3, 2) * scale, at + Vector2(-3, -2) * scale, at + Vector2(-1.5, 0) * scale, at + Vector2(0, -3) * scale, at + Vector2(1.5, 0) * scale, at + Vector2(3, -2) * scale, at + Vector2(3, 2) * scale]), ink)

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
            var amount: int = int(state.deposits[id])
            var resource: String = sites[id].resource
            harvest(id)
            message = "Materials added to shared camp stock."
            # M4.5d: an owned axe (wood) or pickaxe (stone) gathers more.
            var tool: String = "axe" if resource == "wood" else "pickaxe"
            var tier: int = int(actor.progression.get("tools", {}).get(tool, 0)) if "progression" in actor else 0
            var bonus: int = int(round(amount * preload("res://scripts/travel/travel_catalogue.gd").GATHER_BONUS[tier]))
            if bonus > 0:
                state[resource] += bonus
                state.tool_yield[resource] = int(state.tool_yield[resource]) + bonus
                message = "Materials added to shared camp stock (+%d %s from your %s)." % [bonus, resource, tool]
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
        "hire":
            # Pay Zeni once; the trader or smith then keeps shop at its structure (WorldTrade).
            if not STAFF.has(id) or not state[STRUCTURES[STAFF[id][0]].key] or state.staff[id] or not can_reach(actor, STRUCTURES[STAFF[id][0]].site, HIRE_REACH):
                return false
            if not actor.spend_zeni(STAFF[id][1]):
                get_node("/root/GameSession").notify_character(actor.character_id, "Hiring the %s costs %d Zeni." % [STAFF[id][2], STAFF[id][1]])
                return false
            state.staff[id] = true
            message = "You hired a %s for %d Zeni. Talk to them with F." % [STAFF[id][2], STAFF[id][1]]
        "place":
            # M5a: "kind@x,y" (a tile); the host checks the tier, stock, reach and free ground.
            var parts := id.split("@")
            var coords := parts[1].split(",") if parts.size() == 2 else PackedStringArray()
            if coords.size() != 2 or not coords[0].is_valid_int() or not coords[1].is_valid_int():
                return false
            if not place(actor, parts[0], Vector2i(int(coords[0]), int(coords[1]))):
                return false
            message = "%s built. Shared materials consumed." % NATION.BUILDINGS[parts[0]][0]
        "demolish":
            if not state.founded or not can_reach_point(actor, id) or not demolish(id):
                return false
            message = "Building torn down (its materials are lost)."
        "rank":
            var problem := NATION.tier_problem(state.nation, state) if state.founded else "Found the camp first."
            if not problem.is_empty() or not can_reach(actor, SITE, 55):
                if not problem.is_empty():
                    get_node("/root/GameSession").notify_character(actor.character_id, problem)
                return false
            rank_up()
            message = "Your settlement is now a %s!" % NATION.tier_name(tier()).to_lower()
        "name":
            var cleaned := clean_name(id)
            if not state.founded or actor.character_id != state.founder or cleaned.is_empty():
                return false
            state.nation.name = cleaned
            message = "Your nation is now called %s." % cleaned
        "banner":
            var pick := id.split(",")
            if not state.founded or actor.character_id != state.founder or pick.size() != 2 or not pick[0].is_valid_int() or not pick[1].is_valid_int():
                return false
            if int(pick[0]) < 0 or int(pick[0]) >= NATION.COLORS.size() or int(pick[1]) < 0 or int(pick[1]) >= NATION.EMBLEMS.size():
                return false
            state.nation.color = int(pick[0])
            state.nation.emblem = int(pick[1])
            for node in _placed.values():
                if is_instance_valid(node) and node.has_node("Flag"):
                    node.get_node("Flag").queue_redraw()
            message = "New banner raised."
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

## A building to demolish must be close to the character.
func can_reach_point(actor: Node2D, id: String) -> bool:
    for entry in state.nation.buildings:
        if entry.id == id:
            return actor.global_position.distance_to(NATION.foot(Vector2i(entry.tile[0], entry.tile[1]))) <= PLACE_REACH
    return false

func harvest(id: String) -> bool:
    if not AUTHORITY.can_mutate(self) or not sites.has(id) or state.deposits[id] <= 0:
        return false
    state[sites[id].resource] += state.deposits[id]
    state.deposits[id] = 0
    if not id in SEEDED_DEPOSITS:
        state.refill_left[id] = REFILL_SECONDS
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
    if not AUTHORITY.can_mutate(self):
        return
    _refill(delta)
    if not state.shrine:
        return
    # Resting at the shrine doubles recovery once the character's normal regeneration delay has passed.
    for actor in get_tree().get_nodes_in_group("player"):
        var pool = actor.get_node("Magicules")
        if actor.get_node("Health").current > 0 and pool.enabled and pool._delay_left <= 0 and actor.global_position.distance_to(STRUCTURES.shrine_1.site) <= SHRINE_RANGE:
            pool.restore(pool.regeneration_per_second * SHRINE_BONUS * delta)

func _draw() -> void:
    for id in _art:
        _art[id].visible = state[STRUCTURES[id].key]
    if is_instance_valid(_center):
        var center := "campfire" if state.founded else "camp_post"
        if _center.name != center:
            _center.name = center
            _center.texture = ART.atlas(center)
            _center.offset = Vector2(0, -ART.PROPS[center][1].size.y / 2.0)
    draw_arc(SITE, 21, 0, TAU, 20, Color("e1bf79") if state.founded else Color("a1a99b"), 2)
    for node in _placed.values():
        if is_instance_valid(node) and node.has_node("Flag"):
            node.get_node("Flag").queue_redraw()
    for id in sites:
        var point: Vector2 = sites[id].position
        if state.deposits[id] == 0:
            ART.draw_prop(self, "pebbles", point + Vector2(0, 6))
        elif sites[id].resource == "wood":
            ART.draw_prop(self, "logs", point + Vector2(0, 8))
            ART.draw_prop(self, "logs", point + Vector2(2, 1))
        else:
            ART.draw_prop(self, "stones", point + Vector2(0, 7))
    if state.shrine:
        draw_arc(STRUCTURES.shrine_1.site, SHRINE_RANGE, 0, TAU, 32, Color(0.44, 0.89, 0.83, 0.25), 1)

## Region deposits come back REFILL_SECONDS after they were emptied (host).
func _refill(delta: float) -> void:
    if state.refill_left.is_empty():
        return
    for id in state.refill_left.keys():
        state.refill_left[id] = maxf(0.0, float(state.refill_left[id]) - delta)
        if state.refill_left[id] <= 0.0 and sites.has(id):
            state.refill_left.erase(id)
            state.deposits[id] = sites[id].amount
            state.refills[id] = int(state.refills.get(id, 0)) + 1
            queue_redraw()
            get_node("/root/GameSession").queue_save()
