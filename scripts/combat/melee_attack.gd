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
    if dealt <= 0 or not AUTHORITY.can_mutate(self):
        return
    _unique_hit(target, dealt, already)
    if String(element[0]).is_empty():
        return
    var boost: float = SETS.element_factor(get_parent().equipped_items(), GEAR.BASES, element[0]) if get_parent().has_method("equipped_items") else 1.0
    var effect: Dictionary = ELEMENTS.on_hit(element[0], element[1], dealt, boost)
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
        for creature in get_tree().get_nodes_in_group("enemies").filter(func(node): return not (node.has_method("dormant") and node.dormant())):
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

## --- Unique abilities (item expansion part 3)
const SETS := preload("res://scripts/items/set_catalogue.gd")
var _unique_hits := 0

func weapon_ability() -> String:
    var weapon: Dictionary = get_parent().equipped_weapon() if get_parent().has_method("equipped_weapon") else {}
    return "" if weapon.is_empty() else String(GEAR.BASES[weapon.base].get("unique", ""))

## Executioner doubles the hit on a weakened creature (decided per target before the hit).
func ability_damage(target: Node2D, value: int) -> int:
    if weapon_ability() == "executioner" and target.has_node("Health") and target.get_node("Health").current < target.get_node("Health").maximum * 0.3:
        return value * 2
    # M9d: the Eclipse Sovereign's reaper hits far harder at night.
    if weapon_ability() == "sovereign" and _is_night():
        return int(round(value * SETS.SOVEREIGN_NIGHT))
    return value

func _is_night() -> bool:
    var world: Node = get_parent().get_parent()
    return world != null and world.get("progression") != null and preload("res://scripts/world/day_night.gd").is_night(float(world.progression.get("world_time", 0.0)))

func _creatures_near(at: Vector2, reach: float, skip: Array) -> Array:
    return get_tree().get_nodes_in_group("enemies").filter(func(node): return not node in skip and not node.is_queued_for_deletion() and not (node.has_method("dormant") and node.dormant()) and node.get_node("Health").current > 0 and node.global_position.distance_to(at) <= reach)

func _unique_hit(target: Node2D, dealt: int, already: Array) -> void:
    var ability := weapon_ability()
    if ability.is_empty():
        return
    _unique_hits += 1
    var owner: Node2D = get_parent()
    var killed: bool = is_instance_valid(target) and target.get_node("Health").current <= 0
    var at: Vector2 = target.global_position if is_instance_valid(target) else owner.global_position
    var colour := ELEMENTS.color(weapon_element()[0])
    match ability:
        "radiance":
            var share: int = maxi(1, int(round(dealt * 0.05)))
            owner.get_node("Health").heal(share)
            var party: Node = owner.get_parent().get("party")
            for mate in get_tree().get_nodes_in_group("player"):
                if mate != owner and party != null and party.same_party(owner.character_id, mate.character_id) and mate.global_position.distance_to(owner.global_position) <= 96.0:
                    mate.get_node("Health").heal(share)
        "inferno":
            if _unique_hits % 4 == 0:
                for creature in _creatures_near(at, 36.0, [target]):
                    creature.get_node("Health").take_damage(maxi(1, dealt / 2), owner, true)
                    creature.apply_status({"dot": [maxf(1.0, dealt * 0.1), 3.0]}, owner)
                _burst(at, "ring", colour, 1.4)
        "overgrowth":
            if _element_rng.randf() < 0.25 and is_instance_valid(target):
                target.apply_status({"root": 1.0}, owner)
        "bloodthirst":
            owner.get_node("Health").heal(maxi(1, int(round(dealt * 0.12))))
        "thunderlord":
            var from := at
            var skip: Array = already.duplicate() + [target]
            for _jump in range(3):
                var next: Array = _creatures_near(from, ELEMENTS.CHAIN_REACH, skip)
                if next.is_empty():
                    break
                next.sort_custom(func(a, b): return a.global_position.distance_to(from) < b.global_position.distance_to(from))
                next[0].get_node("Health").take_damage(maxi(1, dealt / 2), owner, true)
                _bolt(from, next[0].global_position, colour)
                skip.append(next[0])
                from = next[0].global_position
        "glacier":
            if _element_rng.randf() < 0.2 and is_instance_valid(target):
                target.apply_status({"stun": 0.8}, owner)
        "starfall":
            if _unique_hits % 5 == 0:
                for creature in _creatures_near(at, 40.0, []):
                    creature.get_node("Health").take_damage(dealt, owner, true)
                _burst(at + Vector2(0, -6), "sparkle", colour, 1.6)
        "eclipse":
            if killed:
                owner.get_node("Health").heal(int(round(owner.get_node("Health").maximum * 0.15)))
        "sovereign":
            if killed and _is_night():
                owner.get_node("Health").heal(int(round(owner.get_node("Health").maximum * 0.1)))
        "moonwarden":
            if _unique_hits % 4 == 0:
                for creature in _creatures_near(at, 44.0, [target]):
                    creature.get_node("Health").take_damage(maxi(1, int(dealt * 0.75)), owner, true)
                var heal: int = maxi(1, int(round(owner.get_node("Health").maximum * 0.03)))
                owner.get_node("Health").heal(heal)
                var party: Node = owner.get_parent().get("party")
                for mate in get_tree().get_nodes_in_group("player"):
                    if mate != owner and party != null and party.same_party(owner.character_id, mate.character_id) and mate.global_position.distance_to(owner.global_position) <= 96.0:
                        mate.get_node("Health").heal(heal)
                _burst(at + Vector2(0, -6), "sparkle", Color(0.85, 0.92, 1.0), 1.8)

func _burst(at: Vector2, id: String, colour: Color, size: float) -> void:
    var effect := EFFECTS.spawn(get_parent().get_parent(), id, at)
    if effect != null:
        effect.modulate = colour
        effect.scale = Vector2.ONE * size

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

const ATTRIBUTES := preload("res://scripts/progression/attributes.gd")
## Whether the last basic strike was critical (Dexterity, M12a).
var last_critical := false

func attack(facing: Vector2) -> bool:
    # Mimic forms and Human weapon mastery strengthen the basic strike; skills keep their own damage.
    var bonus: int = get_parent().form_strike_bonus() if get_parent().has_method("form_strike_bonus") else 0
    bonus += get_parent().tree_strike_bonus() if get_parent().has_method("tree_strike_bonus") else 0
    bonus += int(get_parent().gear_bonus("strike")) if get_parent().has_method("gear_bonus") else 0
    var race := _race()
    # M12a: Strength (damage), Dexterity (faster recovery and critical strikes).
    var attributes: float = 1.0
    var quicker: float = 1.0
    var progression: Variant = get_parent().get("progression")
    if progression is Dictionary:
        attributes = ATTRIBUTES.damage_factor(progression)
        quicker = ATTRIBUTES.recovery_factor(progression)
        var crit: float = ATTRIBUTES.crit_chance(progression)
        if crit > 0.0 and _element_rng.randf() < crit:
            attributes *= ATTRIBUTES.CRIT_FACTOR
            last_critical = true
        else:
            last_critical = false
    # An equipped weapon replaces the unarmed damage and sets the attack's shape and timing.
    var weapon: Dictionary = get_parent().equipped_weapon() if get_parent().has_method("equipped_weapon") else {}
    if weapon.is_empty():
        return _strike(facing, int(round((int(race.get("strike_damage", damage)) + bonus + race.strike_bonus) * _aura() * attributes)), strike_cost(), cooldown * race.recovery * quicker)
    var kind: String = GEAR.BASES[weapon.base].weapon
    var set_factor: float = SETS.damage_factor(get_parent().equipped_items(), GEAR.BASES) if get_parent().has_method("equipped_items") else 1.0
    return _strike(facing, element_damage(int(round((int(weapon.stats.damage) + bonus + race.strike_bonus) * _aura() * set_factor * attributes))), strike_cost(), GEAR.WEAPONS[kind].recovery * race.recovery * quicker, StringName(kind))

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
    # M12a: Intelligence makes skills stronger.
    var mind: float = ATTRIBUTES.skill_factor(get_parent().progression) if get_parent().get("progression") is Dictionary else 1.0
    var power := int(round(skill.damage * (1.0 + race.skill_bonus + keen) * _aura() * mind))
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
            var hit_damage: int = ability_damage(target, strike_damage) if effect in BASIC_EFFECTS else strike_damage
            if target.get_node("Health").take_damage(hit_damage, get_parent()):
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
