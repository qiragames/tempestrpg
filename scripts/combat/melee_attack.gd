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
const BASIC_EFFECTS := [&"strike", &"sword", &"spear", &"scythe", &"bow"]
const SKILL_EFFECTS := preload("res://scripts/skills/skill_effects.gd")
## The skill whose utility effects the current strike applies ("" for basic strikes).
var _skill_id: String = ""
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
        return _strike(facing, int(race.get("strike_damage", damage)) + bonus + race.strike_bonus, strike_cost(), cooldown * race.recovery)
    var kind: String = GEAR.BASES[weapon.base].weapon
    return _strike(facing, int(weapon.stats.damage) + bonus + race.strike_bonus, strike_cost(), GEAR.WEAPONS[kind].recovery * race.recovery, StringName(kind))

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
    var power := int(round(skill.damage * (1.0 + race.skill_bonus + keen)))
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
        var line := RectangleShape2D.new()
        line.size = Vector2(PIERCE_LENGTH, PIERCE_WIDTH)
        query.shape = line
        query.transform = Transform2D(direction.angle(), global_position + direction * (PIERCE_LENGTH / 2.0 + 4.0))
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
    elif flash_left > 0.0 and flash_effect == &"sword":
        draw_arc(direction * 20.0, SWORD_RADIUS, direction.angle() - 1.1, direction.angle() + 1.1, 12, tint, 3.0)
    elif flash_left > 0.0 and flash_effect == &"scythe":
        draw_arc(direction * 10.0, SCYTHE_RADIUS, direction.angle() - 1.9, direction.angle() + 1.9, 18, tint, 3.0)
    elif flash_left > 0.0 and flash_effect == &"pierce":
        draw_line(direction * 6.0, direction * (PIERCE_LENGTH + 4.0), Color("e8dcc0"), 3.0)
        draw_line(direction * 6.0, direction * (PIERCE_LENGTH + 4.0), Color("c9f6df"), 1.0)
    elif flash_left > 0.0:
        draw_arc(direction * 18.0, 16.0, direction.angle() - 1.0, direction.angle() + 1.0, 10, Color("c9f6df"), 3.0)
