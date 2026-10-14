extends Node
## Creature respawning (step 17d2, user decision). A defeated world creature comes back at its
## home after RESPAWN_SECONDS with the same ID, kind and difficulty. If its corpse was never
## absorbed it is cleared then. It never appears while a living character stands within
## CLEAR_RADIUS of its home (it retries a little later). Trial creatures never respawn.
## Host-only; the pending list is saved with the world.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
## Longest respawn (Elite); each creature's time comes from RegionContent.respawn_seconds (24a:
## by tier 45 / 90 / 180 s, three times faster at hidden leveling spots).
const RESPAWN_SECONDS := 180.0
const REGION := preload("res://scripts/world/region_content.gd")
const RETRY_SECONDS := 5.0
const CLEAR_RADIUS := 160.0
const MAX_PENDING := 64

## [{id, kind, difficulty, home: [x, y], remaining}]
var pending: Array = []

func restore(value: Variant) -> void:
    pending = value.duplicate(true) if value is Array else []

func capture() -> Array:
    return pending.duplicate(true)

func scheduled(id: String) -> bool:
    return pending.any(func(entry): return entry.id == id)

## Called when a creature is defeated (host). Trial creatures and duplicates are ignored.
func schedule(enemy: Node2D) -> void:
    if not AUTHORITY.can_mutate(self) or not enemy.drops_rewards or scheduled(enemy.entity_id) or pending.size() >= MAX_PENDING:
        return
    pending.append({"id": enemy.entity_id, "kind": enemy.kind, "difficulty": int(enemy.difficulty), "home": CODEC.vector(enemy.home), "remaining": REGION.respawn_seconds(enemy.entity_id, int(enemy.difficulty))})

func _physics_process(delta: float) -> void:
    if pending.is_empty() or not AUTHORITY.can_mutate(self):
        return
    for entry in pending.duplicate():
        entry.remaining = maxf(0.0, entry.remaining - delta)
        if entry.remaining > 0.0:
            continue
        if _occupied(CODEC.to_vector(entry.home)):
            entry.remaining = RETRY_SECONDS
            continue
        pending.erase(entry)
        _respawn(entry)

func _occupied(home: Vector2) -> bool:
    for actor in get_tree().get_nodes_in_group("player"):
        if actor.get_node("Health").current > 0 and actor.global_position.distance_to(home) < CLEAR_RADIUS:
            return true
    return false

func _respawn(entry: Dictionary) -> void:
    var world: Node2D = get_parent()
    var old: Node2D = world.entity_by_id(entry.id)
    if old != null:
        # An unabsorbed corpse (or a living duplicate, which should not exist) makes room.
        if old.get_node("Health").current > 0:
            return
        if old.being_analyzed:
            entry.remaining = RETRY_SECONDS
            pending.append(entry)
            return
        world.remove_child(old)
        old.queue_free()
    var creature: Node2D = load(CODEC.ENEMY_SCENES[entry.kind]).instantiate()
    creature.entity_id = entry.id
    creature.difficulty = entry.difficulty
    creature.position = CODEC.to_vector(entry.home)
    world.add_child(creature)
    world.wire_enemy(creature)
    get_node("/root/GameSession").queue_save()
