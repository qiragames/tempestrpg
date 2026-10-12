extends Node2D
## PLACEHOLDER STORY: a neutral "Proving Trial" at a stone in the north. Re-theme names, text and
## look once the user's storyline exists; the rules below are the gameplay contract.
##
## A character who knows the required Extra skill starts the trial at the stone. Three trial
## creatures appear; the starter must survive and stay in the arena until all are defeated within
## the time limit. Anyone may help, but only the starter is credited (personal evidence). Trial
## creatures drop nothing and cannot be analyzed. A running trial is not saved: a host restart
## cancels it and the starter may simply begin again.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const CREATURE := preload("res://scenes/enemies/forest_gnasher.tscn")
const ID := "proving_trial"
const DISPLAY_NAME := "Proving Trial"
const REQUIRED_SKILL := &"piercing_fang"
const STONE := Vector2(480, 100)
const START_RANGE := 40.0
const ARENA_RADIUS := 150.0
const DURATION := 60.0
const SPAWNS: Array[Vector2] = [Vector2(-70, 40), Vector2(0, 70), Vector2(70, 40)]
## Replicated runtime state; never written to world saves.
var state: Dictionary = idle_state()

static func idle_state() -> Dictionary:
    return {"active": false, "owner": "", "time_left": 0.0, "remaining": 0}

func restore(value: Variant) -> void:
    state = value.duplicate(true) if value is Dictionary else idle_state()
    queue_redraw()

func near(actor: Node2D) -> bool:
    return actor.global_position.distance_to(STONE) <= START_RANGE

func creatures() -> Array:
    return get_tree().get_nodes_in_group("trial_creatures").filter(func(node): return not node.is_queued_for_deletion())

## Why the actor cannot start right now, or "" when it can.
func start_problem(actor: Node2D) -> String:
    if state.active:
        return "The trial is already in progress."
    if actor.get_node("Health").current <= 0 or actor.is_exhausted():
        return "Recover before attempting the trial."
    if not near(actor):
        return "Stand at the trial stone to begin."
    if ID in actor.get_node("SkillBook").evidence.trials:
        return "You have already completed the %s." % DISPLAY_NAME
    if not actor.get_node("SkillBook").knows(REQUIRED_SKILL):
        return "The stone stays silent. Master an Extra skill first."
    return ""

func try_start(actor: Node2D) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    var problem := start_problem(actor)
    var session := get_node("/root/GameSession")
    if not problem.is_empty():
        session.notify_character(actor.character_id, problem)
        return false
    state = {"active": true, "owner": actor.character_id, "time_left": DURATION, "remaining": SPAWNS.size()}
    var world := get_parent()
    for index in range(SPAWNS.size()):
        var creature = CREATURE.instantiate()
        creature.entity_id = "trial_%d" % index
        creature.difficulty = 0
        creature.specimen = null
        creature.drops_rewards = false
        creature.position = STONE + SPAWNS[index]
        creature.add_to_group("trial_creatures")
        world.add_child(creature)
        world.wire_enemy(creature)
    session.notify_character(actor.character_id, "%s begun: defeat 3 creatures within 60 seconds. Stay inside the circle." % DISPLAY_NAME)
    queue_redraw()
    return true

func _physics_process(delta: float) -> void:
    if not state.active or not AUTHORITY.can_mutate(self):
        return
    state.time_left = maxf(0.0, state.time_left - delta)
    var alive := creatures().filter(func(node): return node.get_node("Health").current > 0)
    state.remaining = alive.size()
    var owner = get_parent().player_by_id(state.owner)
    if owner == null:
        _finish(false, "")
    elif owner.get_node("Health").current <= 0:
        _finish(false, "Trial failed: you were defeated.")
    elif owner.global_position.distance_to(STONE) > ARENA_RADIUS:
        _finish(false, "Trial failed: you left the circle.")
    elif alive.is_empty():
        _finish(true, "")
    elif state.time_left <= 0.0:
        _finish(false, "Trial failed: time ran out.")

func _finish(success: bool, message: String) -> void:
    var owner_id: String = state.owner
    var owner = get_parent().player_by_id(owner_id)
    for creature in creatures():
        get_parent().remove_child(creature)
        creature.queue_free()
    state = idle_state()
    var session := get_node("/root/GameSession")
    if success and owner != null:
        # Only the starter is credited; helpers and reconnecting guests gain nothing.
        var gained: Array = owner.get_node("SkillBook").record_trial(ID)
        var names: Array = gained.map(func(skill): return "%s: %s" % [skill.tier, skill.display_name])
        session.notify_character(owner_id, "%s complete.%s" % [DISPLAY_NAME, " %s acquired." % ", ".join(names) if not names.is_empty() else ""])
    elif not message.is_empty():
        session.notify_character(owner_id, message)
    session.queue_save()
    queue_redraw()

func _draw() -> void:
    # Placeholder stone and arena circle.
    draw_arc(STONE, ARENA_RADIUS, 0, TAU, 48, Color(0.9, 0.8, 0.45, 0.35 if state.active else 0.12), 1)
    draw_rect(Rect2(STONE - Vector2(8, 14), Vector2(16, 20)), Color("6d6f78"))
    draw_rect(Rect2(STONE - Vector2(6, 12), Vector2(12, 3)), Color("9c9fa8"))
    draw_circle(STONE + Vector2(0, -3), 2.5, Color("f0d27a") if state.active else Color("b9a46a"))
