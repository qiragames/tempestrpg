extends RefCounted
## Stable IDs and primitive data only; runtime nodes/resources never enter a save.

const SKILLS := {"rending_bite": "res://data/skills/rending_bite.tres"}
const SPECIMEN := "res://data/specimens/forest_gnasher.tres"

static func vector(value: Vector2) -> Array:
    return [value.x, value.y]

static func to_vector(value: Array) -> Vector2:
    return Vector2(value[0], value[1])

static func capture_player(actor: Node2D) -> Dictionary:
    var health = actor.get_node("Health")
    var pool = actor.get_node("Magicules")
    var book = actor.get_node("SkillBook")
    var bag = actor.get_node("Inventory")
    var absorption = actor.get_node("Absorption")
    var known: Array = []
    for skill in book.all_skills():
        known.append(String(skill.id))
    var slots: Array = []
    for index in range(3):
        var skill: Resource = book.skill_at_slot(index)
        slots.append(String(skill.id) if skill else "")
    var counts: Dictionary = {}
    for entry in bag.entries():
        counts[String(entry.id)] = entry.count
    return {
        "id": actor.character_id, "position": vector(actor.position), "facing": vector(actor.facing),
        "move_speed": actor.move_speed,
        "exhaustion": {"active": actor.exhaustion_active, "remaining": actor.exhaustion_left},
        "health": {"maximum": health.maximum, "current": health.current, "immunity": health.immunity_left, "immunity_seconds": health.immunity_seconds},
        "magicules": {"maximum": pool.maximum, "current": pool.current, "regen": pool.regeneration_per_second, "regen_delay": pool.regeneration_delay, "delay": pool._delay_left, "enabled": pool.enabled},
        "skill_ids": known, "slots": slots, "inventory": {"capacity": bag.capacity, "counts": counts},
        "attack_recovery": actor.get_node("MeleeAttack").cooldown_left,
        "analysis": {"target": absorption._target.entity_id if absorption.active else "", "remaining": absorption.time_left},
        "progression": actor.progression.duplicate(true)
    }

static func apply_player(actor: Node2D, state: Dictionary, world: Node2D, replica: bool) -> void:
    actor.character_id = state.id
    actor.position = to_vector(state.position)
    actor.facing = to_vector(state.facing)
    actor.move_speed = state.move_speed
    actor.progression = state.progression.duplicate(true)
    actor.exhaustion_active = state.exhaustion.active
    actor.exhaustion_left = state.exhaustion.remaining
    var health = actor.get_node("Health")
    health.maximum = int(state.health.maximum)
    health.current = int(state.health.current)
    health.immunity_left = state.health.immunity
    health.immunity_seconds = state.health.immunity_seconds
    health.changed.emit(health.current, health.maximum)
    var pool = actor.get_node("Magicules")
    pool.maximum = state.magicules.maximum
    pool._current = state.magicules.current
    pool.regeneration_per_second = state.magicules.regen
    pool.regeneration_delay = state.magicules.regen_delay
    pool._delay_left = state.magicules.delay
    pool.enabled = state.magicules.enabled and health.current > 0
    pool.changed.emit(pool.current, pool.maximum)
    var book = actor.get_node("SkillBook")
    book._known.clear()
    for id in state.skill_ids:
        book._known[StringName(id)] = load(SKILLS[id])
    for index in range(3):
        book._slots[index] = StringName(state.slots[index])
    var bag = actor.get_node("Inventory")
    bag.capacity = int(state.inventory.capacity)
    bag._entries.clear()
    var specimen: Resource = load(SPECIMEN)
    for id in state.inventory.counts:
        bag._entries[StringName(id)] = {"id": StringName(id), "name": specimen.material_name, "description": specimen.material_description, "category": "Materials", "count": int(state.inventory.counts[id])}
    bag.changed.emit()
    actor.get_node("MeleeAttack").cooldown_left = state.attack_recovery
    var absorption = actor.get_node("Absorption")
    # Replicas show the channel. Reload/reconnect interrupts it without refunding cost.
    absorption._target = world.entity_by_id(state.analysis.target) if replica else null
    absorption.time_left = state.analysis.remaining if replica and absorption.active else 0.0
    actor.queue_redraw()

static func capture_entities(world: Node2D) -> Dictionary:
    var enemies: Array = []
    var pickups: Array = []
    var allies: Array = []
    for node in world.get_children():
        if node.is_queued_for_deletion():
            continue
        if node.is_in_group("enemies"):
            var health = node.get_node("Health")
            enemies.append({"id": node.entity_id, "kind": "gnasher", "position": vector(node.position), "home": vector(node.home), "difficulty": node.difficulty, "hp": health.current, "maximum_hp": health.maximum, "immunity": health.immunity_left, "state": node.state, "state_time": node.state_time, "target": node.target.character_id if is_instance_valid(node.target) else ""})
        elif node.is_in_group("magicule_pickups"):
            pickups.append({"id": node.entity_id, "position": vector(node.position), "amount": node.amount})
        elif node.is_in_group("allies"):
            allies.append({"id": node.entity_id, "position": vector(node.position), "owner": node.owner_id, "name": node.display_name, "race": node.race, "maximum_hp": node.maximum_hp, "power": node.power, "speed": node.follow_speed})
    return {"enemies": enemies, "pickups": pickups, "allies": allies, "camp": world.camp.state.duplicate(true)}

static func apply_entities(world: Node2D, data: Dictionary, replica: bool) -> void:
    world.camp.restore(data.camp)
    var wanted: Dictionary = {}
    for state in data.get("allies", []):
        wanted[state.id] = true
        var ally = world.entity_by_id(state.id)
        if ally == null:
            ally = load("res://scenes/allies/goblin_ally.tscn").instantiate()
            ally.entity_id = state.id
            world.add_child(ally)
        ally.position = to_vector(state.position)
        ally.owner_id = state.owner
        ally.display_name = state.name
        ally.race = state.race
        ally.maximum_hp = int(state.maximum_hp)
        ally.power = int(state.power)
        ally.follow_speed = state.speed
        ally.set_physics_process(not replica)
        ally.queue_redraw()
    for state in data.enemies:
        wanted[state.id] = true
        var actor = world.entity_by_id(state.id)
        if actor == null:
            actor = load("res://scenes/enemies/forest_gnasher.tscn").instantiate()
            actor.entity_id = state.id
            actor.difficulty = int(state.difficulty)
            world.add_child(actor)
            world.wire_enemy(actor)
        actor.position = to_vector(state.position)
        actor.home = to_vector(state.home)
        actor.difficulty = int(state.difficulty)
        actor.speed = actor.TIER_STATS[actor.difficulty].speed
        actor.damage = actor.TIER_STATS[actor.difficulty].damage
        actor.get_node("Health").maximum = int(state.maximum_hp)
        actor.get_node("Health").current = int(state.hp)
        actor.get_node("Health").immunity_left = state.immunity
        actor.state = int(state.state)
        actor.state_time = state.state_time
        actor.target = world.player_by_id(state.target)
        actor.get_node("CollisionShape2D").set_deferred("disabled", state.hp == 0)
        if state.hp == 0:
            actor.add_to_group("absorbable_creatures")
        else:
            actor.remove_from_group("absorbable_creatures")
        actor.set_physics_process(not replica)
        actor.get_node("Health").set_process(not replica)
        actor.queue_redraw()
    for state in data.pickups:
        wanted[state.id] = true
        var pickup = world.entity_by_id(state.id)
        if pickup == null:
            pickup = load("res://scenes/pickups/magicule_pickup.tscn").instantiate()
            pickup.entity_id = state.id
            pickup.amount = state.amount
            pickup.collected_by.connect(world.announce_magicule_pickup)
            world.add_child(pickup)
        pickup.position = to_vector(state.position)
        pickup.amount = state.amount
        pickup.set_physics_process(not replica)
    for node in world.get_children():
        if (node.is_in_group("enemies") or node.is_in_group("magicule_pickups") or node.is_in_group("allies")) and not wanted.has(node.entity_id):
            world.remove_child(node)
            node.queue_free()
