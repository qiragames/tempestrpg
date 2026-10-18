extends Node2D
## Pets in the world (M11f): every character's chosen pet trots after them (drawn on every peer
## from the replicated progression), and the host's pet rules — hatching eggs, choosing a pet, the
## eggs creatures drop. See pet_catalogue.gd.
const PETS := preload("res://scripts/pets/pet_catalogue.gd")
const AUTHORITY := preload("res://scripts/network/authority.gd")
const FOLLOW := Vector2(-14, 6)

## Eggs drop in the game (switched on by the title menu, where every game starts); scripted test
## runs that count bag items stay exact unless they switch it on (the pets test does).
static var egg_drops := false

var world: Node2D
var _followers: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _init(owner_world: Node2D = null) -> void:
    world = owner_world
    name = "Pets"
    y_sort_enabled = true
    _rng.randomize()

func session() -> Node:
    return get_node("/root/GameSession")

## --- Host.
func use_egg(actor: Node2D) -> bool:
    if not AUTHORITY.can_mutate(actor) or actor.get_node("Inventory").count_of(PETS.EGG) <= 0:
        return false
    var id := PETS.hatch(actor.progression, _rng)
    if id.is_empty():
        session().notify_character(actor.character_id, "You already have every pet. The egg stays in your bag.")
        return false
    actor.get_node("Inventory").discard(StringName(PETS.EGG), 1)
    if not actor.progression.get("pets") is Array:
        actor.progression["pets"] = []
    actor.progression.pets.append(id)
    if String(actor.progression.get("pet", "")).is_empty():
        actor.progression["pet"] = id
    actor.refresh_gear()
    session().notify_character(actor.character_id, "The egg hatches: %s! (%s · V: pets)" % [PETS.PETS[id][0], PETS.PETS[id][1]])
    if world.get("quests") != null:
        world.quests.unlock(actor)
    session().queue_save()
    return true

func choose(actor: Node2D, id: String) -> bool:
    if not AUTHORITY.can_mutate(actor) or not (id.is_empty() or id in PETS.owned(actor.progression)):
        return false
    actor.progression["pet"] = id
    actor.refresh_gear()
    session().queue_save()
    return true

## Host: a creature fell (QuestLog passes defeats on) — sometimes an egg for whoever beat it.
func on_event(actor: Node, kind: String, data: Dictionary) -> void:
    if not AUTHORITY.can_mutate(actor) or not egg_drops:
        return
    var entity := String(data.get("id", ""))
    var chance := 0.0
    if kind == "kill":
        chance = 1.0 if entity.begins_with("event_treasure_goblin") else float(PETS.EGG_CHANCE[clampi(int(data.get("difficulty", 1)), 0, 2)])
    elif kind == "boss":
        chance = PETS.BOSS_EGG_CHANCE
    if chance > 0.0 and _rng.randf() < chance and actor.get_node("Inventory").add_material(PETS.EGG, 1) == 1:
        session().notify_character(actor.character_id, "A Mysterious Egg! Use it from your bag to hatch a pet.")

## --- Every peer: followers.
func _process(delta: float) -> void:
    if world == null:
        return
    var wanted := {}
    for actor in get_tree().get_nodes_in_group("player"):
        if actor.get_parent() != world or not actor.visible:
            continue
        var id := PETS.active(actor.progression)
        if id.is_empty():
            continue
        wanted[actor.character_id] = true
        var follower: Sprite2D = _followers.get(actor.character_id)
        if follower == null or follower.get_meta("pet") != id:
            if follower != null:
                follower.queue_free()
            follower = Sprite2D.new()
            follower.texture = PETS.texture(id)
            follower.hframes = 2
            follower.offset = Vector2(0, -7)
            follower.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            follower.set_meta("pet", id)
            follower.global_position = actor.global_position + FOLLOW
            add_child(follower)
            _followers[actor.character_id] = follower
        var facing_left: bool = float(actor.get("facing").x if actor.get("facing") is Vector2 else 1.0) < 0.0
        var target: Vector2 = actor.global_position + Vector2(-FOLLOW.x if facing_left else FOLLOW.x, FOLLOW.y)
        var gap: float = follower.global_position.distance_to(target)
        if gap > 240.0:
            follower.global_position = target
        elif gap > 2.0:
            var step: Vector2 = (target - follower.global_position) * minf(1.0, delta * 5.0)
            follower.global_position += step
            if absf(step.x) > 0.05:
                follower.flip_h = step.x < 0.0
        follower.frame = int(Time.get_ticks_msec() / 180) % 2 if gap > 3.0 else 0
    for owner_id in _followers.keys():
        if not wanted.has(owner_id):
            _followers[owner_id].queue_free()
            _followers.erase(owner_id)
