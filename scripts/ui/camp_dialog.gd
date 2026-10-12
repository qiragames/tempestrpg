extends Panel
var _stock: Label
var _hint: Label
var _found: Button
var _gather: Button
var _work_status: Label
var _work_buttons: Dictionary = {}
var _build: Button
var _paused_before: bool = false
@onready var hud = get_parent()
@onready var session: Node = get_node("/root/GameSession")

func _ready() -> void:
    position = Vector2(50, 24)
    size = Vector2(380, 286)
    add_theme_stylebox_override("panel", hud._panel_style())
    hud._label("THE FIRST GOBLIN CAMP", Vector2(12, 10), Vector2(356, 24), self, 15)
    _stock = hud._label("", Vector2(12, 40), Vector2(356, 22), self, 12)
    _hint = hud._label("", Vector2(12, 68), Vector2(356, 78), self, 11)
    _found = hud._button("Found camp", Vector2(12, 148), Vector2(170, 28), self)
    _found.pressed.connect(func(): _request("found", "camp_1"))
    _gather = hud._button("Gather nearby materials", Vector2(194, 148), Vector2(174, 28), self)
    _gather.pressed.connect(func():
        var id: String = hud.get_parent().camp.nearest_deposit(hud.player)
        if not id.is_empty():
            _request("gather", id)
    )
    _build = hud._button("Build hut: 12 wood + 6 stone", Vector2(12, 187), Vector2(242, 28), self)
    _build.pressed.connect(func(): _request("build", "hut_1"))
    var close: Button = hud._button("Close", Vector2(266, 187), Vector2(102, 28), self)
    close.pressed.connect(close_dialog)
    for index in range(3):
        var role: String = ["gather", "build", "follow"][index]
        var button: Button = hud._button(["Ally: Gather", "Ally: Build", "Ally: Follow"][index], Vector2(12 + index * 120, 225), Vector2(114, 26), self)
        button.pressed.connect(_assign.bind(role))
        _work_buttons[role] = button
    _work_status = hud._label("", Vector2(12, 258), Vector2(356, 20), self, 10)
    hide()

func _owned_ally() -> Node2D:
    for ally in get_tree().get_nodes_in_group("allies"):
        if ally.owner_id == hud.player.character_id and not ally.display_name.is_empty():
            return ally
    return null

func _assign(role: String) -> void:
    var ally := _owned_ally()
    if ally != null:
        session.request_action("ally_work", {"id": ally.entity_id, "role": role})
        _refresh()

func _request(operation: String, id: String) -> void:
    session.request_action("camp", {"operation": operation, "id": id})
    _refresh()

func open_dialog() -> void:
    if hud.menu_open():
        return
    _paused_before = get_tree().paused
    if session.active:
        hud.player.input_blocked = true
        session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    show()
    _refresh()

func close_dialog() -> void:
    if not visible:
        return
    hide()
    if session.active:
        hud.player.input_blocked = false
        session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before

func _process(_delta: float) -> void:
    if visible:
        _refresh()

func _refresh() -> void:
    var camp = hud.get_parent().camp
    if camp == null:
        return
    _stock.text = "Shared stock: %d wood · %d stone" % [camp.state.wood, camp.state.stone]
    _hint.text = "Camp site: (350, 350), west of spawn.\nFound it with your named ally nearby (after recovery).\nWood: (300, 350), (350, 300). Stone: (410, 350).\nGather within 36px; found/build within 55px of camp.\nKeep the southeast hut footprint clear of characters."
    if camp.state.hut:
        _hint.text = "Goblin hut complete! Shared camp progress is saved in hosted play.\nAssign your ally to work or return to following."
    _found.text = "Camp established" if camp.state.founded else "Found camp (free)"
    _found.disabled = not camp.can_found(hud.player)
    _gather.disabled = camp.nearest_deposit(hud.player).is_empty()
    _build.text = "Hut complete" if camp.state.hut else "Build hut: 12 wood + 6 stone"
    _build.disabled = not camp.can_build(hud.player)
    var ally := _owned_ally()
    _work_status.text = "Name an ally to assign work." if ally == null else "%s · %s %s · %.1fs work left" % [ally.display_name, ally.work_role, ally.work_target, ally.work_left]
    for role in _work_buttons:
        _work_buttons[role].disabled = ally == null or not ally.can_assign_work(hud.player, role)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("camp") and not event.is_echo():
        if visible:
            close_dialog()
        else:
            open_dialog()
        get_viewport().set_input_as_handled()
    elif visible and event.is_action_pressed("ui_cancel"):
        close_dialog()
        get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    if visible:
        get_tree().paused = _paused_before
