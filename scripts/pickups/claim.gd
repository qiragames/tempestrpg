extends RefCounted
## Who may take something lying on the ground (step 24a, user decision): loot handed out by
## damage rank and a defeated character's item pile belong to their owner for CLAIM_SECONDS of
## world time, then to anyone. Unowned things (owner "") are free for all. Host-side rule.
const CLAIM_SECONDS := 300.0

static func world_time(world: Node) -> float:
    return float(world.progression.get("world_time", 0.0)) if world != null and world.get("progression") is Dictionary else 0.0

static func can_take(world: Node, owner_id: String, claim_until: float, character_id: String) -> bool:
    return owner_id.is_empty() or owner_id == character_id or world_time(world) >= claim_until

static func until(world: Node) -> float:
    return world_time(world) + CLAIM_SECONDS
