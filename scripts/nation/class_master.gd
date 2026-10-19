extends Node2D
## The old master (M12b, user design): a master of every weapon and martial art who moves into
## your settlement when it is founded and stays there. Talking to him (F) opens the class window:
## choose a main class, a subclass from level 20, change them for Zeni, or reset your attribute
## points. Host rules here (the "class" intent); drawn on every peer. Every character's equipped
## gear is checked against its requirements (a piece that no longer fits goes back to the bag).
const CLASSES := preload("res://scripts/progression/class_catalogue.gd")
const ATTRIBUTES := preload("res://scripts/progression/attributes.gd")
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const AUTHORITY := preload("res://scripts/network/authority.gd")
const OFFSET := Vector2(-56, 34)
const REACH := 36.0
const CHECK_SECONDS := 1.0

var world: Node2D
var _body: Node2D
var _check_left := 0.0

func _init(owner_world: Node2D = null) -> void:
    world = owner_world
    name = "ClassMaster"
    y_sort_enabled = true

func _ready() -> void:
    _body = Node2D.new()
    var sprite := SPRITES.make("npc_class_master")
    sprite.name = "Sprite"
    _body.add_child(sprite)
    SPRITES.play(sprite, "idle_down")
    add_child(_body)

func session() -> Node:
    return get_node("/root/GameSession")

func position_in_world() -> Vector2:
    var camp: Node = world.get("camp") if world != null else null
    return (camp.SITE if camp != null else Vector2.ZERO) + OFFSET

## User report: he was missing in a friend's world whose camp was not founded yet; every player
## needs him for classes, so he lives at the camp site from the start in every world.
func present() -> bool:
    return world != null and world.get("camp") != null

func near(actor: Node2D) -> bool:
    return present() and actor.global_position.distance_to(position_in_world()) <= REACH

## --- Host operations.
## Choose (or change) the main class or the subclass; the first choice of each is free.
func choose(actor: Node2D, slot: String, id: String) -> bool:
    if not AUTHORITY.can_mutate(actor) or not near(actor) or not slot in ["main", "sub"] or not CLASSES.CLASSES.has(id):
        return false
    var mine := CLASSES.chosen(actor.progression)
    if slot == "sub":
        if int(actor.progression.get("level", 1)) < CLASSES.SUB_LEVEL:
            _tell(actor, "Come back at level %d for a subclass." % CLASSES.SUB_LEVEL)
            return false
        if mine.main.is_empty() or id == mine.main:
            _tell(actor, "Choose a main class first, and a different subclass.")
            return false
    elif id == mine.sub:
        _tell(actor, "That is your subclass already.")
        return false
    if mine[slot] == id:
        return false
    if not String(mine[slot]).is_empty():
        var price := CLASSES.change_price(actor.progression)
        if not actor.spend_zeni(price):
            _tell(actor, "Changing your %s costs %d Zeni." % ["class" if slot == "main" else "subclass", price])
            return false
    mine[slot] = id
    actor.progression["classes"] = mine
    # M12c: the new main class's skills replace the old ones.
    actor.get_node("SkillBook").sync_class_skills()
    enforce(actor)
    _tell(actor, "The master nods: you are now a %s%s." % [CLASSES.CLASSES[id][0], "" if slot == "main" else " (subclass)"])
    session().queue_save()
    return true

func reset_attributes(actor: Node2D) -> bool:
    if not AUTHORITY.can_mutate(actor) or not near(actor):
        return false
    var used: int = ATTRIBUTES.total_points(actor.progression) - ATTRIBUTES.unspent(actor.progression)
    if used <= 0:
        return false
    var price := CLASSES.change_price(actor.progression)
    if not actor.spend_zeni(price):
        _tell(actor, "Resetting your attributes costs %d Zeni." % price)
        return false
    actor.reset_attributes()
    enforce(actor)
    _tell(actor, "Your attribute points are free to spend again.")
    session().queue_save()
    return true

## Unequip every worn piece the character can no longer use (back into the bag).
func enforce(actor: Node2D) -> void:
    if not AUTHORITY.can_mutate(actor):
        return
    var equipment: Dictionary = actor.progression.get("equipment", {})
    for slot in equipment.keys():
        var item: Dictionary = actor.item_by_id(equipment[slot])
        if item.is_empty():
            continue
        var why := CLASSES.problem(actor.progression, item)
        if not why.is_empty() and actor.unequip(slot):
            _tell(actor, "%s went back into your bag: %s" % [GEAR.display_name(item), why])

func _tell(actor: Node, message: String) -> void:
    session().notify_character(actor.character_id, message)

func _physics_process(delta: float) -> void:
    if world == null or session().replica_world:
        return
    _check_left -= delta
    if _check_left > 0.0:
        return
    _check_left = CHECK_SECONDS
    for actor in get_tree().get_nodes_in_group("player"):
        if actor.get_parent() == world:
            enforce(actor)
            # M12c: the second class skill arrives at level 25.
            if actor.get_node("SkillBook").sync_class_skills():
                _tell(actor, "The master's teaching takes hold: new class skill.")

func _process(_delta: float) -> void:
    if _body == null:
        return
    _body.visible = present()
    _body.position = position_in_world()
    queue_redraw()

func _draw() -> void:
    if not present():
        return
    var me: Node2D = world.get_local_player() if world.has_method("get_local_player") else null
    if me == null or me.global_position.distance_to(position_in_world()) > 400.0:
        return
    var font := ThemeDB.fallback_font
    var at := position_in_world()
    draw_string_outline(font, at + Vector2(-30, -22), "Old Master", HORIZONTAL_ALIGNMENT_CENTER, 60, 8, 3, Color(0.05, 0.04, 0.02))
    draw_string(font, at + Vector2(-30, -22), "Old Master", HORIZONTAL_ALIGNMENT_CENTER, 60, 8, Color("ffe08a"))
    if CLASSES.chosen(me.progression).main.is_empty():
        var bob := sin(Time.get_ticks_msec() / 250.0) * 1.5
        draw_string_outline(font, at + Vector2(-3, -30 + bob), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0.05, 0.04, 0.02))
        draw_string(font, at + Vector2(-3, -30 + bob), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffd84a"))
