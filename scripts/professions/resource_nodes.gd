extends Node
## Harvestable trees and ore rocks (M6a): every tree and boulder of the world's prop plan is a
## resource node whose wood or ore follows from its kind, its region and its plan index (the same
## on every peer). The host runs the swings (Player.start_gather with "node:<index>"): each swing
## succeeds with the profession's chance, every SWINGS_PER_UNIT successes put one log or ore in
## the bag and give XP; an emptied node becomes a stump or rubble until it grows back. Which nodes
## are used is replicated in snapshots and not saved (nodes are full again after a restart).
const PRO := preload("res://scripts/professions/profession_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const REACH := 30.0

var world: Node2D
## Host-owned: units taken from a node {index: count}, seconds until a used-up node regrows
## {index: seconds}.
var used: Dictionary = {}
var regrow: Dictionary = {}
## Swing successes towards the next unit, per character {character_id: [index, successes]}.
var _progress: Dictionary = {}
var _info_cache: Dictionary = {}

func _init(owner_world: Node2D = null) -> void:
    world = owner_world
    name = "ResourceNodes"

func _terrain() -> Node:
    return world.terrain if world != null else null

## {prop, foot, resource, profession, required, units} of a plan index, or {} if not harvestable.
func info(index: int) -> Dictionary:
    if _info_cache.has(index):
        return _info_cache[index]
    var plan: Array = _terrain().planned_props() if _terrain() != null else []
    if index < 0 or index >= plan.size():
        return {}
    var prop: String = plan[index][0]
    var result := {}
    if prop in PRO.TREE_PROPS or prop in PRO.ROCK_PROPS or prop in PRO.HERB_PROPS:
        var foot: Vector2 = plan[index][1]
        var resource := PRO.resource_for(prop, MAP.region_name(foot), index)
        if prop in PRO.HERB_PROPS and resource.is_empty():
            result = {}
        elif not resource.is_empty():
            result = {"prop": prop, "foot": foot, "resource": resource, "profession": PRO.profession_for(resource), "required": PRO.required_level(resource), "units": PRO.units_for(resource, index)}
    _info_cache[index] = result
    return result

## Units a character's milestones add to a node.
static func extra_units(profession: String, level: int) -> int:
    if profession == "woodcutting" and level >= 20:
        return 1
    if profession == "mining" and level >= 30:
        return 1
    return 0

func intact(index: int) -> bool:
    return not regrow.has(index) and not info(index).is_empty()

## Where a character stands to work a node (the foot of its sprite).
func work_point(index: int) -> Vector2:
    return info(index).get("foot", Vector2.ZERO) + Vector2(0, -4)

## The nearest intact node within reach of a character (-1 for none).
func nearest(actor: Node2D) -> int:
    if _terrain() == null:
        return -1
    var best := -1
    var distance := REACH + 0.1
    for index in _terrain().props_near(actor.global_position, REACH + 16.0):
        if not intact(index):
            continue
        var current: float = actor.global_position.distance_to(work_point(index))
        if current < distance:
            best = index
            distance = current
    return best

## What the HUD prompt shows for a character at a node: [text, chance].
func prompt(actor: Node2D, index: int) -> Array:
    var node := info(index)
    if node.is_empty():
        return ["", 0.0]
    var level: int = PRO.level_of(actor.progression, node.profession)
    var chance := success_chance(actor, index)
    var verb: String = {"woodcutting": "Chop", "mining": "Mine", "alchemy": "Pick"}[node.profession]
    return ["F: %s %s · %s %d/%d · %d%%" % [verb, PRO.resource_info(node.resource)[0], PRO.PROFESSIONS[node.profession][0], level, node.required, int(round(chance * 100.0))], chance]

## The tool tier that helps with a node (herbs are picked by hand).
static func tool_tier(actor: Node2D, profession: String) -> int:
    if profession == "alchemy":
        return 0
    return int(actor.progression.get("tools", {}).get("axe" if profession == "woodcutting" else "pickaxe", 0))

func success_chance(actor: Node2D, index: int) -> float:
    var node := info(index)
    var level: int = PRO.level_of(actor.progression, node.profession)
    return PRO.chance(level, node.required, 0.03 * tool_tier(actor, node.profession))

func swing_seconds(actor: Node2D, index: int) -> float:
    var node := info(index)
    var level: int = PRO.level_of(actor.progression, node.profession)
    return PRO.work_seconds(PRO.BASE_SWING, level, node.required, tool_tier(actor, node.profession))

## Host: one swing landed. Returns false when the work must stop (node gone, bag full).
func strike(actor: Node2D, index: int, rng: RandomNumberGenerator) -> bool:
    if not intact(index):
        return false
    var node := info(index)
    var id: String = actor.character_id
    var progress: Array = _progress.get(id, [index, 0])
    if progress[0] != index:
        progress = [index, 0]
    var profession: String = node.profession
    if rng.randf() >= success_chance(actor, index):
        # A miss still teaches a little.
        actor.gain_profession_xp(profession, maxi(1, PRO.xp_reward(node.required) / 15))
        _progress[id] = progress
        return true
    progress[1] += 1
    if progress[1] < PRO.SWINGS_PER_UNIT:
        _progress[id] = progress
        return true
    _progress.erase(id)
    var bag: Node = actor.get_node("Inventory")
    var level: int = PRO.level_of(actor.progression, profession)
    var count := 2 if rng.randf() < PRO.double_chance(level) else 1
    var added: int = bag.add_material(node.resource, count)
    if added <= 0:
        actor.session.notify_character(id, "Your bag is full.")
        return false
    var name: String = PRO.resource_info(node.resource)[0]
    var note := "+%d %s" % [added, name]
    # Finds: gems while mining, rare sap from trees (Woodcutting 30).
    if profession == "mining" and rng.randf() < PRO.GEM_CHANCE * (2.0 if level >= 20 else 1.0):
        var gem := PRO.gem_for(int(node.required), rng.randi())
        if bag.add_material(gem, 1) == 1:
            note += " and a %s!" % PRO.GEMS[gem][0]
    elif profession == "alchemy":
        var day_night := preload("res://scripts/world/day_night.gd")
        var time: float = float(world.progression.get("world_time", 0.0))
        if day_night.is_night(time) and rng.randf() < 0.25 and bag.add_material("herb_moonbloom", 1) == 1:
            note += " and a Moonbloom (it only opens at night)!"
        elif day_night.weather(MAP.region_name(node.foot), time) == "storm" and rng.randf() < 0.2 and bag.add_material("herb_storm_orchid", 1) == 1:
            note += " and a Storm Orchid!"
    elif profession == "woodcutting" and level >= 30 and rng.randf() < 0.01:
        if bag.add_material("amber_sap", 1) == 1:
            note += " and Amber Sap!"
    actor.gain_profession_xp(profession, PRO.xp_reward(node.required))
    actor.session.notify_character(id, note + ".")
    used[index] = int(used.get(index, 0)) + 1
    if int(used[index]) >= int(node.units) + extra_units(profession, level):
        used.erase(index)
        regrow[index] = PRO.regrow_seconds(node.resource)
        refresh(index)
        return false
    return true

func _process(delta: float) -> void:
    if regrow.is_empty() or not AUTHORITY_host():
        return
    for index in regrow.keys():
        regrow[index] = float(regrow[index]) - delta
        if regrow[index] <= 0.0:
            regrow.erase(index)
            refresh(index)

func AUTHORITY_host() -> bool:
    var session: Node = world.session if world != null else null
    return session == null or not session.replica_world

## Snapshot part (every peer).
func state() -> Dictionary:
    return {"used": used.duplicate(), "regrow": regrow.duplicate()}

func apply(data: Variant) -> void:
    if not data is Dictionary:
        return
    var before: Dictionary = regrow.duplicate()
    used = {}
    regrow = {}
    for key in data.get("used", {}):
        used[int(key)] = int(data.used[key])
    for key in data.get("regrow", {}):
        regrow[int(key)] = float(data.regrow[key])
    for index in before:
        if not regrow.has(index):
            refresh(index)
    for index in regrow:
        if not before.has(index):
            refresh(index)

func reset() -> void:
    var changed: Array = regrow.keys()
    used = {}
    regrow = {}
    _progress = {}
    for index in changed:
        refresh(index)

## Redraw a spawned prop (felled/broken or grown back).
func refresh(index: int) -> void:
    var holder: Node2D = _terrain().spawned_prop(index) if _terrain() != null else null
    if holder != null:
        decorate(holder, index)

## Called by the terrain whenever it spawns a prop: ore veins on rocks, stumps and rubble.
func decorate(holder: Node2D, index: int) -> void:
    var node := info(index)
    if node.is_empty():
        return
    var marks: Node2D = holder.get_node_or_null("Marks")
    if marks == null:
        marks = Marks.new()
        marks.name = "Marks"
        # Just in front of the sprite (same foot) so the veins draw over the rock.
        marks.position = Vector2(0, 0.5)
        holder.add_child(marks)
    marks.resource = node.resource
    marks.prop = node.prop
    marks.depleted = regrow.has(index)
    for child in holder.get_children():
        if child is Sprite2D:
            child.visible = not marks.depleted
    marks.queue_redraw()

## Ore veins on a rock, or a stump/rubble where a node was used up.
class Marks extends Node2D:
    const PRO := preload("res://scripts/professions/profession_catalogue.gd")
    var resource := ""
    var prop := ""
    var depleted := false
    const VEIN := [Vector2(-8, -14), Vector2(-4, -11), Vector2(1, -16), Vector2(5, -9), Vector2(-1, -7), Vector2(8, -13)]

    func _draw() -> void:
        if depleted:
            if PRO.HERBS.has(resource):
                draw_line(Vector2(-3, -1), Vector2(-2, -4), Color("5a7a3a"), 1.0)
                draw_line(Vector2(2, -1), Vector2(3, -4), Color("5a7a3a"), 1.0)
            elif PRO.WOODS.has(resource):
                draw_circle(Vector2(0, -3), 5.0, Color("6b4a2b"))
                draw_circle(Vector2(0, -3), 3.5, PRO.WOODS[resource][3].lerp(Color("c49a6a"), 0.5))
                draw_arc(Vector2(0, -3), 2.0, 0, TAU, 8, Color("8a6440"), 1.0)
            else:
                for k in range(5):
                    draw_rect(Rect2(Vector2(-8 + k * 3.5, -3 - (k % 2) * 2), Vector2(3, 2)), Color("8a8f96"))
            return
        if PRO.HERBS.has(resource):
            # Little blossoms in the herb's colour on the bush.
            var tint: Color = PRO.HERBS[resource][3]
            for spot in [Vector2(-4, -9), Vector2(2, -11), Vector2(4, -6), Vector2(-1, -5)]:
                draw_rect(Rect2(spot, Vector2(2, 2)), tint)
                draw_rect(Rect2(spot, Vector2(1, 1)), tint.lightened(0.5))
        if PRO.ORES.has(resource):
            var colour: Color = PRO.ORES[resource][3]
            # A vein across the rock's face: a few nuggets with a dark rim and a highlight.
            for spot in VEIN:
                var at: Vector2 = spot + Vector2(0, -0.5)
                draw_rect(Rect2(at - Vector2(1, 1), Vector2(4, 4)), colour.darkened(0.55))
                draw_rect(Rect2(at, Vector2(2, 2)), colour)
                draw_rect(Rect2(at, Vector2(1, 1)), colour.lightened(0.5))
