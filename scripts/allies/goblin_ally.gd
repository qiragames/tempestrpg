extends CharacterBody2D
## Citizens belong to stable character IDs; disconnecting never transfers ownership.
const AUTHORITY := preload("res://scripts/network/authority.gd")
const INTERACTION_RANGE := 40.0
const NAMING_COST := 80.0
const RECOVERY_SECONDS := 8.0
const GATHER_SECONDS := 3.0
const BUILD_SECONDS := 4.0
@export var entity_id: String = "ally_goblin_1"
var owner_id: String = ""
var display_name: String = ""
var race: String = "Goblin"
var maximum_hp: int = 30
var power: int = 4
var follow_speed: float = 45.0
var work_role: String = "follow"
var work_target: String = ""
var work_left: float = 0.0

func _ready() -> void:
    add_to_group("allies")

func can_reach(actor: Node2D) -> bool:
    if actor.global_position.distance_to(global_position) > INTERACTION_RANGE:
        return false
    var ray := PhysicsRayQueryParameters2D.create(actor.global_position, global_position, 1)
    return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func threat_cleared() -> bool:
    var threat = get_parent().entity_by_id("gnasher_1")
    return threat == null or threat.get_node("Health").current <= 0

func try_recruit(actor: Node2D) -> bool:
    if not AUTHORITY.can_mutate(self) or not owner_id.is_empty() or actor.get_node("Health").current <= 0 or actor.is_exhausted() or not can_reach(actor):
        return false
    var session := get_node("/root/GameSession")
    if not threat_cleared():
        session.notify_character(actor.character_id, "The goblin fears the clearing's Gnasher. Defeat it first.")
        return false
    owner_id = actor.character_id
    queue_redraw()
    session.notify_character(owner_id, "A nameless goblin has joined you.")
    session.queue_save()
    return true

static func valid_name(value: String) -> bool:
    if value != value.strip_edges():
        return false
    var pattern := RegEx.new()
    pattern.compile("^[A-Za-z][A-Za-z0-9 '-]{1,23}$")
    return pattern.search(value) != null

func try_name(actor: Node2D, value: String) -> bool:
    if not AUTHORITY.can_mutate(self) or owner_id != actor.character_id or not display_name.is_empty() or actor.get_node("Health").current <= 0 or actor.is_exhausted() or not can_reach(actor):
        return false
    var name_value := value.strip_edges()
    var session := get_node("/root/GameSession")
    if not valid_name(name_value):
        session.notify_character(owner_id, "Use 2-24 letters/digits, spaces, apostrophes or hyphens; start with a letter.")
        return false
    for ally in get_tree().get_nodes_in_group("allies"):
        if not ally.display_name.is_empty() and ally.display_name.to_lower() == name_value.to_lower():
            session.notify_character(owner_id, "That ally name is already in use.")
            return false
    if not actor.get_node("Magicules").try_spend(NAMING_COST):
        session.notify_character(owner_id, "Naming requires 80 Magicules.")
        return false
    # A single host-side transaction: resource transfer, name, race and base stats.
    display_name = name_value
    race = "Hobgoblin"
    maximum_hp = 60
    power = 8
    follow_speed = 65.0
    if actor.get_node("Magicules").current < actor.get_node("Magicules").maximum * 0.25:
        actor.begin_exhaustion(RECOVERY_SECONDS)
    queue_redraw()
    session.notify_character(owner_id, "%s evolved into a Hobgoblin. 80 Magicules transferred." % display_name)
    session.queue_save()
    return true

func can_assign_work(actor: Node2D, role: String) -> bool:
    var camp = get_parent().camp
    if owner_id != actor.character_id or display_name.is_empty() or race != "Hobgoblin" or not camp.can_reach(actor, camp.SITE, 55):
        return false
    if role not in ["follow", "gather", "build"] or role == work_role:
        return false
    if role != "follow" and (not camp.state.founded or global_position.distance_to(camp.SITE) > 100):
        return false
    if role == "build" and camp.next_buildable().is_empty():
        return false
    if role == "gather" and _next_deposit().is_empty():
        return false
    return true

func assign_work(actor: Node2D, role: String) -> bool:
    if not AUTHORITY.can_mutate(self) or not can_assign_work(actor, role):
        return false
    work_role = role
    var camp = get_parent().camp
    work_target = _next_deposit() if role == "gather" else camp.next_buildable() if role == "build" else ""
    work_left = _work_seconds(role)
    get_node("/root/GameSession").notify_character(owner_id, "%s: %s assigned." % [display_name, role])
    get_node("/root/GameSession").queue_save()
    return true

## A built storehouse shortens each job; the remaining time of a job in progress is kept.
func _work_seconds(role: String) -> float:
    var base := GATHER_SECONDS if role == "gather" else BUILD_SECONDS if role == "build" else 0.0
    return base * get_parent().camp.work_factor()

func _next_deposit() -> String:
    var camp = get_parent().camp
    var target := ""
    var distance := INF
    for id in camp.DEPOSITS:
        var current: float = global_position.distance_to(camp.DEPOSITS[id].position)
        # Outlying deposits are exploration rewards for players; workers stay near camp.
        if camp.state.deposits[id] > 0 and not camp.DEPOSITS[id].outlying and current < distance:
            target = id
            distance = current
    return target

func _finish_work(message: String) -> void:
    work_role = "follow"
    work_target = ""
    work_left = 0.0
    get_node("/root/GameSession").notify_character(owner_id, message)
    get_node("/root/GameSession").queue_save()

func _work_tick(delta: float) -> void:
    var camp = get_parent().camp
    if work_role == "gather" and (work_target.is_empty() or camp.state.deposits[work_target] == 0):
        work_target = _next_deposit()
        work_left = _work_seconds("gather")
        if work_target.is_empty():
            _finish_work("All nearby deposits gathered. Ally returning to follow.")
            return
    if work_role == "build" and not camp.affordable(work_target):
        # Someone else finished this structure, or spent its materials first.
        _finish_work("%s complete. Ally returning to follow." % camp.STRUCTURES[work_target].name if camp.built(work_target) else "Construction materials ran out. Ally returning to follow.")
        return
    var target: Vector2 = camp.DEPOSITS[work_target].position if work_role == "gather" else camp.SITE
    if global_position.distance_to(target) > 10:
        velocity = global_position.direction_to(target) * follow_speed
        move_and_slide()
        return
    var ray := PhysicsRayQueryParameters2D.create(global_position, target, 1)
    if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty() or (work_role == "build" and not camp.build_ready(work_target)):
        return
    work_left = maxf(0.0, work_left - delta)
    if work_left > 0:
        return
    if work_role == "gather":
        if camp.harvest(work_target):
            get_node("/root/GameSession").notify_character(owner_id, "%s gathered materials for camp." % display_name)
        work_target = ""
    elif camp.complete(work_target):
        _finish_work("Ally completed the %s." % camp.STRUCTURES[work_target].name)

func _physics_process(delta: float) -> void:
    if not AUTHORITY.can_mutate(self):
        return
    velocity = Vector2.ZERO
    if work_role != "follow":
        _work_tick(delta)
        return
    var owner = get_parent().player_by_id(owner_id)
    if owner != null and owner.get_node("Health").current > 0 and global_position.distance_to(owner.global_position) > 28.0:
        velocity = global_position.direction_to(owner.global_position) * follow_speed
        move_and_slide()

func _draw() -> void:
    if race == "Hobgoblin":
        draw_rect(Rect2(-7, -20, 14, 11), Color("749f66"))
        draw_rect(Rect2(-11, -16, 4, 5), Color("749f66"))
        draw_rect(Rect2(7, -16, 4, 5), Color("749f66"))
        draw_rect(Rect2(-8, -9, 16, 15), Color("495c77"))
        draw_rect(Rect2(-8, -9, 16, 3), Color("bca575"))
        draw_rect(Rect2(-7, 6, 5, 7), Color("283442"))
        draw_rect(Rect2(2, 6, 5, 7), Color("283442"))
        draw_rect(Rect2(-4, -16, 2, 2), Color("172f32"))
        draw_rect(Rect2(2, -16, 2, 2), Color("172f32"))
        draw_line(Vector2(13, -19), Vector2(13, 10), Color("cbb891"), 2)
        draw_circle(Vector2(0, 16), 3, Color("71e4d4"))
        return
    draw_rect(Rect2(-5, -12, 10, 9), Color("759954"))
    draw_rect(Rect2(-8, -10, 3, 4), Color("759954"))
    draw_rect(Rect2(5, -10, 3, 4), Color("759954"))
    draw_rect(Rect2(-5, -3, 10, 9), Color("7d6850"))
    draw_rect(Rect2(-4, 6, 3, 4), Color("3d4538"))
    draw_rect(Rect2(1, 6, 3, 4), Color("3d4538"))
    draw_rect(Rect2(-3, -8, 2, 2), Color("172f32"))
    draw_rect(Rect2(1, -8, 2, 2), Color("172f32"))
    draw_circle(Vector2(0, 13), 2, Color("71e4d4") if not owner_id.is_empty() else Color("d7b16d"))
