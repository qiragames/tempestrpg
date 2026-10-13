extends CharacterBody2D
@onready var session: Node = get_node("/root/GameSession")
const AUTHORITY := preload("res://scripts/network/authority.gd")
const FORMS := preload("res://scripts/forms/form_catalogue.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
const RACES := preload("res://scripts/races/race_catalogue.gd")
const TREE := preload("res://scripts/skills/skill_tree.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
## Mimic forms show the creature's body tinted in the character's own colours (never an enemy look).
const MIMIC_TINT := Color(0.62, 1.0, 1.0)
## Movement delegates health and attacks to reusable combat components.

@export var move_speed: float = 95.0
var facing := Vector2.DOWN
var character_id: String = "host"
var local_controlled: bool = true
var network_controlled: bool = false
var input_blocked: bool = false
var exhaustion_active: bool = false
var exhaustion_left: float = 0.0
var remote_direction := Vector2.ZERO
var last_input_msec: int = 0
var progression: Dictionary = {"level": 1, "experience": 0, "skill_points": 1, "race": "Slime", "quests": {}, "equipment": {}, "tree": {"nodes": [], "active": [], "free": []}, "chests": []}
## Current mimic form and the time until it can change again (host-owned, saved).
## Gear (17e): owned items and active cooldowns; equipped item IDs live in progression.equipment.
var gear: Dictionary = {"items": [], "cooldowns": {}}
var form: String = FORMS.BASE
var form_cooldown: float = 0.0

## Animated body (step 19); presentation only. `_body_set` is the sheet set currently shown.
var body_sprite: AnimatedSprite2D
var _body_set: String = ""
var _last_position := Vector2.INF
var _moving_time: float = 0.0

func _ready() -> void:
    body_sprite = SPRITES.make(_body_id())
    add_child(body_sprite)
    _body_set = _body_id()
    $Camera2D.enabled = local_controlled
    # Each character resizes its own body when its form changes.
    $CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
    $Health.defeated.connect(func():
        $Magicules.enabled = false
        # Safe-form policy: defeat always returns to the base form.
        apply_form(FORMS.BASE)
        form_cooldown = 0.0
    )

func race() -> String:
    return progression.get("race", RACES.DEFAULT)

## Which sheet set draws this character: its race, or the creature it mimics.
func _body_id() -> String:
    if form != FORMS.BASE:
        return "gnasher"
    return {"Slime": "slime", "Human": "human", "Demon": "demon"}.get(race(), "slime")

## Runs on every peer: replicas only see positions, so movement is read from position changes.
func _animate(delta: float) -> void:
    if not is_instance_valid(body_sprite):
        return
    var wanted := _body_id()
    if wanted != _body_set:
        _body_set = wanted
        body_sprite.sprite_frames = SPRITES.frames(wanted)
    var moved: bool = _last_position != Vector2.INF and position.distance_to(_last_position) > 0.05
    _last_position = position
    # A short grace keeps the walk cycle steady when snapshots arrive unevenly.
    _moving_time = 0.15 if moved else maxf(0.0, _moving_time - delta)
    var walking: bool = _moving_time > 0.0
    body_sprite.modulate = MIMIC_TINT if form != FORMS.BASE else Color.WHITE
    if exhaustion_active:
        body_sprite.modulate = Color(0.55, 0.65, 0.9)
    if SPRITES.is_side(_body_set):
        body_sprite.flip_h = facing.x < 0.0
        SPRITES.play(body_sprite, "death" if $Health.current <= 0 else ("run" if walking else "idle"))
        return
    if $Health.current <= 0:
        SPRITES.play(body_sprite, "dead")
        return
    var direction := SPRITES.direction_name(facing)
    var attacking: bool = has_node("MeleeAttack") and $MeleeAttack.flash_left > 0.0
    SPRITES.play(body_sprite, ("attack_" if attacking and _body_set != "slime" else ("walk_" if walking else "idle_")) + direction)

func race_stats() -> Dictionary:
    return RACES.stats(race())

func can_mimic() -> bool:
    return RACES.can_mimic(race(), int(progression.get("level", 1)))

func mimic_hint() -> String:
    return "%ss learn mimicry at level %d." % [race(), int(race_stats().mimic_level)]

## Character creation (host only): set the race and its base stats at full health and Magicules.
func choose_race(id: String) -> bool:
    if not RACES.valid(id) or not AUTHORITY.can_mutate(self):
        return false
    var stats: Dictionary = RACES.stats(id)
    progression["race"] = id
    # Base stats plus any bought tree upgrades, so re-applying never loses purchased stats.
    var nodes: Array = progression.get("tree", {}).get("nodes", [])
    move_speed = stats.move_speed + TREE.stat_bonus(nodes, "speed")
    # Base stats plus tree upgrades plus equipped gear.
    $Health.maximum = stats.hp + int(TREE.stat_bonus(nodes, "hp")) + int(gear_bonus("hp"))
    $Health.current = $Health.maximum
    $Health.changed.emit($Health.current, $Health.maximum)
    $Magicules.maximum = stats.magicules + TREE.stat_bonus(nodes, "magicules") + gear_bonus("magicules")
    $Magicules._current = $Magicules.maximum
    $Magicules.changed.emit($Magicules.current, $Magicules.maximum)
    if not can_mimic() and form != FORMS.BASE:
        apply_form(FORMS.BASE)
    queue_redraw()
    return true

## Host-only skill-tree purchase: one point for a stat upgrade or a new skill.
func buy_node(id: String) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    var problem: String = TREE.buy_problem(progression, id)
    if not problem.is_empty():
        session.notify_character(character_id, problem)
        return false
    var node: Dictionary = TREE.NODES[id]
    progression["skill_points"] = int(progression.skill_points) - TREE.COST
    progression.tree.nodes.append(id)
    if node.has("skill"):
        $SkillBook.grant_tree_skill(StringName(node.skill))
    else:
        _apply_stat(node.stat, node.amount)
    session.notify_character(character_id, "Skill tree: %s. %s" % [node.name, TREE.describe_node(id)])
    session.queue_save()
    return true

## Host-only: spend a point so a skill learned by absorbing or a trial can be used and slotted.
func activate_skill(id: String) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    var problem: String = TREE.activate_problem(progression, $SkillBook.evidence_ids(), id)
    if not problem.is_empty():
        session.notify_character(character_id, problem)
        return false
    progression["skill_points"] = int(progression.skill_points) - TREE.ACTIVATE_COST
    progression.tree.active.append(id)
    $SkillBook.auto_slot(StringName(id))
    session.notify_character(character_id, "Skill activated: %s." % $SkillBook.get_skill(StringName(id)).display_name)
    session.queue_save()
    return true

## Host-only fusion (17d): two active skills become their fused skill.
func fuse_skills(a: String, b: String) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    var problem: String = $SkillBook.fuse(StringName(a), StringName(b))
    if not problem.is_empty():
        session.notify_character(character_id, problem)
        return false
    var result: String = $SkillBook.CATALOGUE.fusion_for(a, b)
    var book = $SkillBook
    session.notify_character(character_id, "Fusion: %s + %s → %s (%s)." % [load(book.CATALOGUE.SKILLS[a]).display_name, load(book.CATALOGUE.SKILLS[b]).display_name, book.get_skill(StringName(result)).display_name, book.get_skill(StringName(result)).tier])
    session.queue_save()
    return true

## Host-only split: a fused skill becomes its two skills again.
func split_skill(id: String) -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    var problem: String = $SkillBook.split(StringName(id))
    if not problem.is_empty():
        session.notify_character(character_id, problem)
        return false
    session.notify_character(character_id, "Split: %s → %s." % [load($SkillBook.CATALOGUE.SKILLS[id]).display_name, " + ".join($SkillBook.CATALOGUE.components(id).map(func(part): return load($SkillBook.CATALOGUE.SKILLS[part]).display_name))])
    session.queue_save()
    return true

func tree_strike_bonus() -> int:
    return int(TREE.stat_bonus(progression.get("tree", {}).get("nodes", []), "strike"))

func _apply_stat(stat: String, amount: float) -> void:
    match stat:
        "hp":
            $Health.maximum += int(amount)
            if $Health.current > 0:
                $Health.current += int(amount)
            $Health.changed.emit($Health.current, $Health.maximum)
        "magicules":
            $Magicules.maximum += amount
            $Magicules._current += amount
            $Magicules.changed.emit($Magicules.current, $Magicules.maximum)
        "regen":
            $Magicules.regeneration_per_second += amount
        "speed":
            move_speed += amount

## Host-only experience award; tells the character about XP and any level-up.
func gain_experience(amount: int, reason: String) -> void:
    if amount <= 0 or not AUTHORITY.can_mutate(self):
        return
    var gained: int = LEVELING.grant(self, amount)
    if is_instance_valid(session.world):
        var text := "+%d XP (%s)." % [amount, reason]
        if gained > 0:
            text += " Level %d reached: +%d skill point%s." % [progression.level, gained, "" if gained == 1 else "s"]
        session.notify_character(character_id, text)
    if gained > 0:
        session.queue_save()

func _physics_process(_delta: float) -> void:
    var direction := Vector2.ZERO
    if local_controlled and not input_blocked:
        direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    elif network_controlled and not input_blocked and Time.get_ticks_msec() - last_input_msec < 350:
        direction = remote_direction
    if is_exhausted():
        direction = Vector2.ZERO
    if session.replica_world:
        if local_controlled:
            session.send_move(direction)
        return
    if $Health.current <= 0 or is_exhausted():
        velocity = Vector2.ZERO
        return
    velocity = direction * current_speed()
    if not direction.is_zero_approx():
        facing = direction
    move_and_slide()
    queue_redraw()

func current_speed() -> float:
    return maxf(10.0, move_speed + gear_bonus("speed")) * FORMS.FORMS[form].speed

## ---- Gear (17e) ----
func item_by_id(id: String) -> Dictionary:
    for item in gear.items:
        if item.id == id:
            return item
    return {}

func equipped_items() -> Array:
    var result: Array = []
    for slot in GEAR.SLOTS:
        var item: Dictionary = item_by_id(progression.get("equipment", {}).get(slot, ""))
        if not item.is_empty():
            result.append(item)
    return result

func equipped_weapon() -> Dictionary:
    return item_by_id(progression.get("equipment", {}).get("weapon", ""))

func gear_passive(id: String) -> bool:
    return equipped_items().any(func(item): return id in item.passives)

## Sum of a stat over equipped items, including the passives that are plain stat bonuses.
func gear_bonus(stat: String) -> float:
    var total := 0.0
    for item in equipped_items():
        total += float(item.stats.get(stat, 0))
        if stat == "speed" and "swift" in item.passives:
            total += 5.0
        if stat == "regen" and "wellspring" in item.passives:
            total += 0.5
    return total

## Saved maxima and regeneration already include equipped gear; this re-derives the live parts.
func refresh_gear() -> void:
    $Health.armor = int(gear_bonus("defense"))
    queue_redraw()

func _apply_item(item: Dictionary, sign: int) -> void:
    var hp: int = int(item.stats.get("hp", 0)) * sign
    $Health.maximum += hp
    # Reversible equipment changes capacity, never refills current resources.
    $Health.current = clampi($Health.current, 0, $Health.maximum)
    $Health.changed.emit($Health.current, $Health.maximum)
    var mp: float = float(item.stats.get("magicules", 0)) * sign
    $Magicules.maximum += mp
    $Magicules._current = clampf($Magicules._current, 0.0, $Magicules.maximum)
    $Magicules.changed.emit($Magicules.current, $Magicules.maximum)
    $Magicules.regeneration_per_second = maxf(0.0, $Magicules.regeneration_per_second + (float(item.stats.get("regen", 0)) + (0.5 if "wellspring" in item.passives else 0.0)) * sign)

## Host-only: put an owned item into a slot (swapping out what was there).
func add_item(item: Dictionary) -> bool:
    if not AUTHORITY.can_mutate(self) or not GEAR.valid_item(item) or gear.items.size() >= GEAR.MAX_ITEMS or not item_by_id(item.id).is_empty():
        return false
    gear.items.append(item.duplicate(true))
    return true

func equip(id: String, slot: String) -> bool:
    if not AUTHORITY.can_mutate(self) or not slot in GEAR.SLOTS:
        return false
    var item: Dictionary = item_by_id(id)
    if item.is_empty() or not GEAR.slot_fits(item.base, slot):
        session.notify_character(character_id, "That item does not fit there.")
        return false
    var equipment: Dictionary = progression.equipment
    for other in equipment.keys():
        if equipment[other] == id:
            unequip(other)
    if equipment.has(slot):
        unequip(slot)
    equipment[slot] = id
    _apply_item(item, 1)
    refresh_gear()
    session.notify_character(character_id, "Equipped %s." % GEAR.display_name(item))
    session.queue_save()
    return true

func unequip(slot: String) -> bool:
    if not AUTHORITY.can_mutate(self) or not progression.equipment.has(slot):
        return false
    var item: Dictionary = item_by_id(progression.equipment[slot])
    progression.equipment.erase(slot)
    if not item.is_empty():
        _apply_item(item, -1)
    refresh_gear()
    session.queue_save()
    return true

## G: use the first ready active of the equipped items (slot order).
func use_gear_active() -> bool:
    if not AUTHORITY.can_mutate(self) or $Health.current <= 0 or is_exhausted():
        return false
    for item in equipped_items():
        if item.active.is_empty() or gear.cooldowns.get(item.id, 0.0) > 0.0:
            continue
        match item.active:
            "barrier":
                $Health.immunity_left = maxf($Health.immunity_left, 2.0)
            "surge":
                $Magicules.restore(30.0)
        gear.cooldowns[item.id] = GEAR.ACTIVES[item.active].cooldown
        session.notify_character(character_id, "%s: %s." % [GEAR.ACTIVES[item.active].name, GEAR.ACTIVES[item.active].text])
        return true
    session.notify_character(character_id, "No gear active is ready.")
    return false

## Thorns: a creature that lands a hit takes damage back (host).
func on_damaged_by(source: Node) -> void:
    if gear_passive("thorns") and is_instance_valid(source) and source.is_in_group("enemies") and source.has_node("Health"):
        source.get_node("Health").take_damage(3, self)

func form_strike_bonus() -> int:
    return FORMS.FORMS[form].strike_bonus

## Presentation and collision for a form; validation and costs live in try_transform.
func apply_form(id: String) -> void:
    form = id
    $CollisionShape2D.shape.radius = FORMS.FORMS[id].radius
    queue_redraw()

## Host-side mimicry. Costs are paid only when the change succeeds; nothing is refilled.
func try_transform(target: String) -> bool:
    if not AUTHORITY.can_mutate(self) or not FORMS.FORMS.has(target) or target == form:
        return false
    if not can_mimic():
        session.notify_character(character_id, mimic_hint())
        return false
    if $Health.current <= 0 or is_exhausted() or form_cooldown > 0.0:
        return false
    if not FORMS.unlocked(target, $SkillBook.evidence):
        session.notify_character(character_id, "Mimicry requires analyzing that creature first.")
        return false
    if FORMS.FORMS[target].radius > FORMS.FORMS[form].radius and not _room_for(FORMS.FORMS[target].radius):
        session.notify_character(character_id, "Not enough room to change form here.")
        return false
    var cost: float = FORMS.FORMS[target].cost
    if cost > 0.0 and not $Magicules.try_spend(cost):
        return false
    apply_form(target)
    form_cooldown = FORMS.CHANGE_COOLDOWN
    session.notify_character(character_id, "Mimicry: %s." % FORMS.FORMS[target].name)
    session.queue_save()
    return true

func _room_for(radius: float) -> bool:
    var circle := CircleShape2D.new()
    circle.radius = radius
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = circle
    query.transform = Transform2D(0.0, global_position)
    query.collision_mask = 1
    query.exclude = [get_rid()]
    return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

## The form T switches to: base when transformed, otherwise the first unlocked mimic form.
func next_form() -> String:
    if form != FORMS.BASE:
        return FORMS.BASE
    for id in FORMS.available($SkillBook.evidence):
        if id != FORMS.BASE:
            return id
    return ""

func is_exhausted() -> bool:
    return exhaustion_active

func begin_exhaustion(seconds: float) -> void:
    if session.replica_world:
        return
    if $Absorption.active:
        $Absorption._cancel("Analysis interrupted by exhaustion.")
    exhaustion_active = true
    exhaustion_left = maxf(exhaustion_left, seconds)
    velocity = Vector2.ZERO
    remote_direction = Vector2.ZERO
    queue_redraw()

func _process(delta: float) -> void:
    _animate(delta)
    if session.replica_world:
        return
    form_cooldown = maxf(0.0, form_cooldown - delta)
    for id in gear.cooldowns.keys():
        gear.cooldowns[id] = maxf(0.0, gear.cooldowns[id] - delta)
        if gear.cooldowns[id] <= 0.0:
            gear.cooldowns.erase(id)
    if not exhaustion_active or $Health.current <= 0:
        return
    exhaustion_left = maxf(0.0, exhaustion_left - delta)
    if exhaustion_left <= 0.0 and $Magicules.current >= $Magicules.maximum * 0.25:
        exhaustion_active = false
        session.notify_character(character_id, "Aura stabilized. Recovery complete.")
        session.queue_save()
        queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if not local_controlled or input_blocked:
        return
    if event.is_action_pressed("transform") and not event.is_echo():
        var target := next_form()
        if not can_mimic():
            session.notify_character(character_id, mimic_hint())
        elif target.is_empty():
            session.notify_character(character_id, "No mimic form known yet. Analyze a creature first.")
        elif session.active:
            session.request_action("transform", {"form": target})
        else:
            try_transform(target)
        return
    if event.is_action_pressed("gear_active") and not event.is_echo():
        if session.active:
            session.request_action("gear", {"operation": "use"})
        else:
            use_gear_active()
        return
    if session.active:
        if event.is_action_pressed("restart") and not event.is_echo():
            session.request_action("respawn")
        for action in ["attack", "absorb", "skill_1", "skill_2", "skill_3", "skill_4"]:
            if event.is_action_pressed(action) and not event.is_echo():
                session.request_action(action)
        return
    if event.is_action_pressed("attack") and not event.is_echo():
        $MeleeAttack.attack(facing)
    elif event.is_action_pressed("absorb") and not event.is_echo():
        $Absorption.attempt_absorb()
    elif not event.is_echo():
        for index in range($SkillBook.SLOT_COUNT):
            if event.is_action_pressed("skill_%d" % (index + 1)):
                var skill: Resource = $SkillBook.skill_at_slot(index)
                if skill != null:
                    $MeleeAttack.attack_skill(facing, skill.id)

func configure_replica() -> void:
    for component in [$Health, $Magicules, $MeleeAttack, $Absorption]:
        component.set_process(false)

func _draw() -> void:
    _draw_body()
    if has_node("Health") and $Health.current > 0 and not exhaustion_active and form == FORMS.BASE:
        _draw_gear()

## Distinct, rarity-coloured looks per item base (placeholders until the sprite step).
func _draw_gear() -> void:
    for slot in GEAR.SLOTS:
        var item: Dictionary = item_by_id(progression.get("equipment", {}).get(slot, ""))
        if item.is_empty():
            continue
        var color := Color(GEAR.RARITY_COLORS[int(item.rarity)])
        match GEAR.BASES[item.base].look:
            "hood":
                draw_rect(Rect2(-6, -12, 12, 4), color.darkened(0.2))
            "helm":
                draw_rect(Rect2(-6, -13, 12, 4), color)
                draw_rect(Rect2(-1, -15, 2, 2), color.lightened(0.3))
            "vest":
                draw_rect(Rect2(-5, 2, 10, 4), color.darkened(0.15))
            "mail":
                draw_rect(Rect2(-6, 1, 12, 5), color)
                draw_rect(Rect2(-4, 2, 8, 1), color.lightened(0.4))
            "gloves":
                draw_rect(Rect2(-8, 3, 2, 2), color)
                draw_rect(Rect2(6, 3, 2, 2), color)
            "boots":
                draw_rect(Rect2(-5, 7, 3, 2), color)
                draw_rect(Rect2(2, 7, 3, 2), color)
            "ring":
                draw_circle(Vector2(7, 4), 1.2, color)
            "amulet":
                draw_rect(Rect2(-1, 0, 2, 2), color)
            "sword":
                draw_line(Vector2(9, 4), Vector2(9, -8), color, 2.0)
                draw_rect(Rect2(7, 2, 5, 1), color.darkened(0.3))
            "spear":
                draw_line(Vector2(10, 8), Vector2(10, -14), color.darkened(0.3), 1.0)
                draw_rect(Rect2(9, -17, 3, 4), color)
            "scythe":
                draw_line(Vector2(10, 8), Vector2(10, -12), color.darkened(0.3), 1.0)
                draw_arc(Vector2(5, -12), 5.0, -PI, 0.0, 6, color, 2.0)
            "bow":
                draw_arc(Vector2(8, -1), 7.0, -1.4, 1.4, 8, color, 1.5)
                draw_line(Vector2(9, -8), Vector2(9, 6), Color(0.9, 0.9, 0.85, 0.7), 1.0)

func _draw_body() -> void:
    # The animated body replaces these placeholder shapes; they remain only as a fallback.
    if is_instance_valid(body_sprite):
        return
    if has_node("Health") and $Health.current <= 0:
        draw_rect(Rect2(-8, 2, 16, 4), Color("447c88"))
        return
    if exhaustion_active:
        draw_rect(Rect2(-9, 0, 18, 6), Color("477f91"))
        draw_rect(Rect2(-5, -2, 10, 3), Color("78a6b4"))
        draw_rect(Rect2(-4, 2, 3, 1), Color("142c42"))
        draw_rect(Rect2(1, 2, 3, 1), Color("142c42"))
        return
    if form == "gnasher":
        # Gnasher mimicry keeps the slime's cyan palette so it never reads as an enemy.
        draw_rect(Rect2(-10, 3, 20, 5), Color(0.03, 0.12, 0.14, 0.5))
        draw_rect(Rect2(-9, -8, 18, 14), Color("359caf"))
        draw_rect(Rect2(-11, -12, 5, 8), Color("359caf"))
        draw_rect(Rect2(6, -12, 5, 8), Color("359caf"))
        draw_rect(Rect2(-7, -10, 14, 3), Color("73d7d5"))
        draw_rect(Rect2(Vector2(-6, -4) + facing * 1.5, Vector2(3, 3)), Color("142c42"))
        draw_rect(Rect2(Vector2(3, -4) + facing * 1.5, Vector2(3, 3)), Color("142c42"))
        draw_rect(Rect2(-4, 2, 8, 3), Color("baf3e4"))
        return
    var eyes := facing * 1.5
    if race() == "Human":
        # Placeholder humanoid: tan skin, brown hair, blue tunic.
        draw_rect(Rect2(-7, 5, 14, 4), Color(0.03, 0.12, 0.14, 0.5))
        draw_rect(Rect2(-4, 1, 8, 7), Color("3d5f9e"))
        draw_rect(Rect2(-4, 8, 3, 2), Color("4a3a2c"))
        draw_rect(Rect2(1, 8, 3, 2), Color("4a3a2c"))
        draw_rect(Rect2(-6, 1, 2, 5), Color("e2b98f"))
        draw_rect(Rect2(4, 1, 2, 5), Color("e2b98f"))
        draw_rect(Rect2(-4, -8, 8, 9), Color("e2b98f"))
        draw_rect(Rect2(-5, -10, 10, 4), Color("6b4428"))
        draw_rect(Rect2(Vector2(-3, -4) + eyes, Vector2(2, 2)), Color("142c42"))
        draw_rect(Rect2(Vector2(1, -4) + eyes, Vector2(2, 2)), Color("142c42"))
        return
    if race() == "Demon":
        # Placeholder demon: dark violet body, pale horns, red eyes.
        draw_rect(Rect2(-7, 5, 14, 4), Color(0.03, 0.12, 0.14, 0.5))
        draw_rect(Rect2(-5, 0, 10, 8), Color("4b2a5e"))
        draw_rect(Rect2(-4, 8, 3, 2), Color("2b1736"))
        draw_rect(Rect2(1, 8, 3, 2), Color("2b1736"))
        draw_rect(Rect2(-4, -8, 8, 9), Color("7d4a8f"))
        draw_rect(Rect2(-6, -12, 2, 5), Color("e6dcc8"))
        draw_rect(Rect2(4, -12, 2, 5), Color("e6dcc8"))
        draw_rect(Rect2(Vector2(-3, -4) + eyes, Vector2(2, 2)), Color("ff4a4a"))
        draw_rect(Rect2(Vector2(1, -4) + eyes, Vector2(2, 2)), Color("ff4a4a"))
        return
    # Deliberately simple pixel placeholder, ready to replace with animated sprites.
    draw_rect(Rect2(-9, 3, 18, 5), Color(0.03, 0.12, 0.14, 0.5))
    draw_rect(Rect2(-7, -5, 14, 11), Color("359caf"))
    draw_rect(Rect2(-5, -8, 10, 3), Color("73d7d5"))
    draw_rect(Rect2(-9, -2, 2, 6), Color("359caf"))
    draw_rect(Rect2(7, -2, 2, 6), Color("359caf"))
    draw_rect(Rect2(-5, -4, 3, 2), Color("baf3e4"))
    var eye_offset := facing * 1.5
    draw_rect(Rect2(Vector2(-4, -1) + eye_offset, Vector2(2, 3)), Color("142c42"))
    draw_rect(Rect2(Vector2(2, -1) + eye_offset, Vector2(2, 3)), Color("142c42"))
