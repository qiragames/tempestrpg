extends Panel
## UI sends an entity ID only; the host validates the actual interacting character.
var ally_id: String = ""
var _title: Label
var _details: Label
var _recruit: Button
var _close: Button
var _paused_before: bool = false
@onready var hud = get_parent()
@onready var session: Node = get_node("/root/GameSession")

func _ready() -> void:
    position = Vector2(70, 120)
    size = Vector2(340, 150)
    add_theme_stylebox_override("panel", hud._panel_style())
    _title = hud._label("NAMELESS GOBLIN", Vector2(12, 10), Vector2(260, 24), self, 14)
    _details = hud._label("", Vector2(12, 39), Vector2(316, 66), self, 11)
    _recruit = hud._button("Recruit", Vector2(12, 108), Vector2(170, 28), self)
    _recruit.pressed.connect(func(): session.request_action("recruit", {"id": ally_id}))
    _close = hud._button("Close", Vector2(190, 108), Vector2(138, 28), self)
    _close.pressed.connect(close_dialog)
    hide()

func open_nearest() -> void:
    if hud.menu_open() or hud.player.get_node("Health").current <= 0:
        return
    var closest: Node2D
    var distance: float = 40.1
    for candidate in get_tree().get_nodes_in_group("allies"):
        var current: float = hud.player.global_position.distance_to(candidate.global_position)
        if current <= 40.0 and current < distance:
            closest = candidate
            distance = current
    if closest == null:
        hud.record_event("No ally nearby. Find the goblin to the west.")
        return
    ally_id = closest.entity_id
    _paused_before = get_tree().paused
    if session.active:
        hud.player.input_blocked = true
        session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    show()
    _refresh()
    _close.grab_focus()

func _process(_delta: float) -> void:
    if visible:
        _refresh()

func _refresh() -> void:
    var ally = hud.get_parent().entity_by_id(ally_id)
    if ally == null:
        close_dialog()
        return
    var ours: bool = ally.owner_id == hud.player.character_id
    _title.text = "NAMELESS GOBLIN" if ally.display_name.is_empty() else ally.display_name
    _details.text = "%s · HP %d · Power %d\n%s" % [ally.race, ally.maximum_hp, ally.power, "Joined you. The goblin will follow." if ours else "Already follows another player." if not ally.owner_id.is_empty() else "Defeat the clearing's Gnasher, then offer your friendship."]
    _recruit.text = "Ally recruited" if ours else "Recruit"
    _recruit.disabled = not ally.owner_id.is_empty() or not ally.can_reach(hud.player) or not ally.threat_cleared() or hud.player.get_node("Health").current <= 0

func close_dialog() -> void:
    if not visible:
        return
    hide()
    if session.active:
        hud.player.input_blocked = false
        session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and not event.is_echo():
        if visible:
            close_dialog()
        else:
            open_nearest()
        get_viewport().set_input_as_handled()
    elif visible and event.is_action_pressed("ui_cancel"):
        close_dialog()
        get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    if visible:
        get_tree().paused = _paused_before
