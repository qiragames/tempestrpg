extends Node2D
const AUTHORITY := preload("res://scripts/network/authority.gd")
## A directional strike checks both range and world obstruction.

@export var damage: int = 10
@export var cooldown: float = 0.4
@export var magicule_cost: float = 8.0
var cooldown_left: float = 0.0
var flash_left: float = 0.0
var direction := Vector2.DOWN
var flash_effect: StringName = &"strike"
## Piercing thrust: a narrow line in front of the attacker that hits every creature inside it.
const PIERCE_LENGTH := 64.0
const PIERCE_WIDTH := 14.0
## Weapon shapes (17f).
const SPEAR_LENGTH := 52.0
const SPEAR_WIDTH := 10.0
const SWORD_RADIUS := 20.0
const SCYTHE_RADIUS := 30.0
const BOW_RANGE := 200.0
const BASIC_EFFECTS := [&"strike", &"dagger", &"sword", &"spear", &"scythe", &"bow"]
## Daggers (item expansion): a small, quick stab right in front.
const DAGGER_RADIUS := 11.0
const SKILL_EFFECTS := preload("res://scripts/skills/skill_effects.gd")
## The skill whose utility effects the current strike applies ("" for basic strikes).
var _skill_id: String = ""
## The last beam's shape and colour (presentation).
var _flash_length := PIERCE_LENGTH
var _flash_width := 3.0
var _flash_color := Color("c9f6df")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
## Where the last bow shot ended (for the flash).
var shot_end := Vector2.ZERO

func _process(delta: float) -> void:
    if not AUTHORITY.can_mutate(self):
        return
    cooldown_left = maxf(0.0, cooldown_left - delta)
    flash_left = maxf(0.0, flash_left - delta)
    queue_redraw()

## Race modifiers of the attacking character (none for other attackers).
func _race() -> Dictionary:
    return get_parent().race_stats() if get_parent().has_method("race_stats") else {"strike_damage": damage, "strike_cost": magicule_cost, "strike_bonus": 0, "recovery": 1.0, "skill_bonus": 0.0, "drain": 0.0}

## The basic strike's Magicule cost for this attacker (by race, 24b).
## M4.7: a transformation multiplies strike and skill damage.
func _aura() -> float:
    return get_parent().aura_damage() if get_parent().has_method("aura_damage") else 1.0

## Item expansion: the wielded weapon's element (Rare and up) acts on its basic hits.
const ELEMENTS := preload("res://scripts/items/element_catalogue.gd")
const EFFECTS := preload("res://scripts/visual/effects.gd")
var _element_rng := RandomNumberGenerator.new()

func weapon_element() -> Array:
    var weapon: Dictionary = get_parent().equipped_weapon() if get_parent().has_method("equipped_weapon") else {}
    if weapon.is_empty():
        return ["", 0]
    return [String(GEAR.BASES[weapon.base].get("element", "")), int(weapon.rarity)]

## Shadow weapons sometimes strike twice as hard (decided before the hit).
func element_damage(value: int) -> int:
    var element := weapon_element()
    var effect: Dictionary = ELEMENTS.on_hit(element[0], element[1], value)
    if effect.has("crit") and _element_rng.randf() < float(effect.crit):
        return value * 2
    return value

## After a weapon hit on `target` (dealt damage): statuses on the creature, healing, Magicules,
## lightning to one more creature, and a burst in the element's colour.
func element_hit(target: Node2D, dealt: int, already: Array = []) -> void:
    var element := weapon_element()
    if String(element[0]).is_empty() or dealt <= 0 or not AUTHORITY.can_mutate(self):
        return
    var effect: Dictionary = ELEMENTS.on_hit(element[0], element[1], dealt)
    var status := {}
    for key in ["dot", "slow"]:
        if effect.has(key):
            status[key] = effect[key]
    if not status.is_empty() and is_instance_valid(target) and target.has_method("apply_status"):
        target.apply_status(status, get_parent())
    if effect.has("heal"):
        get_parent().get_node("Health").heal(maxi(1, int(round(dealt * float(effect.heal)))))
    if effect.has("magicules"):
        get_parent().get_node("Magicules").restore(float(effect.magicules))
    var world: Node = get_parent().get_parent()
    if effect.has("chain") and world != null and is_instance_valid(target):
        var best: Node2D = null
        var distance := ELEMENTS.CHAIN_REACH
        for creature in get_tree().get_nodes_in_group("enemies"):
            if creature == target or creature in already or creature.get_node("Health").current <= 0:
                continue
            var gap: float = creature.global_position.distance_to(target.global_position)
            if gap < distance:
                best = creature
                distance = gap
        if best != null:
            best.get_node("Health").take_damage(int(effect.chain), get_parent(), true)
            _bolt(target.global_position, best.global_position, ELEMENTS.color(element[0]))
    if is_instance_valid(target) and world != null:
        var burst := EFFECTS.spawn(world, "hit_spark", target.global_position + Vector2(0, -4))
        if burst != null:
            burst.modulate = ELEMENTS.color(element[0]).lightened(0.2)
            burst.scale = Vector2.ONE * (0.6 + 0.15 * int(element[1]))

## A short lightning line between two creatures (storm).
func _bolt(from: Vector2, to: Vector2, colour: Color) -> void:
    var world: Node = get_parent().get_parent()
    var line := Line2D.new()
    line.width = 1.5
    line.default_color = colour
    line.z_index = 6
    var points := PackedVector2Array([from])
    for step in range(1, 4):
        points.append(from.lerp(to, step / 4.0) + Vector2(_element_rng.randf_range(-4, 4), _element_rng.randf_range(-4, 4)))
    points.append(to)
    line.points = points
    world.add_child(line)
    world.get_tree().create_timer(0.15).timeout.connect(line.queue_free)

func strike_cost() -> float:
    return float(_race().get("strike_cost", magicule_cost))

func attack(facing: Vector2) -> bool:
    # Mimic forms and Human weapon mastery strengthen the basic strike; skills keep their own damage.
    var bonus: int = get_parent().form_strike_bonus() if get_parent().has_method("form_strike_bonus") else 0
    bonus += get_parent().tree_strike_bonus() if get_parent().has_method("tree_strike_bonus") else 0
    bonus += int(get_parent().gear_bonus("strike")) if get_parent().has_method("gear_bonus") else 0
    var race := _race()
    # An equipped weapon replaces the unarmed damage and sets the attack's shape and timing.
    var weapon: Dictionary = get_parent().equipped_weapon() if get_parent().has_method("equipped_weapon") else {}
    if weapon.is_empty():
        return _strike(facing, int(round((int(race.get("strike_damage", damage)) + bonus + race.strike_bonus) * _aura())), strike_cost(), cooldown * race.recovery)
    var kind: String = GEAR.BASES[weapon.base].weapon
    return _strike(facing, element_damage(int(round((int(weapon.stats.damage) + bonus + race.strike_bonus) * _aura()))), strike_cost(), GEAR.WEAPONS[kind].recovery * race.recovery, StringName(kind))

func attack_skill(facing: Vector2, skill_id: StringName) -> bool:
    var book = get_parent().get_node("SkillBook")
    var skill: Resource = book.get_skill(skill_id)
    # Learned skills must be activated in the skill tree before use.
    if skill == null or not book.is_active(skill_id):
        return false
    # Effects are dispatched by stable ID; new effect types are added here deliberately.
    # Demons hit harder with skills and drain part of the damage; Humans recover faster.
    var race := _race()
    var keen: float = 0.1 if get_parent().has_method("gear_passive") and get_parent().gear_passive("keen") else 0.0
    var power := int(round(skill.damage * (1.0 + race.skill_bonus + keen) * _aura()))
    _flash_length = PIERCE_LENGTH
    _flash_width = 3.0
    _flash_color = Color("c9f6df")
    var fx: Dictionary = SKILL_EFFECTS.effects(String(skill_id))
    var drain: float = race.drain + float(fx.get("drain", 0.0))
    var done := false
    _skill_id = String(skill_id)
    match skill.effect:
        &"strike":
            done = _strike(facing, power, skill.magicule_cost, skill.cooldown * race.recovery, &"strike", drain)
        &"pierce":
            done = _strike(facing, power, skill.magicule_cost, skill.cooldown * race.recovery, &"pierce", drain)
        &"focus":
            done = _focus(skill)
    _skill_id = ""
    return done

## Predator Focus arms the next analysis; it cannot stack while already armed.
func _focus(skill: Resource) -> bool:
    var absorption = get_parent().get_node("Absorption")
    if not AUTHORITY.can_mutate(self) or cooldown_left > 0.0 or absorption.focus_left > 0.0:
        return false
    if get_parent().get_node("Health").current <= 0 or get_parent().is_exhausted():
        return false
    if not get_parent().get_node("Magicules").try_spend(skill.magicule_cost):
        return false
    cooldown_left = skill.cooldown
    absorption.focus_left = absorption.FOCUS_SECONDS
    absorption.status_changed.emit("Predator Focus: your next analysis within 20s reaches twice as far and completes almost instantly.")
    return true

func _strike(facing: Vector2, strike_damage: int, cost: float, recovery: float, effect: StringName = &"strike", drain: float = 0.0) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    if cooldown_left > 0.0 or get_parent().get_node("Health").current <= 0 or get_parent().is_exhausted():
        return false
    # Free strikes (Humans, 24b) spend nothing and do not delay regeneration.
    if cost > 0.0 and not get_parent().get_node("Magicules").try_spend(cost):
        return false
    direction = facing.normalized()
    cooldown_left = recovery
    # M4.5d: attacking from the saddle dismounts.
    if get_parent().has_method("dismount"):
        get_parent().dismount()
    flash_left = 0.12
    flash_effect = effect
    if effect == &"bow":
        return _shoot(strike_damage)
    var fx: Dictionary = SKILL_EFFECTS.effects(_skill_id)
    # Lunge-style skills move the caster forward first (stopped by walls and creatures).
    if fx.has("dash") and get_parent() is CharacterBody2D:
        get_parent().move_and_collide(direction * float(fx.dash))
    var query := PhysicsShapeQueryParameters2D.new()
    var reach_dot := 0.25
    if effect == &"spear":
        var shaft := RectangleShape2D.new()
        shaft.size = Vector2(SPEAR_LENGTH, SPEAR_WIDTH)
        query.shape = shaft
        query.transform = Transform2D(direction.angle(), global_position + direction * (SPEAR_LENGTH / 2.0 + 4.0))
    elif effect == &"dagger":
        var stab := CircleShape2D.new()
        stab.radius = DAGGER_RADIUS
        query.shape = stab
        query.transform = Transform2D(0.0, global_position + direction * 15.0)
        reach_dot = 0.5
    elif effect == &"sword":
        var arc := CircleShape2D.new()
        arc.radius = SWORD_RADIUS
        query.shape = arc
        query.transform = Transform2D(0.0, global_position + direction * 20.0)
    elif effect == &"scythe":
        var sweep := CircleShape2D.new()
        sweep.radius = SCYTHE_RADIUS
        query.shape = sweep
        query.transform = Transform2D(0.0, global_position + direction * 10.0)
        reach_dot = -0.3
    elif effect == &"pierce":
        # M4.7: ki beams set their own reach and width.
        var length: float = float(fx.get("reach", PIERCE_LENGTH))
        var line := RectangleShape2D.new()
        line.size = Vector2(length, float(fx.get("width", PIERCE_WIDTH)))
        query.shape = line
        query.transform = Transform2D(direction.angle(), global_position + direction * (length / 2.0 + 4.0))
        _flash_length = length
        _flash_width = float(fx.get("width", 3.0))
        _flash_color = Color(String(fx.get("color", "c9f6df")))
    else:
        var circle := CircleShape2D.new()
        circle.radius = float(fx.get("area", 16.0))
        query.shape = circle
        query.transform = Transform2D(0.0, global_position + direction * 18.0)
        if fx.has("area"):
            reach_dot = -1.0
    query.collision_mask = 4
    var space := get_world_2d().direct_space_state
    var dealt := 0
    var hits := 0
    var struck: Array = []
    for hit in space.intersect_shape(query):
        var target: Node2D = hit.collider
        var offset := target.global_position - global_position
        if offset.normalized().dot(direction) < reach_dot:
            continue
        var sight := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
        if space.intersect_ray(sight).is_empty() and target.has_node("Health"):
            var before: int = target.get_node("Health").current
            if target.get_node("Health").take_damage(strike_damage, get_parent()):
                dealt += before - target.get_node("Health").current
                hits += 1
                struck.append(target)
                if effect in BASIC_EFFECTS and effect != &"strike":
                    element_hit(target, before - target.get_node("Health").current, struck)
                if not fx.is_empty() and target.has_method("apply_status"):
                    target.apply_status(fx, get_parent())
    if drain > 0.0 and dealt > 0:
        get_parent().get_node("Health").heal(int(round(dealt * drain)))
    # Lifesteal gear: basic strikes heal 1 HP per creature hit.
    if effect in BASIC_EFFECTS and drain == 0.0 and hits > 0 and get_parent().has_method("gear_passive") and get_parent().gear_passive("lifesteal"):
        get_parent().get_node("Health").heal(hits)
    return true

## Bow: the first thing in line of sight up to BOW_RANGE takes the hit (terrain stops the shot).
## Bow (24a): a flying arrow does the hit when it arrives (see Arrow).
func _shoot(shot_damage: int) -> bool:
    spawn_arrow(get_parent(), direction, shot_damage, false, self)
    return true

## Launch an arrow from `shooter` into the world. Cosmetic arrows only fly (clients' view of
## other characters' shots).
static func spawn_arrow(shooter: Node2D, toward: Vector2, shot_damage: int, cosmetic: bool, attack: Node = null) -> Node2D:
    var world: Node = shooter.get_parent()
    if world == null:
        return null
    var arrow: Node2D = preload("res://scripts/combat/arrow.gd").new()
    arrow.direction = toward.normalized()
    arrow.damage = shot_damage
    arrow.shooter = shooter
    arrow.attack = attack
    arrow.cosmetic = cosmetic
    arrow.position = shooter.position + arrow.direction * 6.0
    world.add_child(arrow)
    return arrow

func _draw() -> void:
    var tint := Color("f4e2b8")
    if flash_left > 0.0 and flash_effect == &"bow":
        # The arrow itself flies (Arrow); only a short release flash here.
        draw_line(direction * 4.0, direction * 10.0, tint, 1.0)
    elif flash_left > 0.0 and flash_effect == &"spear":
        draw_line(direction * 6.0, direction * (SPEAR_LENGTH + 4.0), tint, 2.0)
    elif flash_left > 0.0 and flash_effect == &"dagger":
        draw_line(direction * 6.0, direction * 22.0, tint, 2.0)
        draw_arc(direction * 15.0, DAGGER_RADIUS * 0.7, direction.angle() - 0.6, direction.angle() + 0.6, 8, tint, 2.0)
    elif flash_left > 0.0 and flash_effect == &"sword":
        draw_arc(direction * 20.0, SWORD_RADIUS, direction.angle() - 1.1, direction.angle() + 1.1, 12, tint, 3.0)
    elif flash_left > 0.0 and flash_effect == &"scythe":
        draw_arc(direction * 10.0, SCYTHE_RADIUS, direction.angle() - 1.9, direction.angle() + 1.9, 18, tint, 3.0)
    elif flash_left > 0.0 and flash_effect == &"pierce":
        draw_line(direction * 6.0, direction * (_flash_length + 4.0), Color(_flash_color, 0.45), maxf(3.0, _flash_width))
        draw_line(direction * 6.0, direction * (_flash_length + 4.0), Color(1, 1, 1, 0.9), maxf(1.0, _flash_width * 0.35))
    elif flash_left > 0.0:
        draw_arc(direction * 18.0, 16.0, direction.angle() - 1.0, direction.angle() + 1.0, 10, Color("c9f6df"), 3.0)
