extends Node
## Sound and effect cues for the world (step 23). Runs on every peer and reacts to *observed state
## changes* — a creature's or character's HP dropping, a recovery timer jumping (an attack), a
## pickup vanishing next to someone, a level, skill, chest, form, evolution or building appearing
## — instead of network events. Retried requests and repeated snapshots therefore never repeat
## a cue: the same state seen twice is not a change. The first observation of an entity (joining,
## loading, respawning) only sets the baseline.
##
## Replicas also get their attack frame here: `attack_recovery` is replicated, so a jump in it
## means that character just attacked, and the local flash timer drives player.gd's attack pose.
const EFFECTS := preload("res://scripts/visual/effects.gd")
const MAP := preload("res://scripts/world/world_map.gd")
## Region → music track (assets/game/audio/music).
const REGION_MUSIC := {
    MAP.Region.CLEARING: "clearing", MAP.Region.VERDANT: "verdant", MAP.Region.THORNWOOD: "thornwood",
    MAP.Region.MIRROR_LAKE: "mirror_lake", MAP.Region.CINDER_CRATER: "cinder_crater", MAP.Region.HARROWMERE: "harrowmere",
    MAP.Region.SEA: "sea", MAP.Region.AMBERVALE: "verdant", MAP.Region.EMBERREACH: "cinder_crater",
}
## Things only the local character hears (others see the effect).
const PICKUP_RADIUS := 40.0

var world: Node2D
var audio: Node
## Per entity: last observed values.
var _seen: Dictionary = {}
var _pickups: Dictionary = {}
var _camp: Dictionary = {}
var _aura: AnimatedSprite2D
var _was_analyzing := false

func _ready() -> void:
    name = "Presentation"
    process_mode = Node.PROCESS_MODE_PAUSABLE
    audio = get_node_or_null("/root/Audio")

func _process(delta: float) -> void:
    if world == null or not is_instance_valid(world.get_local_player()):
        return
    var me: CharacterBody2D = world.get_local_player()
    for node in world.get_children():
        if node.is_queued_for_deletion():
            continue
        if node.is_in_group("enemies"):
            _creature(node)
        elif node is CharacterBody2D and node.has_method("race"):
            _character(node, node == me, delta)
        elif node.is_in_group("allies"):
            _ally(node)
    _pickups_changed(me)
    _camp_changed()
    _analysis(me)
    _music(me)

func _cue(id: String, at: Variant = null) -> void:
    if audio != null:
        audio.play(id, at)

func _creature(node: Node2D) -> void:
    var hp: int = node.get_node("Health").current
    var key: String = "enemy:" + node.entity_id
    if _seen.has(key) and hp < _seen[key]:
        EFFECTS.spawn(world, "hit_spark", node.position + Vector2(0, -6))
        _cue("hit", node.position)
        if hp <= 0:
            EFFECTS.spawn(world, "smoke", node.position + Vector2(0, -4))
            _cue("defeat", node.position)
    # A creature's bite: its wind-up ends in an attack (claw at the target side).
    var state: int = node.state
    var state_key := key + ":state"
    if _seen.has(state_key) and _seen[state_key] == node.State.WINDUP and state != node.State.WINDUP and hp > 0 and is_instance_valid(node.target):
        var toward: Vector2 = node.position.direction_to(node.target.position)
        EFFECTS.spawn(world, "claw", node.position + toward * 14.0, toward.angle())
    _seen[key] = hp
    _seen[state_key] = state

func _character(actor: CharacterBody2D, local: bool, delta: float) -> void:
    var key: String = "player:" + actor.character_id
    var hp: int = actor.get_node("Health").current
    var attack: Node = actor.get_node("MeleeAttack")
    # Replica combat timers are disabled. Tick only the cosmetic pose here;
    # recovery and all gameplay state remain owned by the host/snapshots.
    if not attack.is_processing():
        attack.flash_left = maxf(0.0, attack.flash_left - delta)
    var recovery: float = attack.cooldown_left
    var level: int = int(actor.progression.get("level", 1))
    var skills: int = actor.get_node("SkillBook").known_ids().size()
    var chests: int = actor.progression.get("chests", []).size()
    var form: String = String(actor.form)
    var exhausted: bool = actor.exhaustion_active
    if _seen.has(key):
        var last: Dictionary = _seen[key]
        if hp < last.hp and hp >= 0:
            EFFECTS.spawn(world, "hit_spark", actor.position + Vector2(0, -6))
            _cue("hurt" if local else "hit", actor.position)
            if hp == 0 and local:
                _cue("game_over")
        # An attack: the recovery timer jumped up (replicated for other characters).
        if recovery > last.recovery + 0.05:
            if attack.flash_left <= 0.0:
                attack.flash_left = 0.12
            var weapon: Dictionary = actor.equipped_weapon()
            var bow: bool = not weapon.is_empty() and actor.GEAR.BASES[weapon.base].get("weapon") == "bow"
            if not bow:
                EFFECTS.spawn(world, "slash", actor.position + actor.facing.normalized() * 16.0, actor.facing.angle())
            elif not attack.is_processing() and actor.facing != Vector2.ZERO:
                # A replica's shot: the host's arrow is not replicated, so show a cosmetic one.
                attack.spawn_arrow(actor, actor.facing, 0, true)
            _cue("bow" if bow else "swing", actor.position)
        if level > last.level:
            EFFECTS.spawn(world, "boost", actor.position + Vector2(0, -10))
            _cue("level_up" if local else "learned", null if local else actor.position)
        if skills > last.skills:
            EFFECTS.spawn(world, "ring", actor.position + Vector2(0, -6))
            if local:
                _cue("learned")
        if chests > last.chests:
            EFFECTS.spawn(world, "sparkle", actor.position + Vector2(0, -12))
            if local:
                _cue("chest")
        if form != last.form:
            EFFECTS.spawn(world, "smoke", actor.position)
            _cue("form", actor.position)
        if exhausted and not last.exhausted and local:
            _cue("exhausted")
    _seen[key] = {"hp": hp, "recovery": recovery, "level": level, "skills": skills, "chests": chests, "form": form, "exhausted": exhausted}

func _ally(node: Node2D) -> void:
    var key: String = "ally:" + node.entity_id
    if _seen.has(key) and _seen[key] != node.race and node.race == "Hobgoblin":
        EFFECTS.spawn(world, "boost", node.position + Vector2(0, -12))
        _cue("evolve")
    _seen[key] = node.race

## Pickups that vanish next to a character were collected (not when a snapshot removes them far away).
func _pickups_changed(me: Node2D) -> void:
    var now: Dictionary = {}
    for node in get_tree().get_nodes_in_group("magicule_pickups") + get_tree().get_nodes_in_group("gear_pickups"):
        if node.is_inside_tree() and not node.is_queued_for_deletion():
            now[node.entity_id] = [node.position, node.is_in_group("gear_pickups")]
    for id in _pickups:
        if now.has(id):
            continue
        var spot: Vector2 = _pickups[id][0]
        var near := false
        for node in world.get_children():
            if node is CharacterBody2D and node.has_method("race") and node.position.distance_to(spot) <= PICKUP_RADIUS:
                near = true
        if near:
            EFFECTS.spawn(world, "sparkle", spot + Vector2(0, -6))
            if me.position.distance_to(spot) <= PICKUP_RADIUS:
                _cue("item" if _pickups[id][1] else "magicules")
    _pickups = now

func _camp_changed() -> void:
    var camp: Node2D = world.camp
    var built: Dictionary = {}
    for id in camp.STRUCTURES:
        built[id] = bool(camp.state.get(camp.STRUCTURES[id].key, false))
    var deposits: Dictionary = camp.state.deposits.duplicate()
    if not _camp.is_empty():
        for id in built:
            if built[id] and not _camp.built.get(id, false):
                EFFECTS.spawn(world, "ring", camp.STRUCTURES[id].site)
                _cue("build", camp.STRUCTURES[id].site)
        for id in deposits:
            if deposits[id] == 0 and int(_camp.deposits.get(id, 0)) > 0:
                _cue("gather", camp.sites[id].position)
        if bool(camp.state.founded) and not bool(_camp.founded):
            EFFECTS.spawn(world, "ring", camp.SITE)
            _cue("build", camp.SITE)
    _camp = {"built": built, "deposits": deposits, "founded": camp.state.founded}

## The local character's analysis: a sound when it starts, an aura on the target meanwhile.
func _analysis(me: Node2D) -> void:
    var absorption: Node = me.get_node("Absorption")
    var active: bool = absorption.active and is_instance_valid(absorption._target)
    if active and not _was_analyzing:
        _cue("analysis", me.position)
        _aura = EFFECTS.spawn(world, "aura", absorption._target.position + Vector2(0, -4), 0.0, true)
    if not active and is_instance_valid(_aura):
        _aura.queue_free()
    _was_analyzing = active

func _music(me: Node2D) -> void:
    if audio == null:
        return
    var trial: Dictionary = world.trial.state
    audio.music("trial" if trial.get("active", false) else REGION_MUSIC.get(MAP.region_at(me.position), "verdant"))
