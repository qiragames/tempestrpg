extends Panel
var _stock: Label
var _hint: Label
var _found: Button
var _gather: Button
var _offer: Button
var _work_status: Label
var _work_buttons: Dictionary = {}
var _build_buttons: Dictionary = {}
var _craft_buttons: Dictionary = {}
var _paused_before: bool = false
@onready var hud = get_parent()
@onready var session: Node = get_node("/root/GameSession")

func _ready() -> void:
    position = Vector2(116, 18)
    size = Vector2(408, 324)
    add_theme_stylebox_override("panel", hud._panel_style())
    hud.UI.heading(hud._label("THE FIRST GOBLIN CAMP", Vector2(12, 8), Vector2(384, 22), self, 15))
    _stock = hud._label("", Vector2(12, 32), Vector2(384, 18), self, 11)
    _hint = hud._label("", Vector2(12, 54), Vector2(384, 72), self, 10)
    _found = hud._button("Found camp", Vector2(12, 132), Vector2(124, 26), self)
    _found.pressed.connect(func(): _request("found", "camp_1"))
    _gather = hud._button("Gather nearby", Vector2(142, 132), Vector2(124, 26), self)
    _gather.pressed.connect(func():
        var id: String = hud.get_parent().camp.nearest_deposit(hud.player)
        if not id.is_empty():
            _request("gather", id)
    )
    _offer = hud._button("Offer essence", Vector2(272, 132), Vector2(124, 26), self)
    _offer.pressed.connect(func(): _request("offer", "gnasher_essence"))
    var camp_script = load("res://scripts/settlement/first_camp.gd")
    var index := 0
    for id in camp_script.STRUCTURES:
        var button: Button = hud._button("", Vector2(12 + index * 98, 164), Vector2(94, 34), self)
        button.add_theme_font_size_override("font_size", 9)
        button.pressed.connect(_request.bind("build", id))
        _build_buttons[id] = button
        index += 1
    for role_index in range(3):
        var role: String = ["gather", "build", "follow"][role_index]
        var button: Button = hud._button(["Ally: Gather", "Ally: Build", "Ally: Follow"][role_index], Vector2(12 + role_index * 130, 204), Vector2(124, 26), self)
        button.pressed.connect(_assign.bind(role))
        _work_buttons[role] = button
    _work_status = hud._label("", Vector2(12, 236), Vector2(384, 36), self, 10)
    var sources = load("res://scripts/items/gear_sources.gd")
    var recipe_index := 0
    for recipe in sources.RECIPES:
        var craft: Button = hud._button("Forge " + sources.RECIPES[recipe].name.to_lower(), Vector2(12 + recipe_index * 92, 286), Vector2(88, 26), self)
        craft.add_theme_font_size_override("font_size", 9)
        craft.pressed.connect(_request.bind("craft", recipe))
        craft.tooltip_text = sources.recipe_text(recipe)
        _craft_buttons[recipe] = craft
        recipe_index += 1
    var close: Button = hud._button("Close", Vector2(294, 286), Vector2(102, 26), self)
    close.pressed.connect(close_dialog)
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
    _stock.text = "Camp level %d · Shared stock: %d wood · %d stone · %d essence" % [camp.level(), camp.state.wood, camp.state.stone, camp.state.essence]
    if not camp.state.founded:
        _hint.text = "Camp site (350, 350), west of spawn. Found it with your named ally nearby.\nNear wood (300, 350), (350, 300); stone (410, 350). Gather within 36px.\nFound, build and offer within 55px of the flag."
    elif not camp.state.hut:
        _hint.text = "Build the Goblin Hut first; it unlocks the Storehouse and Shrine.\nKeep building footprints clear of characters."
    else:
        _hint.text = "Explore for more: wood far east (700, 440), stone northeast (860, 200)\nand southwest (200, 540). Absorbed Gnasher Essence can be offered.\nStorehouse halves ally work time; the Shrine doubles nearby regen."
    _found.text = "Camp established" if camp.state.founded else "Found camp (free)"
    _found.disabled = not camp.can_found(hud.player)
    _gather.disabled = camp.nearest_deposit(hud.player).is_empty()
    _offer.disabled = not camp.can_offer(hud.player)
    for id in _build_buttons:
        var info: Dictionary = camp.STRUCTURES[id]
        _build_buttons[id].text = "%s\nbuilt" % info.name if camp.built(id) else "%s\n%s" % [info.name, camp.cost_text(id)]
        _build_buttons[id].disabled = not camp.can_build(hud.player, id)
    var ally := _owned_ally()
    if ally == null:
        _work_status.text = "Name an ally to assign work."
    else:
        var target: String = camp.STRUCTURES[ally.work_target].name if camp.STRUCTURES.has(ally.work_target) else ally.work_target
        _work_status.text = "%s · %s %s · %.1fs work left%s" % [ally.display_name, ally.work_role, target, ally.work_left, "\nStorehouse: work takes half the time." if camp.state.storehouse else ""]
    var near_forge: bool = camp.state.get("forge", false) and hud.player.global_position.distance_to(camp.STRUCTURES.forge_1.site) <= camp.FORGE_REACH
    for recipe in _craft_buttons:
        _craft_buttons[recipe].disabled = not near_forge
    if camp.state.get("forge", false):
        _hint.text += "\nForge (south of the flag): armor = 2 Gnasher Essence, weapon = 2 Thornback Quill,\naccessory = 1 of each. Stand within 50px."
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
