extends RefCounted
## Stable IDs and primitive data only; runtime nodes/resources never enter a save.

const CATALOGUE := preload("res://scripts/skills/skill_catalogue.gd")
const SKILLS := CATALOGUE.SKILLS
const TREE := preload("res://scripts/skills/skill_tree.gd")
const CLASS_SKILLS := preload("res://scripts/skills/class_skills.gd")
const SPECIMEN := "res://data/specimens/forest_gnasher.tres"
## Saved enemy kind -> scene. Stable IDs only; never a client-supplied path.
const ENEMY_SCENES := {"gnasher": "res://scenes/enemies/forest_gnasher.tscn", "treasure_goblin": "res://scenes/enemies/forest_gnasher.tscn", "thornback": "res://scenes/enemies/thornback_gnasher.tscn",
    "frost_bear": "res://scenes/enemies/frost_bear.tscn", "snow_wisp": "res://scenes/enemies/snow_wisp.tscn", "dune_viper": "res://scenes/enemies/dune_viper.tscn", "sand_scuttler": "res://scenes/enemies/sand_scuttler.tscn", "bog_kappa": "res://scenes/enemies/bog_kappa.tscn", "mirecap": "res://scenes/enemies/mirecap.tscn", "bamboo_sprite": "res://scenes/enemies/bamboo_sprite.tscn", "paper_lantern": "res://scenes/enemies/paper_lantern.tscn", "amber_owl": "res://scenes/enemies/amber_owl.tscn", "burrow_mole": "res://scenes/enemies/burrow_mole.tscn", "ember_flame": "res://scenes/enemies/ember_flame.tscn", "salamander": "res://scenes/enemies/salamander.tscn",
    "raptor": "res://scenes/enemies/raptor.tscn", "tyrant_rex": "res://scenes/enemies/tyrant_rex.tscn", "gi_fighter": "res://scenes/enemies/gi_fighter.tscn", "monkey_brawler": "res://scenes/enemies/monkey_brawler.tscn", "android_scout": "res://scenes/enemies/android_scout.tscn", "bio_android": "res://scenes/enemies/bio_android.tscn", "android_tank": "res://scenes/enemies/android_tank.tscn", "demon_king": "res://scenes/enemies/demon_king.tscn",
    "storm_bat": "res://scenes/enemies/storm_bat.tscn", "gale_beast": "res://scenes/enemies/gale_beast.tscn", "cliff_lizard": "res://scenes/enemies/cliff_lizard.tscn", "thunder_eye": "res://scenes/enemies/thunder_eye.tscn", "dusk_spider": "res://scenes/enemies/dusk_spider.tscn", "fen_octopus": "res://scenes/enemies/fen_octopus.tscn", "shade_spirit": "res://scenes/enemies/shade_spirit.tscn", "fen_skull": "res://scenes/enemies/fen_skull.tscn", "crystal_cyclops": "res://scenes/enemies/crystal_cyclops.tscn", "sky_dragonling": "res://scenes/enemies/sky_dragonling.tscn", "peak_reptile": "res://scenes/enemies/peak_reptile.tscn", "frost_spirit": "res://scenes/enemies/frost_spirit.tscn"}
## M7a: raid bosses use one scene; their kind is their boss ID.
static func enemy_scene(kind: String) -> String:
    if preload("res://scripts/bosses/boss_catalogue.gd").is_boss(kind):
        return "res://scenes/enemies/raid_boss.tscn"
    return ENEMY_SCENES[kind]

static func known_kind(kind: Variant) -> bool:
    return kind is String and (ENEMY_SCENES.has(kind) or preload("res://scripts/bosses/boss_catalogue.gd").is_boss(kind))

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
    # Tree skills are not saved as known skills; they follow from the bought nodes.
    var known: Array = book.evidence_ids()
    var slots: Array = []
    for index in range(book.SLOT_COUNT):
        var skill: Resource = book.skill_at_slot(index)
        slots.append(String(skill.id) if skill else "")
    var counts: Dictionary = {}
    for entry in bag.entries():
        counts[String(entry.id)] = entry.count
    return {
        "id": actor.character_id, "position": vector(actor.position), "facing": vector(actor.facing),
        "move_speed": actor.move_speed,
        "death_left": actor.death_left,
        "form": {"id": actor.form, "cooldown": actor.form_cooldown},
        "exhaustion": {"active": actor.exhaustion_active, "remaining": actor.exhaustion_left},
        "health": {"maximum": health.maximum, "current": health.current, "immunity": health.immunity_left, "immunity_seconds": health.immunity_seconds, "regen_rate": health.regen_rate, "regen_left": health.regen_left, "regen_carry": health._regen_carry},
        "magicules": {"maximum": pool.maximum, "current": pool.current, "regen": pool.regeneration_per_second, "regen_delay": pool.regeneration_delay, "delay": pool._delay_left, "enabled": pool.enabled},
        "skill_ids": known, "slots": slots, "skill_evidence": book.evidence.duplicate(true), "inventory": {"capacity": bag.capacity, "counts": counts},
        "attack_recovery": actor.get_node("MeleeAttack").cooldown_left,
        "analysis": {"target": absorption._target.entity_id if absorption.active else "", "remaining": absorption.time_left, "focus": absorption.focus_left},
        "progression": actor.progression.duplicate(true),
        "gear": actor.gear.duplicate(true),
        # M4.5d: a cast line [seconds to the bite, bite window] (replicated for the HUD; a reload
        # cancels it).
        "fishing": [actor.fishing_bite_in, actor.fishing_window] if actor.fishing_bite_in != -INF else []
    }

## A guest's predicted position further than this from the host's jumps to the host's.
const PREDICTION_SNAP := 80.0

static func apply_player(actor: Node2D, state: Dictionary, world: Node2D, replica: bool) -> void:
    actor.character_id = state.id
    var host_position := to_vector(state.position)
    if replica and actor.local_controlled and actor.get("predicting"):
        # User report (lag for a connected player): a guest moves its own character at once
        # (prediction); the host's position only corrects it - at once when far off (a teleport,
        # a ferry, a knock-back), gently while standing still.
        var gap: float = actor.position.distance_to(host_position)
        if gap > PREDICTION_SNAP:
            actor.position = host_position
        elif actor.velocity.length() < 1.0:
            actor.position = host_position if gap < 1.0 else actor.position.lerp(host_position, 0.5)
    else:
        actor.position = host_position
        actor.facing = to_vector(state.facing)
    actor.move_speed = state.move_speed
    actor.apply_form(state.form.id)
    actor.form_cooldown = state.form.cooldown
    actor.progression = state.progression.duplicate(true)
    actor.exhaustion_active = state.exhaustion.active
    actor.exhaustion_left = state.exhaustion.remaining
    var health = actor.get_node("Health")
    health.maximum = int(state.health.maximum)
    health.current = int(state.health.current)
    actor.death_left = float(state.get("death_left", actor.RESPAWN_DELAY if health.current <= 0 else 0.0))
    health.immunity_left = state.health.immunity
    health.immunity_seconds = state.health.immunity_seconds
    health.regen_rate = state.health.regen_rate
    health.regen_left = state.health.regen_left
    # Always overwrite the fractional remainder so an existing actor cannot keep a stale one.
    health._regen_carry = state.health.regen_carry
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
    for id in TREE.granted_skills(state.progression.tree.nodes):
        book._known[StringName(id)] = load(TREE.SKILLS[id])
    # M12c: the main class's skills follow from the class and level.
    for id in CLASS_SKILLS.granted(state.progression):
        book._known[StringName(id)] = load(CLASS_SKILLS.SKILLS[id])
    for index in range(book.SLOT_COUNT):
        book._slots[index] = StringName(state.slots[index])
    book.evidence = CATALOGUE.empty_evidence()
    for kind in CATALOGUE.EVIDENCE_KINDS:
        for entry in state.skill_evidence[kind]:
            book.evidence[kind].append(String(entry))
    var bag = actor.get_node("Inventory")
    bag.capacity = int(state.inventory.capacity)
    bag._entries.clear()
    for id in state.inventory.counts:
        # Materials and (M4.5c/d) goods: consumables, scrolls, tickets, fish, runes, augments.
        bag.restore_stack(String(id), int(state.inventory.counts[id]))
    bag.changed.emit()
    actor.get_node("MeleeAttack").cooldown_left = state.attack_recovery
    var fishing: Array = state.get("fishing", [])
    actor.fishing_bite_in = float(fishing[0]) if replica and fishing.size() == 2 else -INF
    actor.fishing_window = float(fishing[1]) if replica and fishing.size() == 2 else 0.0
    # Saved maxima/regeneration already include equipped gear; only derived values are refreshed.
    actor.gear = state.gear.duplicate(true)
    actor.refresh_gear()
    var absorption = actor.get_node("Absorption")
    # Replicas show the channel. Reload/reconnect interrupts it without refunding cost.
    absorption._target = world.entity_by_id(state.analysis.target) if replica else null
    absorption.time_left = state.analysis.remaining if replica and absorption.active else 0.0
    # Replicas only see the remaining time; the race's normal channel length is a good display scale.
    absorption.channel_seconds = maxf(absorption.time_left, absorption.analysis_seconds * actor.race_stats().absorb_time)
    absorption.focus_left = state.analysis.focus
    actor.queue_redraw()

static func capture_entities(world: Node2D) -> Dictionary:
    var enemies: Array = []
    var pickups: Array = []
    var allies: Array = []
    var loot: Array = []
    var piles: Array = []
    for node in world.get_children():
        if node.is_queued_for_deletion():
            continue
        if node.is_in_group("enemies"):
            var health = node.get_node("Health")
            enemies.append({"id": node.entity_id, "kind": node.kind, "position": vector(node.position), "home": vector(node.home), "difficulty": node.difficulty, "hp": health.current, "maximum_hp": health.maximum, "immunity": health.immunity_left, "state": node.state, "state_time": node.state_time, "target": node.target.character_id if is_instance_valid(node.target) else "", "credit": node.credit.duplicate(), "group_scaled": node._group_scaled, "status": node.shown_status})
        elif node.is_in_group("gear_pickups"):
            loot.append({"id": node.entity_id, "position": vector(node.position), "item": node.item.duplicate(true), "owner": node.owner_id, "claim_until": node.claim_until, "since": node.since})
        elif node.is_in_group("magicule_pickups"):
            pickups.append({"id": node.entity_id, "position": vector(node.position), "amount": node.amount, "owner": node.owner_id, "claim_until": node.claim_until})
        elif node.is_in_group("item_piles"):
            piles.append(node.capture())
        elif node.is_in_group("allies"):
            allies.append({"id": node.entity_id, "position": vector(node.position), "owner": node.owner_id, "name": node.display_name, "race": node.race, "maximum_hp": node.maximum_hp, "power": node.power, "speed": node.follow_speed, "work": {"role": node.work_role, "target": node.work_target, "remaining": node.work_left}})
    return {"enemies": enemies, "pickups": pickups, "allies": allies, "camp": world.camp.state.duplicate(true), "trial": world.trial.state.duplicate(true), "respawns": world.respawner.capture(), "loot": loot, "piles": piles, "trade": world.trade.capture(), "harbours": world.harbours.capture(), "party": world.party.capture(), "realm": world.realm.capture(), "siege": world.siege.capture(), "exchange": world.exchange.capture() if world.get("exchange") != null else {}, "events": world.events.capture() if world.get("events") != null else {}, "guilds": world.guilds.capture() if world.get("guilds") != null else {}, "chat": world.chat.capture() if world.get("chat") != null else {}, "duels": world.duels.capture() if world.get("duels") != null else {}, "housing": world.housing.capture() if world.get("housing") != null else {}}

## `changed_enemies` (guests' delta snapshots): only these creature ids are re-applied; the others
## are unchanged since the last snapshot (null = apply every creature).
static func apply_entities(world: Node2D, data: Dictionary, replica: bool, changed_enemies: Variant = null) -> void:
    world.camp.restore(data.camp)
    world.trial.restore(data.get("trial"))
    if data.get("trade") is Dictionary:
        world.trade.restore(data.trade)
    if data.get("harbours") is Dictionary:
        world.harbours.restore(data.harbours)
    if data.get("party") is Dictionary:
        world.party.restore(data.party)
    # M14a: guilds (saved) and chat (snapshots only).
    if data.get("guilds") is Dictionary and not data.guilds.is_empty() and world.get("guilds") != null:
        world.guilds.restore(data.guilds)
    if replica and data.get("chat") is Dictionary and world.get("chat") != null:
        world.chat.restore(data.chat)
    # M16: houses and inn rooms (saved).
    if data.get("housing") is Dictionary and world.get("housing") != null:
        world.housing.restore(data.housing)
    # M15: running duels (snapshots only).
    if replica and data.get("duels") is Dictionary and world.get("duels") != null:
        world.duels.restore(data.duels)
    # M11c: open trades (snapshots only; never saved).
    if replica and data.get("exchange") is Dictionary and world.get("exchange") != null:
        world.exchange.restore(data.exchange)
    # M11d: a running world event (snapshots only; never saved).
    if replica and data.get("events") is Dictionary and world.get("events") != null:
        world.events.restore(data.events)
    if data.get("realm") is Dictionary:
        world.realm.restore(data.realm, replica)
    if data.get("siege") is Dictionary:
        world.siege.restore(data.siege, replica)
    world.respawner.restore(data.get("respawns", []))
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
        ally.work_role = state.work.role
        ally.work_target = state.work.target
        ally.work_left = state.work.remaining
        ally.set_physics_process(not replica)
        ally.queue_redraw()
    for state in data.enemies:
        wanted[state.id] = true
        if changed_enemies is Dictionary and not changed_enemies.has(state.id):
            continue
        var actor = world.entity_by_id(state.id)
        if actor == null:
            actor = load(enemy_scene(state.kind)).instantiate()
            actor.entity_id = state.id
            actor.difficulty = int(state.difficulty)
            world.add_child(actor)
            world.wire_enemy(actor)
        actor.position = to_vector(state.position)
        actor.home = to_vector(state.home)
        actor.difficulty = int(state.difficulty)
        actor.level = actor.REGION.level_of(actor.entity_id, actor.difficulty)
        actor.get_node("Health").maximum = int(state.maximum_hp)
        actor.get_node("Health").current = int(state.hp)
        actor.restore_stats()
        actor.credit = state.get("credit", {}).duplicate()
        actor.shown_status = String(state.get("status", ""))
        actor._group_scaled = bool(state.get("group_scaled", state.maximum_hp > actor.scaled_health(actor.difficulty, actor.level)))
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
        pickup.owner_id = String(state.get("owner", ""))
        pickup.claim_until = float(state.get("claim_until", 0.0))
        pickup.set_physics_process(not replica)
    for state in data.get("loot", []):
        wanted[state.id] = true
        var lying = world.entity_by_id(state.id)
        if lying == null:
            lying = world.drop_gear(state.item, to_vector(state.position), state.id, String(state.get("owner", "")), float(state.get("claim_until", 0.0)))
        if lying != null:
            lying.owner_id = String(state.get("owner", ""))
            lying.claim_until = float(state.get("claim_until", 0.0))
            lying.since = float(state.get("since", lying.since))
            lying.position = to_vector(state.position)
            lying.set_physics_process(not replica)
            lying.queue_redraw()
    for state in data.get("piles", []):
        wanted[state.id] = true
        var pile = world.entity_by_id(state.id)
        if pile == null:
            pile = world.drop_pile(state.owner, state.materials, state.items, to_vector(state.position), state.id, float(state.claim_until), int(state.get("zeni", 0)))
        if pile != null:
            pile.materials = state.materials.duplicate()
            pile.items = state.items.duplicate(true)
            pile.gone_at = float(state.get("gone_at", 0.0))
            pile.position = to_vector(state.position)
            pile.set_physics_process(not replica)
            pile.queue_redraw()
    for node in world.get_children():
        if (node.is_in_group("enemies") or node.is_in_group("magicule_pickups") or node.is_in_group("allies") or node.is_in_group("gear_pickups") or node.is_in_group("item_piles")) and not wanted.has(node.entity_id):
            world.remove_child(node)
            node.queue_free()
