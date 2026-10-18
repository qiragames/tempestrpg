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
## The owner's mod menu boosts (dev build only, see scripts/dev/dev_tools.gd).
const DEV := preload("res://scripts/dev/dev_tools.gd")
var local_controlled: bool = true
var network_controlled: bool = false
var input_blocked: bool = false
var exhaustion_active: bool = false
var exhaustion_left: float = 0.0
var remote_direction := Vector2.ZERO
var last_input_msec: int = 0
var progression: Dictionary = {"level": 1, "experience": 0, "skill_points": 1, "race": "Slime", "quests": {}, "equipment": {}, "tree": {"nodes": [], "active": [], "free": []}, "chests": [], "zeni": 0, "ship": {"owned": false, "at": ""}, "ferry_pass_until": 0.0, "tools": {"axe": 0, "pickaxe": 0, "rod": 0}, "mounts": [], "mount": "", "augments": [], "auras": [], "aura": "", "bonus_points": 0, "champion": false, "professions": {"woodcutting": 0, "mining": 0, "fishing": 0, "smithing": 0, "alchemy": 0, "cooking": 0, "enchanting": 0, "tailoring": 0}, "fish_log": {}}
## Current mimic form and the time until it can change again (host-owned, saved).
## Gear (17e): owned items and active cooldowns; equipped item IDs live in progression.equipment.
var gear: Dictionary = {"items": [], "cooldowns": {}}
## Step 24a (user decision): hosted worlds respawn a defeated character after RESPAWN_DELAY at the
## camp (or the spawn); the defeat costs 10% of the XP span towards the next level (never a
## level) and drops the bag (materials and unequipped gear) as a pile. Host only, not saved.
const RESPAWN_DELAY := 5.0
const DEATH_XP_SHARE := 0.1
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const TRAVEL := preload("res://scripts/travel/travel_catalogue.gd")
const UPGRADES := preload("res://scripts/items/upgrade_catalogue.gd")
## Fishing (M4.5d, host): seconds until a bite (negative: biting for that long), -INF when not
## fishing; the bite window by rod tier; where the line was cast.
var fishing_bite_in := -INF
var fishing_window := 0.0
## M6b: the reel-in minigame while a fish is hooked (host-owned, replicated in snapshots):
## {fish, rarity, need, hits, misses, centre, width, speed, t}. Empty when nothing is hooked.
var reel: Dictionary = {}
const FISHES := preload("res://scripts/professions/fish_catalogue.gd")
var _fishing_spot := Vector2.ZERO
var _fishing_lake := false
var _tame_cooldown := 0.0
var _mount_sprite: Sprite2D
const REALM := preload("res://scripts/realm/realm_catalogue.gd")
var _aura_node: Node2D
## Consumables (M4.5c): shared cooldown and the effects still running (seconds left, per second).
var consumable_cooldown: float = 0.0
var _heal_left := 0.0
var _heal_carry := 0.0
var _tonic_left := 0.0
var death_left: float = 0.0
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
    # M4.5d: a hit throws you off your mount and spoils a cast.
    $Health.damaged.connect(func(amount: int, _source: Node):
        if amount > 0:
            dismount()
            fishing_bite_in = -INF
    )
    $Health.defeated.connect(func():
        $Magicules.enabled = false
        # Safe-form policy: defeat always returns to the base form.
        apply_form(FORMS.BASE)
        form_cooldown = 0.0
        if session.active and AUTHORITY.can_mutate(self):
            death_left = RESPAWN_DELAY
            _death_penalty()
    )

## XP loss and the dropped bag (host).
func _death_penalty() -> void:
    var level: int = int(progression.get("level", 1))
    if level < LEVELING.LEVEL_CAP:
        var floor_xp: int = LEVELING.xp_for_level(level)
        var span: int = LEVELING.xp_for_level(level + 1) - floor_xp
        var lost: int = mini(int(progression.get("experience", 0)) - floor_xp, int(floor(span * DEATH_XP_SHARE)))
        if lost > 0:
            progression["experience"] = int(progression.experience) - lost
            session.notify_character(character_id, "-%d XP (defeat)." % lost)
    # Do not remove anything until the world has accepted the pile. At the pile
    # limit the bag stays with its character rather than silently disappearing.
    var materials: Dictionary = {}
    for entry in $Inventory.entries():
        materials[String(entry.id)] = entry.count
    var worn: Array = progression.get("equipment", {}).values()
    var dropped: Array = gear.items.filter(func(item): return not item.id in worn)
    # M4.5c: a tenth of the purse falls with the bag.
    var coins: int = int(floor(zeni() * TRADE.DEATH_SHARE))
    var world: Node = session.world
    if (not materials.is_empty() or not dropped.is_empty() or coins > 0) and is_instance_valid(world) and world.has_method("drop_pile"):
        var pile = world.drop_pile(character_id, materials, dropped, global_position, "", -1.0, coins)
        if pile != null:
            progression["zeni"] = zeni() - coins
            $Inventory.take_all()
            gear.items = gear.items.filter(func(item): return item.id in worn)
            for item in dropped:
                gear.cooldowns.erase(item.id)
            session.notify_character(character_id, "Your bag fell where you were defeated (marked on the map).")
        else:
            session.notify_character(character_id, "The world pile limit was reached. Your bag stays with you.")
    session.queue_save()

func zeni() -> int:
    return int(progression.get("zeni", 0))

## Host: add Zeni (defeats, chests, sales, piles).
func gain_zeni(amount: int, reason: String) -> void:
    if amount <= 0 or not AUTHORITY.can_mutate(self):
        return
    if DEV.zeni and DEV.applies(self):
        amount *= DEV.ZENI_FACTOR
    # M11f: a pet's Zeni bonus.
    var pet_zeni: float = preload("res://scripts/pets/pet_catalogue.gd").bonus(progression, "zeni")
    if pet_zeni > 0.0:
        amount = int(round(amount * (1.0 + pet_zeni / 100.0)))
    # M14b: the guild's Zeni perk (from creatures and bosses).
    var guilds: Node = get_parent().get("guilds") if get_parent() != null else null
    if guilds != null and reason in ["defeat", "boss"]:
        var guild_zeni: int = guilds.perk(character_id, "zeni")
        if guild_zeni > 0:
            amount = int(round(amount * (1.0 + guild_zeni / 100.0)))
    progression["zeni"] = mini(TRADE.MAX_ZENI, zeni() + amount)
    if reason in ["defeat", "chest", "pile"]:
        session.notify_character(character_id, "+%d Zeni (%s)." % [amount, reason])

## Host: pay Zeni; false (nothing spent) if the purse is too light.
func spend_zeni(amount: int) -> bool:
    if amount < 0 or zeni() < amount or not AUTHORITY.can_mutate(self):
        return false
    progression["zeni"] = zeni() - amount
    return true

## Host: drop an owned, unequipped item (selling).
func remove_item(id: String) -> bool:
    if not AUTHORITY.can_mutate(self) or id in progression.get("equipment", {}).values():
        return false
    for index in range(gear.items.size()):
        if gear.items[index].id == id:
            gear.items.remove_at(index)
            gear.cooldowns.erase(id)
            return true
    return false

## Host: use a bag good — drink a draught/tonic or read a scroll (M4.5c).
## M6c: active elixirs {effect: [amount, seconds left]} (host-owned, replicated, not saved).
var elixirs: Dictionary = {}
const CRAFT := preload("res://scripts/professions/crafting_catalogue.gd")
var _heal_rate := 8.0
var _tonic_rate := 8.0

## Host: drink a crafted potion or elixir (M6c).
func _drink(id: String) -> bool:
    # M11e: meals work like potions (Cooking 30: they last 50% longer instead of Alchemy).
    var potion: Array = CRAFT.consumable(id)
    var effect: String = potion[3]
    if effect in CRAFT.COOLDOWN_EFFECTS and consumable_cooldown > 0.0:
        session.notify_character(character_id, "Wait %.0f s before the next potion." % ceilf(consumable_cooldown))
        return false
    $Inventory.discard(StringName(id), 1)
    # Alchemy 30 (Potent): potions last 50% longer.
    var seconds: float = float(potion[5]) * (1.5 if PRO.level_of(progression, "cooking" if CRAFT.is_food(id) else "alchemy") >= 30 else 1.0)
    match effect:
        "heal":
            consumable_cooldown = TRADE.CONSUMABLE_COOLDOWN
            _heal_rate = float(potion[4]) / TRADE.CONSUMABLE_SECONDS
            _heal_left = TRADE.CONSUMABLE_SECONDS
        "tonic":
            consumable_cooldown = TRADE.CONSUMABLE_COOLDOWN
            _tonic_rate = float(potion[4]) / TRADE.CONSUMABLE_SECONDS
            _tonic_left = TRADE.CONSUMABLE_SECONDS
        "full":
            consumable_cooldown = TRADE.CONSUMABLE_COOLDOWN
            $Health.heal($Health.maximum)
            $Magicules.restore($Magicules.maximum)
        _:
            elixirs[effect] = [float(potion[4]), seconds]
            refresh_gear()
    session.notify_character(character_id, "%s: %s" % [potion[0], potion[7]])
    return true

## Elixir strength (0 when not active).
func elixir(effect: String) -> float:
    return float(elixirs[effect][0]) if elixirs.has(effect) else 0.0

func _tick_elixirs(delta: float) -> void:
    if elixirs.is_empty():
        return
    for effect in elixirs.keys():
        elixirs[effect][1] = float(elixirs[effect][1]) - delta
        if elixirs[effect][1] <= 0.0 and AUTHORITY.can_mutate(self):
            elixirs.erase(effect)
            refresh_gear()

func use_good(id: String) -> bool:
    if not AUTHORITY.can_mutate(self) or $Health.current <= 0 or $Inventory.count_of(id) <= 0:
        return false
    if CRAFT.is_potion(id) or CRAFT.is_food(id):
        return _drink(id)
    if TRADE.CONSUMABLES.has(id):
        if consumable_cooldown > 0.0:
            session.notify_character(character_id, "Wait %.0f s before the next draught or tonic." % ceilf(consumable_cooldown))
            return false
        $Inventory.discard(StringName(id), 1)
        consumable_cooldown = TRADE.CONSUMABLE_COOLDOWN
        if id == "healing_draught":
            _heal_rate = 40.0 / TRADE.CONSUMABLE_SECONDS
            _heal_left = TRADE.CONSUMABLE_SECONDS
        else:
            _tonic_rate = 40.0 / TRADE.CONSUMABLE_SECONDS
            _tonic_left = TRADE.CONSUMABLE_SECONDS
        session.notify_character(character_id, "%s: +40 over 5 s." % TRADE.CONSUMABLES[id][0])
        return true
    # M11f: a Mysterious Egg hatches a pet.
    if id == "pet_egg":
        return get_parent().pets.use_egg(self) if get_parent() != null and get_parent().get("pets") != null else false
    if UPGRADES.is_rune(id):
        return socket_rune(id)
    if UPGRADES.is_augment(id):
        return install_augment(id)
    var skill := TRADE.scroll_skill(id)
    if skill.is_empty():
        return false
    var book = $SkillBook
    if book.knows(StringName(skill)):
        session.notify_character(character_id, "You already know that skill.")
        return false
    $Inventory.discard(StringName(id), 1)
    book.learn_from_scroll(skill)
    session.notify_character(character_id, "Learned %s from the scroll. Activate it in the skill tree (K)." % TRADE.good_info(id)[0].trim_prefix("Scroll: "))
    session.queue_save()
    return true

func _tick_consumables(delta: float) -> void:
    consumable_cooldown = maxf(0.0, consumable_cooldown - delta)
    if _heal_left > 0.0:
        var step := minf(delta, _heal_left)
        _heal_left -= step
        _heal_carry += _heal_rate * step
        var whole := int(floor(_heal_carry))
        if whole > 0:
            _heal_carry -= whole
            $Health.heal(whole)
    if _tonic_left > 0.0:
        var step := minf(delta, _tonic_left)
        _tonic_left -= step
        $Magicules.restore(_tonic_rate * step)
    _tick_elixirs(delta)

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
    _draw_mount(direction, walking)
    _draw_aura()

## The transformation's aura (M4.7): flickering flame-like spikes behind the character, tinted
## body; seen by everyone (the active aura is in the replicated progression).
func _draw_aura() -> void:
    var active := aura()
    if active.is_empty() or not REALM.AURAS.has(active) or $Health.current <= 0:
        if is_instance_valid(_aura_node):
            _aura_node.visible = false
        return
    if not is_instance_valid(_aura_node):
        _aura_node = Node2D.new()
        _aura_node.name = "Aura"
        _aura_node.show_behind_parent = true
        add_child(_aura_node)
        move_child(_aura_node, 0)
        _aura_node.draw.connect(func():
            var color: Color = REALM.AURAS[aura()][4] if REALM.AURAS.has(aura()) else Color.WHITE
            var t := Time.get_ticks_msec() / 1000.0
            var points := PackedVector2Array()
            for i in range(18):
                var angle := -PI + float(i) / 17.0 * PI * 2.0
                var radius := 14.0 + (8.0 if i % 2 == 0 else 0.0) + sin(t * 12.0 + i) * 2.5
                # Flames lick upwards: the upper half reaches higher.
                points.append(Vector2(cos(angle) * radius * 0.75, sin(angle) * radius - 6.0 - (8.0 if sin(angle) < 0 else 0.0)))
            _aura_node.draw_circle(Vector2(0, -6), 16.0, Color(color, 0.18))
            _aura_node.draw_colored_polygon(points, Color(color, 0.45))
            _aura_node.draw_polyline(points + PackedVector2Array([points[0]]), Color(color.lightened(0.3), 0.95), 1.5)
        )
    _aura_node.visible = true
    _aura_node.queue_redraw()
    body_sprite.modulate = body_sprite.modulate.lerp(REALM.AURAS[active][4], 0.35)

## The mount under a riding character (M4.5d): side view when moving sideways, else the front
## view; two walk frames; the rider sits a little higher.
func _draw_mount(direction: String, walking: bool) -> void:
    var mount := riding()
    if mount.is_empty() or not TRAVEL.MOUNTS.has(mount) or $Health.current <= 0:
        if is_instance_valid(_mount_sprite):
            _mount_sprite.visible = false
        body_sprite.position.y = 0.0
        return
    if not is_instance_valid(_mount_sprite):
        _mount_sprite = Sprite2D.new()
        _mount_sprite.name = "MountBody"
        _mount_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        _mount_sprite.show_behind_parent = true
        add_child(_mount_sprite)
        move_child(_mount_sprite, 0)
    _mount_sprite.visible = true
    var side: bool = direction in ["left", "right"] or mount == "wild_boar"
    var sheet: Texture2D = load("res://assets/game/sprites/%s/%s.png" % [TRAVEL.MOUNTS[mount][3], "side" if side else "front"])
    var frame_width: int = sheet.get_width() / 2
    var frame: int = int(Time.get_ticks_msec() / 160) % 2 if walking else 0
    _mount_sprite.texture = sheet
    _mount_sprite.region_enabled = true
    _mount_sprite.region_rect = Rect2(frame * frame_width, 0, frame_width, sheet.get_height())
    _mount_sprite.flip_h = side and facing.x < 0.0
    _mount_sprite.position = Vector2(0, SPRITES.FEET_Y - sheet.get_height() / 2.0 + 1.0)
    body_sprite.position.y = -6.0

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
    if DEV.xp and DEV.applies(self):
        amount *= DEV.XP_FACTOR
    # M11e: Scholar's Soup and the Moonlit Feast ("wisdom").
    if elixirs.has("wisdom"):
        amount = int(round(amount * (1.0 + elixir("wisdom") / 100.0)))
    # M11f: a pet's XP bonus.
    var pet_xp: float = preload("res://scripts/pets/pet_catalogue.gd").bonus(progression, "xp")
    if pet_xp > 0.0:
        amount = int(round(amount * (1.0 + pet_xp / 100.0)))
    # M14b: the guild's XP perk, and a share of what members earn feeds the guild.
    var guilds: Node = get_parent().get("guilds") if get_parent() != null else null
    if guilds != null:
        var guild_xp: int = guilds.perk(character_id, "xp")
        if guild_xp > 0:
            amount = int(round(amount * (1.0 + guild_xp / 100.0)))
        guilds.member_xp(self, amount)
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

## --- Chopping and mining (user request)
const CHOP := preload("res://scripts/visual/chopping.gd")
## Swings per deposit by tool tier (none, Basic, Fine, Master).
const SWINGS := [5, 4, 3, 2]
var gather_id := ""
var gather_resource := ""
var gather_at := Vector2.ZERO
var gather_swings := 0
var gather_clock := 0.0
## Seconds per swing (M6a: professions make swings faster or, below the requirement, slower).
var gather_period := 0.55
var _last_phase := 0.0
const PRO := preload("res://scripts/professions/profession_catalogue.gd")

## Host: start working a resource node (a tree or ore rock of the world, M6a).
func start_node(index: int) -> bool:
    var nodes: Node = get_parent().get("nodes")
    if nodes == null or not AUTHORITY.can_mutate(self) or $Health.current <= 0 or is_exhausted() or not nodes.intact(index):
        return false
    if global_position.distance_to(nodes.work_point(index)) > nodes.REACH + 6.0:
        return false
    var node: Dictionary = nodes.info(index)
    gather_id = "node:%d" % index
    gather_resource = {"woodcutting": "wood", "mining": "stone", "alchemy": "herb"}[node.profession]
    gather_at = node.foot + Vector2(0, -6)
    gather_swings = 1
    gather_period = nodes.swing_seconds(self, index)
    gather_clock = gather_period
    facing = (gather_at - global_position).normalized() if gather_at.distance_to(global_position) > 1.0 else facing
    return true

## M6c: where this character can craft for a profession ("" when nowhere): the camp's Forge
## (Smithing) or Essence Shrine (Alchemy), or any town.
func craft_station(profession: String) -> String:
    var map := preload("res://scripts/world/world_map.gd")
    if not map.town_at(global_position).is_empty():
        return "town"
    var camp: Node = get_parent().get("camp") if get_parent() != null else null
    if camp == null:
        return ""
    var key := "forge" if profession in ["smithing", "tailoring"] else "shrine"
    var site: Vector2 = camp.STRUCTURES["%s_1" % key].site
    if bool(camp.state.get(key, false)) and global_position.distance_to(site) <= 80.0:
        return key
    return ""

## How many of an ingredient this character has ("log_*"/"gem_*" count any log or gem).
func ingredient_count(id: String) -> int:
    # M11e: "fish_*" is any fish.
    if id == "fish_*":
        var fish_total := 0
        for fish in FISHES.FISH:
            fish_total += $Inventory.count_of(fish)
        return fish_total
    if id == "log_*" or id == "gem_*":
        var total := 0
        for other in (PRO.WOODS if id == "log_*" else PRO.GEMS):
            total += $Inventory.count_of(other)
        return total
    return $Inventory.count_of(id)

func _take_ingredient(id: String, count: int) -> void:
    if id == "fish_*":
        # The cheapest fish first.
        var fishes: Array = FISHES.FISH.keys()
        fishes.sort_custom(func(a, b): return int(FISHES.FISH[a][1]) < int(FISHES.FISH[b][1]))
        for fish in fishes:
            var take_fish: int = mini(count, $Inventory.count_of(fish))
            if take_fish > 0:
                $Inventory.discard(StringName(fish), take_fish)
                count -= take_fish
            if count <= 0:
                return
        return
    if id == "log_*" or id == "gem_*":
        # Cheapest first.
        var kinds: Array = (PRO.WOODS if id == "log_*" else PRO.GEMS).keys()
        kinds.sort_custom(func(a, b): return PRO.resource_price(a) < PRO.resource_price(b))
        for other in kinds:
            var take: int = mini(count, $Inventory.count_of(other))
            if take > 0:
                $Inventory.discard(StringName(other), take)
                count -= take
            if count <= 0:
                return
        return
    $Inventory.discard(StringName(id), count)

## Host: try a Smithing or Alchemy recipe (soft gate: the chance is shown in the window).
func craft(recipe_id: String) -> bool:
    if not AUTHORITY.can_mutate(self) or $Health.current <= 0:
        return false
    var recipe: Array = CRAFT.recipe(recipe_id)
    if recipe.is_empty():
        return false
    var profession: String = recipe[0]
    if craft_station(profession).is_empty():
        session.notify_character(character_id, "%s needs %s or a town." % [PRO.PROFESSIONS[profession][0], "the camp's Forge" if profession in ["smithing", "tailoring"] else "the camp's Essence Shrine"])
        return false
    var needs: Dictionary = recipe[3]
    for id in needs:
        if ingredient_count(id) < int(needs[id]):
            session.notify_character(character_id, "Missing ingredients for %s." % recipe[1])
            return false
    var forging := recipe_id.begins_with("forge:") or recipe_id.begins_with("tailor:")
    if forging and gear.items.size() >= GEAR.MAX_ITEMS:
        session.notify_character(character_id, "Your gear bag is full.")
        return false
    var level: int = PRO.level_of(progression, profession)
    var required: int = int(recipe[2])
    var rng: RandomNumberGenerator = get_parent().loot_rng if get_parent() != null and get_parent().get("loot_rng") != null else RandomNumberGenerator.new()
    # Thrifty (20): one try in five keeps the ingredients.
    if not (level >= 20 and rng.randf() < 0.2):
        for id in needs:
            _take_ingredient(id, int(needs[id]))
    if rng.randf() >= PRO.chance(level, required):
        gain_profession_xp(profession, maxi(1, PRO.xp_reward(required) / 5))
        session.notify_character(character_id, "%s failed — the ingredients are lost." % recipe[1])
        session.queue_save()
        return false
    var made := ""
    if forging:
        var parts: PackedStringArray = recipe_id.split(":")
        var weights: Array = CRAFT.forge_weights(level, required)
        var total := 0.0
        for weight in weights:
            total += weight
        var roll := rng.randf() * total
        var rarity := 0
        for index in range(weights.size()):
            roll -= weights[index]
            if roll <= 0.0:
                rarity = index
                break
        var base: String = CRAFT.tailor_base(parts[2], parts[1], rarity, rng) if recipe_id.begins_with("tailor:") else CRAFT.forge_base(parts[2], parts[1], rarity, rng)
        if base.is_empty():
            return false
        rarity = maxi(rarity, int(GEAR.BASES[base].get("min_rarity", 0)))
        var item: Dictionary = GEAR.roll(base, rarity, rng)
        add_item(item)
        made = "%s %s" % [GEAR.RARITIES[rarity], GEAR.display_name(item)]
        # M11e: Double Stitch (Tailoring 40).
        if profession == "tailoring" and level >= 40 and rng.randf() < 0.1 and gear.items.size() < GEAR.MAX_ITEMS:
            var twin: Dictionary = GEAR.roll(base, rarity, rng)
            if add_item(twin):
                made += " and a second one"
        gain_profession_xp(profession, PRO.xp_reward(required) * 3)
    else:
        var output: String = recipe_id.split(":")[1]
        # Double Smelt / Double Brew (40) and the level's double chance.
        var count := 2 if rng.randf() < PRO.double_chance(level) else 1
        # M11e: Steady Script (Enchanting 30).
        if profession == "enchanting" and level >= 30 and count == 1 and rng.randf() < 0.2:
            count = 2
        # Master Alchemist (50): elixirs brew twice.
        if profession == "alchemy" and level >= 50 and (output.begins_with("elixir_") or output == "senzu_bean"):
            count = 2
        var added: int = $Inventory.add_material(output, count)
        if added <= 0:
            session.notify_character(character_id, "Your bag is full.")
            return false
        made = "%d %s" % [added, TRADE.good_info(output)[0]]
        gain_profession_xp(profession, PRO.xp_reward(required) * 2)
        if get_parent().get("quests") != null:
            get_parent().quests.on_event(self, "craft", {"item": output, "amount": added})
    session.notify_character(character_id, "Made %s." % made)
    session.queue_save()
    return true

## Host: profession experience (M6a), with a message on each new level.
func gain_profession_xp(profession: String, amount: int) -> void:
    if amount <= 0 or not AUTHORITY.can_mutate(self) or not PRO.PROFESSIONS.has(profession):
        return
    if DEV.xp and DEV.applies(self):
        amount *= DEV.XP_FACTOR
    if not progression.get("professions") is Dictionary:
        progression["professions"] = PRO.initial_state()
    var before: int = PRO.level_for(int(progression.professions.get(profession, 0)))
    progression.professions[profession] = mini(PRO.max_xp(), int(progression.professions.get(profession, 0)) + amount)
    var after: int = PRO.level_for(int(progression.professions[profession]))
    if after > before:
        var text := "%s level %d!" % [PRO.PROFESSIONS[profession][0], after]
        for milestone in PRO.MILESTONES[profession]:
            if milestone[0] > before and milestone[0] <= after:
                text += " Milestone: %s (%s)." % [milestone[1], milestone[2]]
        session.notify_character(character_id, text)

## Host: start working a deposit (the camp checked reach and stock).
func start_gather(id: String, resource: String, at: Vector2) -> bool:
    if not AUTHORITY.can_mutate(self) or $Health.current <= 0 or is_exhausted():
        return false
    var tier: int = int(progression.get("tools", {}).get(CHOP.tool_for(resource), 0))
    gather_id = id
    gather_resource = resource
    gather_at = at
    gather_swings = SWINGS[clampi(tier, 0, 3)]
    gather_period = CHOP.SWING
    gather_clock = CHOP.SWING
    facing = (at - global_position).normalized() if at.distance_to(global_position) > 1.0 else facing
    return true

func stop_gather() -> void:
    gather_id = ""
    gather_swings = 0

## The swing in progress (0..1), for drawing on every peer.
func gather_phase() -> float:
    return 1.0 - clampf(gather_clock / maxf(0.05, gather_period), 0.0, 1.0)

func _tick_gather(delta: float) -> void:
    if gather_id.is_empty():
        return
    if gather_id.begins_with("node:"):
        var nodes: Node = get_parent().get("nodes")
        var index := int(gather_id.trim_prefix("node:"))
        if nodes == null or velocity.length() > 1.0 or $Health.current <= 0 or not nodes.intact(index) or global_position.distance_to(nodes.work_point(index)) > nodes.REACH + 10.0:
            stop_gather()
            return
        gather_clock -= delta
        if gather_clock <= 0.0:
            gather_period = nodes.swing_seconds(self, index)
            gather_clock = gather_period
            if not nodes.strike(self, index, get_parent().loot_rng):
                stop_gather()
        return
    var camp: Node = get_parent().get("camp")
    if camp == null or velocity.length() > 1.0 or $Health.current <= 0 or global_position.distance_to(gather_at) > 40.0 or int(camp.state.deposits.get(gather_id, 0)) <= 0:
        stop_gather()
        return
    gather_clock -= delta
    if gather_clock <= 0.0:
        gather_swings -= 1
        gather_clock = CHOP.SWING
        if gather_swings <= 0:
            var id := gather_id
            var resource := gather_resource
            stop_gather()
            if camp.transact(self, "gather", id):
                # M6a: the camp's deposits teach a little too.
                gain_profession_xp("woodcutting" if resource == "wood" else "mining", 10)

## Every peer: the impact moment of each swing (shake, chips, sound).
func _animate_gather() -> void:
    if gather_id.is_empty():
        _last_phase = 0.0
        return
    var phase := gather_phase()
    if _last_phase < CHOP.IMPACT and phase >= CHOP.IMPACT:
        var camp: Node = get_parent().get("camp")
        if camp != null:
            camp.shake[gather_id] = 0.25
        CHOP.impact(get_parent(), gather_at, gather_resource)
        if has_node("/root/Audio"):
            get_node("/root/Audio").play("gather", gather_at)
    _last_phase = phase
    queue_redraw()

## Weather (sandstorms slow walking a little).
func _weather_speed() -> float:
    var world: Node = get_parent()
    if world == null or not world.get("progression") is Dictionary:
        return 1.0
    var day_night := preload("res://scripts/world/day_night.gd")
    var map := preload("res://scripts/world/world_map.gd")
    if not map.dungeon_at(global_position).is_empty():
        return 1.0
    return day_night.speed_factor(day_night.weather(map.region_name(global_position), float(world.progression.get("world_time", 0.0))))

## --- M12a: attributes.
const ATTRIBUTES := preload("res://scripts/progression/attributes.gd")

## Host: spend one unspent point on an attribute (Vitality and Intelligence raise the maxima).
func spend_attribute(key: String) -> bool:
    if not AUTHORITY.can_mutate(self) or not key in ATTRIBUTES.KEYS or ATTRIBUTES.unspent(progression) <= 0:
        return false
    var all := ATTRIBUTES.spent(progression)
    all[key] = int(all[key]) + 1
    progression["attributes"] = all
    var gain: Array = ATTRIBUTES.capacity(key)
    _apply_stats(int(gain[0]), float(gain[1]), 0.0, 1)
    refresh_gear()
    session.queue_save()
    return true

## Host: give every point back (the class master, M12b).
func reset_attributes() -> void:
    if not AUTHORITY.can_mutate(self):
        return
    var all := ATTRIBUTES.spent(progression)
    for key in all:
        var gain: Array = ATTRIBUTES.capacity(key)
        _apply_stats(int(gain[0]) * int(all[key]), float(gain[1]) * int(all[key]), 0.0, -1)
    progression["attributes"] = {"str": 0, "dex": 0, "int": 0, "vit": 0}
    refresh_gear()

func current_speed() -> float:
    var boost: float = DEV.SPEED_FACTOR if DEV.speed and DEV.applies(self) else 1.0
    boost *= _weather_speed()
    return maxf(10.0, move_speed + gear_bonus("speed")) * FORMS.FORMS[form].speed * mount_speed() * aura_speed() * boost

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
    return equipped_items().any(func(item): return id in item.passives or item.get("runes", []).any(func(rune): return UPGRADES.RUNES[rune][1] == id))

## A stat from an item's socketed runes (M4.5d).
static func rune_bonus(item: Dictionary, stat: String) -> float:
    var total := 0.0
    for rune in item.get("runes", []):
        if UPGRADES.RUNES[rune][1] == stat:
            total += float(UPGRADES.RUNES[rune][2])
    return total

## A stat from installed augments (M4.5d).
func augment_bonus(stat: String) -> float:
    var total := 0.0
    for id in progression.get("augments", []):
        if UPGRADES.AUGMENTS[id][1] == stat:
            total += float(UPGRADES.AUGMENTS[id][2])
    return total

## Sum of a stat over equipped items, including the passives that are plain stat bonuses.
func gear_bonus(stat: String) -> float:
    var total := 0.0
    for item in equipped_items():
        total += float(item.stats.get(stat, 0)) + rune_bonus(item, stat)
        if stat == "speed" and "swift" in item.passives:
            total += 5.0
        if stat == "regen" and "wellspring" in item.passives:
            total += 0.5
    # Item expansion: set bonuses (two pieces) and unique abilities' stats.
    total += SETS.bonus(equipped_items(), GEAR.BASES, stat)
    # M6c: the Iron Skin elixir adds defence.
    if stat == "defense":
        total += elixir("iron")
    # M11f: the following pet.
    total += preload("res://scripts/pets/pet_catalogue.gd").bonus(progression, stat)
    # M12a: Dexterity (speed) and Vitality (defence).
    total += ATTRIBUTES.bonus(progression, stat)
    # Augments count like gear (their maxima are applied when installed).
    return total + augment_bonus(stat)

## Phoenix (unique ability): once every PHOENIX_COOLDOWN, survive a lethal hit at 1 HP.
const SETS := preload("res://scripts/items/set_catalogue.gd")
var phoenix_left := 0.0

func lethal_guard() -> bool:
    if phoenix_left > 0.0 or not SETS.has_ability(equipped_items(), GEAR.BASES, "phoenix"):
        return false
    phoenix_left = SETS.PHOENIX_COOLDOWN
    session.notify_character(character_id, "Phoenix! You rise from a lethal blow.")
    var burst := preload("res://scripts/visual/effects.gd").spawn(get_parent(), "ring", global_position)
    if burst != null:
        burst.modulate = Color("ff7a2a")
    return true

## Saved maxima and regeneration already include equipped gear; this re-derives the live parts.
func refresh_gear() -> void:
    $Health.armor = int(gear_bonus("defense"))
    queue_redraw()

func _apply_item(item: Dictionary, sign: int) -> void:
    _apply_stats(int(item.stats.get("hp", 0)) + int(rune_bonus(item, "hp")), float(item.stats.get("magicules", 0)) + rune_bonus(item, "magicules"), float(item.stats.get("regen", 0)) + (0.5 if "wellspring" in item.passives else 0.0) + rune_bonus(item, "regen"), sign)

## Capacity changes from gear, runes and augments: never refill current resources.
func _apply_stats(hp_amount: int, mp_amount: float, regen_amount: float, sign: int) -> void:
    var hp: int = hp_amount * sign
    $Health.maximum += hp
    # Reversible equipment changes capacity, never refills current resources.
    $Health.current = clampi($Health.current, 0, $Health.maximum)
    $Health.changed.emit($Health.current, $Health.maximum)
    var mp: float = mp_amount * sign
    $Magicules.maximum += mp
    $Magicules._current = clampf($Magicules._current, 0.0, $Magicules.maximum)
    $Magicules.changed.emit($Magicules.current, $Magicules.maximum)
    $Magicules.regeneration_per_second = maxf(0.0, $Magicules.regeneration_per_second + regen_amount * sign)

## Host: socket a rune from the bag into worn gear at the camp Smithy (M4.5d). The first worn
## item with a free socket takes it; replacing a rune destroys the old one.
func socket_rune(rune: String, item_id: String = "", index: int = -1) -> bool:
    if not AUTHORITY.can_mutate(self) or not UPGRADES.is_rune(rune) or $Inventory.count_of(rune) <= 0:
        return false
    var camp: Node = session.world.camp if is_instance_valid(session.world) else null
    if camp == null or not camp.state.get("smithy", false) or global_position.distance_to(camp.STRUCTURES.smithy_1.site) > UPGRADES.SMITHY_REACH:
        session.notify_character(character_id, "Runes are socketed at your camp's Smithy.")
        return false
    var target: Dictionary = item_by_id(item_id) if not item_id.is_empty() else {}
    if target.is_empty():
        for slot in ["weapon", "body", "head", "hands", "feet", "accessory_1", "accessory_2"]:
            var worn: Dictionary = item_by_id(progression.get("equipment", {}).get(slot, ""))
            if not worn.is_empty() and worn.get("runes", []).size() < UPGRADES.sockets(int(worn.rarity)):
                target = worn
                break
    if target.is_empty() or UPGRADES.sockets(int(target.rarity)) == 0:
        session.notify_character(character_id, "No free socket in your worn gear (Rare and Epic have 1, Legendary 2).")
        return false
    var runes: Array = target.get("runes", []).duplicate()
    var equipped: bool = target.id in progression.get("equipment", {}).values()
    if equipped:
        _apply_item(target, -1)
    if index >= 0 and index < runes.size():
        runes[index] = rune
    elif runes.size() < UPGRADES.sockets(int(target.rarity)):
        runes.append(rune)
    else:
        if equipped:
            _apply_item(target, 1)
        return false
    target["runes"] = runes
    if equipped:
        _apply_item(target, 1)
        refresh_gear()
    $Inventory.discard(StringName(rune), 1)
    session.notify_character(character_id, "%s socketed into %s." % [UPGRADES.RUNES[rune][0], GEAR.display_name(target)])
    session.queue_save()
    return true

## Host: install an augment from the bag at the Essence Shrine for Zeni (M4.5d). Slots open at
## levels 5, 10 and 15; when all are taken the oldest returns to the bag.
func install_augment(id: String) -> bool:
    if not AUTHORITY.can_mutate(self) or not UPGRADES.is_augment(id) or $Inventory.count_of(id) <= 0:
        return false
    var camp: Node = session.world.camp if is_instance_valid(session.world) else null
    if camp == null or not camp.state.get("shrine", false) or global_position.distance_to(camp.STRUCTURES.shrine_1.site) > UPGRADES.SHRINE_REACH:
        session.notify_character(character_id, "Augments are installed at your camp's Essence Shrine.")
        return false
    var slots := UPGRADES.augment_slots(int(progression.get("level", 1)))
    var installed: Array = progression.get("augments", [])
    if slots == 0:
        session.notify_character(character_id, "Augment slots open at levels 5, 10 and 15.")
        return false
    if id in installed:
        session.notify_character(character_id, "That augment is already installed.")
        return false
    if zeni() < UPGRADES.INSTALL_COST:
        session.notify_character(character_id, "Installing costs %d Zeni." % UPGRADES.INSTALL_COST)
        return false
    if installed.size() >= slots:
        var old: String = installed[0]
        if $Inventory.add_material(old, 1) != 1:
            session.notify_character(character_id, "Make room in the bag for the augment you replace.")
            return false
        installed.remove_at(0)
        _apply_augment(old, -1)
    spend_zeni(UPGRADES.INSTALL_COST)
    $Inventory.discard(StringName(id), 1)
    installed.append(id)
    progression["augments"] = installed
    _apply_augment(id, 1)
    session.notify_character(character_id, "%s installed (%d Zeni)." % [UPGRADES.AUGMENTS[id][0], UPGRADES.INSTALL_COST])
    session.queue_save()
    return true

func _apply_augment(id: String, sign: int) -> void:
    var entry: Array = UPGRADES.AUGMENTS[id]
    _apply_stats(int(entry[2]) if entry[1] == "hp" else 0, float(entry[2]) if entry[1] == "magicules" else 0.0, float(entry[2]) if entry[1] == "regen" else 0.0, sign)
    refresh_gear()

## Analysis time factor from augments (Absorber: 25% faster).
func absorb_factor() -> float:
    return maxf(0.25, 1.0 - augment_bonus("absorb"))

## --- Mounts (M4.5d)
func riding() -> String:
    return String(progression.get("mount", ""))

## --- Transformations (M4.7): a learned aura multiplies damage and speed and drains Magicules.
func aura() -> String:
    return String(progression.get("aura", ""))

func aura_damage() -> float:
    var might: float = 1.0 + elixir("might") / 100.0
    return (float(REALM.AURAS[aura()][1]) if REALM.AURAS.has(aura()) else 1.0) * might

func aura_speed() -> float:
    var swift: float = 1.0 + elixir("speed") / 100.0
    return (float(REALM.AURAS[aura()][2]) if REALM.AURAS.has(aura()) else 1.0) * swift

## Host: power up with the strongest learned transformation, or power down.
func toggle_aura() -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    if not aura().is_empty():
        progression["aura"] = ""
        session.notify_character(character_id, "You power down.")
        return true
    var learned: Array = progression.get("auras", [])
    if learned.is_empty():
        session.notify_character(character_id, "No transformation learned yet.")
        return false
    if $Health.current <= 0 or is_exhausted() or form != FORMS.BASE:
        return false
    var best: String = ""
    for id in REALM.AURA_ORDER:
        if id in learned:
            best = id
    if $Magicules.current < REALM.AURAS[best][3] * 2.0:
        session.notify_character(character_id, "Not enough Magicules to power up.")
        return false
    progression["aura"] = best
    session.notify_character(character_id, "%s! (x%.1f damage, -%d Magicules/s; X to power down)" % [REALM.AURAS[best][0], REALM.AURAS[best][1], int(REALM.AURAS[best][3])])
    return true

func _tick_aura(delta: float) -> void:
    if aura().is_empty():
        return
    var cost: float = float(REALM.AURAS[aura()][3]) * delta
    if $Health.current <= 0 or $Magicules.current < cost or not $Magicules.try_spend(cost):
        progression["aura"] = ""
        session.notify_character(character_id, "Your aura fades.")

func mount_speed() -> float:
    return 1.0 + float(TRAVEL.MOUNTS[riding()][1]) if TRAVEL.MOUNTS.has(riding()) else 1.0

## Host: ride an owned mount (the fastest one by default) or get off.
func toggle_mount(id: String = "") -> bool:
    if not AUTHORITY.can_mutate(self):
        return false
    if not riding().is_empty():
        dismount()
        return true
    var owned: Array = progression.get("mounts", [])
    if owned.is_empty():
        session.notify_character(character_id, "No mount yet: buy one at a stable (Brookhaven, Amberhold, Dunemarch) or tame one in the wild.")
        return false
    if $Health.current <= 0 or is_exhausted() or form != FORMS.BASE or fishing_bite_in != -INF:
        return false
    var pick: String = id if id in owned else owned.reduce(func(best, other): return other if TRAVEL.MOUNTS[other][1] > TRAVEL.MOUNTS[best][1] else best, owned[0])
    progression["mount"] = pick
    session.notify_character(character_id, "Riding: %s (+%d%% speed)." % [TRAVEL.MOUNTS[pick][0], int(TRAVEL.MOUNTS[pick][1] * 100)])
    return true

func dismount() -> void:
    if AUTHORITY.can_mutate(self) and not riding().is_empty():
        progression["mount"] = ""

## Host: try to tame the wild animal you stand beside with its favourite material.
func tame(wild_id: String) -> bool:
    if not AUTHORITY.can_mutate(self) or _tame_cooldown > 0.0:
        return false
    var wild: Array = []
    for entry in TRAVEL.WILD_MOUNTS:
        if entry[0] == wild_id:
            wild = entry
    if wild.is_empty() or global_position.distance_to(preload("res://scripts/world/world_map.gd").to_world(wild[2])) > TRAVEL.TAME_REACH + 24.0:
        return false
    var spec: Array = TRAVEL.MOUNTS[wild[1]]
    if wild[1] in progression.get("mounts", []):
        session.notify_character(character_id, "You already ride a %s." % spec[0])
        return false
    if $Inventory.count_of(spec[4]) < spec[5]:
        session.notify_character(character_id, "The %s might trust you if you offer %d %s." % [spec[0], spec[5], spec[4].replace("_", " ")])
        return false
    for _i in range(spec[5]):
        $Inventory.discard(StringName(spec[4]), 1)
    _tame_cooldown = TRAVEL.TAME_COOLDOWN
    if randf() >= float(spec[6]):
        session.notify_character(character_id, "The %s takes the offering and runs off. Try again." % spec[0])
        return true
    progression.mounts.append(wild[1])
    session.notify_character(character_id, "The %s trusts you now! Ride it with H." % spec[0])
    session.queue_save()
    return true

## --- Fishing (M4.5d)
## Host: cast at the water in front of you (a fishing rod needed).
func cast_line() -> bool:
    if not AUTHORITY.can_mutate(self) or $Health.current <= 0 or fishing_bite_in != -INF:
        return false
    var tier: int = int(progression.get("tools", {}).get("rod", 0))
    if tier <= 0:
        session.notify_character(character_id, "You need a fishing rod (town merchants sell them).")
        return false
    var map := preload("res://scripts/world/world_map.gd")
    var spot: Vector2 = global_position + facing.normalized() * TRAVEL.FISH_REACH
    var tile: Vector2i = map.to_tile(spot)
    if not map.in_grid(tile):
        return false
    var data: Dictionary = map.data()
    var lake: bool = data.lake[map.vertex_index(tile.x, tile.y)] == 1
    if not lake and data.ocean[map.vertex_index(tile.x, tile.y)] == 0:
        session.notify_character(character_id, "Face the water to fish.")
        return false
    dismount()
    _fishing_lake = lake
    _fishing_spot = global_position
    fishing_window = FISHES.REEL_SECONDS
    reel = {}
    # Fishing 20 (Patient): bites come 25% sooner.
    var patience: float = 0.75 if PRO.level_of(progression, "fishing") >= 20 else 1.0
    # Rain and storms make fish bite sooner.
    var day_night := preload("res://scripts/world/day_night.gd")
    var wet: float = day_night.bite_factor(day_night.weather(map.region_name(global_position), float(get_parent().progression.get("world_time", 0.0))))
    fishing_bite_in = randf_range(TRAVEL.BITE_DELAY[0], TRAVEL.BITE_DELAY[1]) * patience * wet
    session.notify_character(character_id, "You cast your line… wait for a bite.")
    return true

## Host: a fish bites — pick it and start the reel-in minigame.
func _hook_fish() -> void:
    var map := preload("res://scripts/world/world_map.gd")
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var rod: int = int(progression.get("tools", {}).get("rod", 0))
    var level: int = PRO.level_of(progression, "fishing")
    var day_night := preload("res://scripts/world/day_night.gd")
    var time: float = float(get_parent().progression.get("world_time", 0.0))
    var region: String = map.region_name(_fishing_spot)
    var fish: String = FISHES.pick(region, _fishing_lake, rod, level, rng, day_night.is_night(time), day_night.weather(region, time))
    var rarity: int = int(FISHES.FISH[fish][4])
    var width: float = FISHES.zone(level, fish, rod)
    reel = {"fish": fish, "rarity": rarity, "need": FISHES.HITS[rarity], "hits": 0, "misses": 0, "centre": rng.randf_range(width / 2.0, 1.0 - width / 2.0), "width": width, "speed": FISHES.SPEED[rarity], "t": 0.0}
    session.notify_character(character_id, "%s bite! Press F while the marker is in the green zone (%d%% per press, %d hit%s)." % [FISHES.RARITIES[rarity], int(round(width * 100.0)), reel.need, "" if reel.need == 1 else "s"])

## Host: land the hooked fish (bag, fish log, XP); mythical catches are announced to everyone.
func _land_fish() -> bool:
    var fish: String = reel.fish
    var rarity: int = int(reel.rarity)
    reel = {}
    fishing_bite_in = -INF
    if $Inventory.add_material(fish, 1) != 1:
        session.notify_character(character_id, "Caught a %s, but the bag is full — it slipped back." % FISHES.FISH[fish][0])
        return false
    if not progression.get("fish_log") is Dictionary:
        progression["fish_log"] = {}
    var first: bool = not progression.fish_log.has(fish)
    progression.fish_log[fish] = int(progression.fish_log.get(fish, 0)) + 1
    gain_profession_xp("fishing", FISHES.xp_for(fish))
    if get_parent().get("quests") != null:
        get_parent().quests.on_event(self, "catch", {"fish": fish})
    session.notify_character(character_id, "Caught a %s (%s)!%s" % [FISHES.FISH[fish][0], FISHES.RARITIES[rarity], " New in your fish log." if first else ""])
    if rarity >= 5 and get_parent() != null and get_parent().has_method("_announce"):
        get_parent()._announce("A mythical %s was landed!" % FISHES.FISH[fish][0])
    session.queue_save()
    return true

func _lose_fish(message: String) -> void:
    if not reel.is_empty():
        gain_profession_xp("fishing", maxi(1, FISHES.xp_for(reel.fish) / 10))
    reel = {}
    fishing_bite_in = -INF
    session.notify_character(character_id, message)

## Host: pull in the line: a catch inside the bite window, nothing too early or too late.
## M6b: F while a fish is hooked: a hit when the marker is in the green zone (enough hits land
## it), a miss otherwise (too many and it escapes). F before a bite pulls the line in empty.
func reel_in() -> bool:
    if not AUTHORITY.can_mutate(self) or fishing_bite_in == -INF:
        return false
    if reel.is_empty():
        fishing_bite_in = -INF
        session.notify_character(character_id, "Too early — nothing on the line.")
        return false
    var at: float = FISHES.marker(float(reel.t), float(reel.speed))
    if absf(at - float(reel.centre)) <= float(reel.width) / 2.0:
        reel.hits = int(reel.hits) + 1
        if int(reel.hits) >= int(reel.need):
            return _land_fish()
        # The fish pulls: the zone moves.
        var width: float = reel.width
        reel.centre = clampf(1.0 - float(reel.centre) + randf_range(-0.15, 0.15), width / 2.0, 1.0 - width / 2.0)
        return true
    reel.misses = int(reel.misses) + 1
    if int(reel.misses) > FISHES.MISSES:
        _lose_fish("The line went slack — it escaped.")
        return false
    return true

func _tick_fishing(delta: float) -> void:
    _tame_cooldown = maxf(0.0, _tame_cooldown - delta)
    if fishing_bite_in == -INF:
        return
    if global_position.distance_to(_fishing_spot) > 6.0 or $Health.current <= 0:
        fishing_bite_in = -INF
        return
    var before := fishing_bite_in
    fishing_bite_in -= delta
    if before > 0.0 and fishing_bite_in <= 0.0 and AUTHORITY.can_mutate(self):
        _hook_fish()
    elif not reel.is_empty():
        reel.t = float(reel.t) + delta
        if float(reel.t) > FISHES.REEL_SECONDS and AUTHORITY.can_mutate(self):
            _lose_fish("It fought too long and got away.")
    elif fishing_bite_in < -fishing_window:
        fishing_bite_in = -INF

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
    # M12b: level, class and attribute requirements.
    var why: String = preload("res://scripts/progression/class_catalogue.gd").problem(progression, item)
    if not why.is_empty():
        session.notify_character(character_id, "%s: %s" % [GEAR.display_name(item), why])
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
    _animate_gather()
    if fishing_bite_in != -INF:
        queue_redraw()
    if session.replica_world:
        return
    if death_left > 0.0 and $Health.current <= 0:
        death_left = maxf(0.0, death_left - delta)
        if death_left <= 0.0:
            session.respawn_character(self)
    form_cooldown = maxf(0.0, form_cooldown - delta)
    if $Health.current > 0:
        _tick_consumables(delta)
    _tick_fishing(delta)
    _tick_aura(delta)
    _tick_gather(delta)
    phoenix_left = maxf(0.0, phoenix_left - delta)
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
    if event.is_action_pressed("aura") and not event.is_echo():
        session.request_action("aura", {"operation": "toggle"})
        return
    if event.is_action_pressed("mount") and not event.is_echo():
        session.request_action("mount", {"operation": "toggle"})
        return
    for potion in [["use_draught", "healing_draught"], ["use_tonic", "magicule_tonic"]]:
        if event.is_action_pressed(potion[0]) and not event.is_echo():
            session.request_action("use_item", {"id": potion[1]})
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
        for action in ["attack", "absorb", "skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6", "skill_7", "skill_8"]:
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
    if fishing_bite_in != -INF and has_node("Health") and $Health.current > 0:
        _draw_line()
    if not gather_id.is_empty() and has_node("Health") and $Health.current > 0 and gather_resource != "herb":
        CHOP.draw_tool(self, CHOP.tool_for(gather_resource), gather_phase(), facing)
    if has_node("Health") and $Health.current > 0 and not exhaustion_active and form == FORMS.BASE:
        _draw_gear()

## The weapon in hand (user feedback: the old coloured lines looked odd): the item's own icon,
## held at the side the character faces (behind the body when facing away).
var _weapon_icon: Texture2D
var _weapon_icon_key := ""

var _weapon_fx: CPUParticles2D

## M6b: the rod's line and bobber on the water; a hooked fish pulls the bobber under.
func _draw_line() -> void:
    var direction := facing.normalized() if facing.length() > 0.1 else Vector2.DOWN
    var tip := direction * 8.0 + Vector2(0, -12)
    var now := Time.get_ticks_msec() / 1000.0
    var bobber := direction * TRAVEL.FISH_REACH + Vector2(0, sin(now * 3.0) * 1.0)
    var hooked := not reel.is_empty()
    if hooked:
        bobber += Vector2(sin(now * 31.0) * 1.5, 2.0)
    draw_line(Vector2(0, -6) + direction * 3.0, tip, Color("6b4a2b"), 1.0)
    draw_line(tip, bobber, Color(0.92, 0.92, 0.92, 0.8), 1.0)
    if hooked:
        var ripple := fmod(now * 2.0, 1.0)
        draw_arc(bobber, 3.0 + ripple * 6.0, 0, TAU, 16, Color(1, 1, 1, 0.6 * (1.0 - ripple)), 1.0)
        draw_circle(bobber, 1.5, Color("d4473f"))
    else:
        draw_circle(bobber, 2.0, Color("d4473f"))
        draw_rect(Rect2(bobber + Vector2(-2, -1), Vector2(4, 1)), Color.WHITE)

func _draw_weapon(item: Dictionary) -> void:
    var key := "%s:%d" % [item.base, int(item.rarity)]
    if key != _weapon_icon_key:
        _weapon_icon_key = key
        _weapon_icon = GEAR.icon_texture(item.base, int(item.rarity))
        _update_weapon_fx(item)
    if _weapon_icon == null:
        return
    var side := 1.0 if facing.x >= -0.1 else -1.0
    var size := Vector2(14, 14)
    var at := Vector2(7.0 * side, 0.0) if absf(facing.x) > 0.3 else Vector2(8.0, 1.0)
    # Rare and up glow (pulsing); the colour is the element's, else the rarity's.
    var rarity: int = int(item.rarity)
    if rarity >= 2:
        var element: String = String(GEAR.BASES[item.base].get("element", ""))
        var glow: Color = preload("res://scripts/items/element_catalogue.gd").color(element) if not element.is_empty() else Color(GEAR.RARITY_COLORS[rarity])
        var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
        draw_circle(at + Vector2(0, -4), 5.0 + rarity * 1.2, Color(glow, 0.08 + 0.05 * rarity + 0.06 * pulse))
    if is_instance_valid(_weapon_fx):
        _weapon_fx.position = at + Vector2(0, -4)
    draw_set_transform(at, 0.0, Vector2(side, 1.0))
    draw_texture_rect(_weapon_icon, Rect2(-size / 2.0 - Vector2(0, 4), size), false)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Epic and up: sparks rise from the weapon (more and bigger for Legendary and Mythic).
func _update_weapon_fx(item: Dictionary) -> void:
    var rarity: int = int(item.rarity) if not item.is_empty() else 0
    if rarity < 3 or preload("res://scripts/visual/effects.gd").reduced:
        if is_instance_valid(_weapon_fx):
            _weapon_fx.queue_free()
        _weapon_fx = null
        return
    if not is_instance_valid(_weapon_fx):
        _weapon_fx = CPUParticles2D.new()
        _weapon_fx.name = "WeaponFx"
        _weapon_fx.local_coords = false
        _weapon_fx.direction = Vector2.UP
        _weapon_fx.spread = 40.0
        _weapon_fx.gravity = Vector2(0, -18)
        _weapon_fx.initial_velocity_min = 4.0
        _weapon_fx.initial_velocity_max = 12.0
        _weapon_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
        _weapon_fx.emission_sphere_radius = 4.0
        add_child(_weapon_fx)
    var element: String = String(GEAR.BASES[item.base].get("element", ""))
    var colour: Color = preload("res://scripts/items/element_catalogue.gd").color(element) if not element.is_empty() else Color(GEAR.RARITY_COLORS[rarity])
    _weapon_fx.amount = [0, 0, 0, 6, 12, 22][rarity]
    _weapon_fx.lifetime = 0.6 + 0.15 * rarity
    _weapon_fx.scale_amount_min = 0.8
    _weapon_fx.scale_amount_max = 1.0 + 0.4 * (rarity - 3)
    var ramp := Gradient.new()
    ramp.set_color(0, Color(colour.lightened(0.3), 0.9))
    ramp.set_color(1, Color(colour, 0.0))
    _weapon_fx.color_ramp = ramp
    _weapon_fx.emitting = true

## Distinct, rarity-coloured looks per item base (placeholders until the sprite step).
func _draw_gear() -> void:
    # No weapon (or a plain one): no weapon sparks.
    if is_instance_valid(_weapon_fx) and item_by_id(progression.get("equipment", {}).get("weapon", "")).is_empty():
        _update_weapon_fx({})
        _weapon_icon_key = ""
    # User request: no coloured bars for worn armour and jewellery (they looked odd); the weapon
    # in hand is the only gear drawn on the character.
    var weapon: Dictionary = item_by_id(progression.get("equipment", {}).get("weapon", ""))
    if not weapon.is_empty():
        _draw_weapon(weapon)

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
