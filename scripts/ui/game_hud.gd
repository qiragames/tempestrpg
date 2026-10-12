extends CanvasLayer
@onready var session: Node = get_node("/root/GameSession")
## A functional prototype of the reference's hotbar, bag/details, and event log.

var _slots: Array[Button] = []
var _modal: Control
var _items: ItemList
var _details: Label
var _capacity: Label
var _discard: Button
var _close: Button
var _log: RichTextLabel
var _events: Array[String] = []
var _entries: Array = []
var _selection: StringName = &""
var _paused_before_open: bool = false
var _ally_dialog: Panel
@onready var player = get_parent().get_node("Player")
@onready var inventory = player.get_node("Inventory")

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_parent().system_message.connect(record_event)
    _build_hotbar()
    _build_inventory()
    inventory.changed.connect(_refresh_inventory)
    _refresh_inventory()
    record_event("Reincarnation confirmed.")
    _build_session_panel()
    _ally_dialog = load("res://scripts/ui/ally_dialog.gd").new()
    add_child(_ally_dialog)

func menu_open() -> bool:
    return _modal.visible or _session_panel.visible or (is_instance_valid(_ally_dialog) and _ally_dialog.visible)

func bind_player(actor: Node2D) -> void:
    if player == actor:
        return
    if is_instance_valid(inventory) and inventory.changed.is_connected(_refresh_inventory):
        inventory.changed.disconnect(_refresh_inventory)
    player = actor
    inventory = actor.get_node("Inventory")
    inventory.changed.connect(_refresh_inventory)
    _refresh_inventory()

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("19212e")
    style.border_color = Color("9a8053")
    style.set_border_width_all(1)
    style.set_corner_radius_all(3)
    return style

func _button(text: String, position: Vector2, size: Vector2, parent: Node) -> Button:
    var button := Button.new()
    button.text = text
    button.position = position
    button.size = size
    button.add_theme_font_size_override("font_size", 10)
    button.add_theme_stylebox_override("normal", _panel_style())
    parent.add_child(button)
    return button

func _label(text: String, position: Vector2, size: Vector2, parent: Node, font_size: int = 11) -> Label:
    var label := Label.new()
    label.text = text
    label.position = position
    label.size = size
    label.add_theme_font_size_override("font_size", font_size)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label

func _build_hotbar() -> void:
    for index in range(3):
        var button := _button("%d: Empty" % (index + 1), Vector2(172 + index * 99, 252), Vector2(95, 38), self)
        button.focus_mode = Control.FOCUS_NONE
        button.pressed.connect(_activate_slot.bind(index))
        _slots.append(button)
    _log = RichTextLabel.new()
    _log.position = Vector2(12, 230)
    _log.size = Vector2(150, 62)
    _log.add_theme_font_size_override("normal_font_size", 9)
    _log.scroll_following = true
    add_child(_log)

func _activate_slot(index: int) -> void:
    if get_tree().paused or player.input_blocked or (session.replica_world and not session.active):
        return
    var skill: Resource = player.get_node("SkillBook").skill_at_slot(index)
    if skill != null:
        if session.active:
            session.request_action("skill_%d" % (index + 1))
        else:
            player.get_node("MeleeAttack").attack_skill(player.facing, skill.id)

func _process(_delta: float) -> void:
    for index in range(_slots.size()):
        var skill: Resource = player.get_node("SkillBook").skill_at_slot(index)
        var button := _slots[index]
        if skill == null:
            button.text = "%d: Empty" % (index + 1)
            button.disabled = true
            continue
        var cooldown: float = player.get_node("MeleeAttack").cooldown_left
        button.text = "%d: %s\n%s" % [index + 1, skill.display_name, "%.1fs" % cooldown if cooldown > 0.0 else "%.0f Magicules" % skill.magicule_cost]
        button.tooltip_text = "%s · %s\n%d damage · %.1fs cooldown" % [skill.tier, skill.display_name, skill.damage, skill.cooldown]
        button.disabled = get_tree().paused or player.input_blocked or (session.replica_world and not session.active) or player.get_node("Health").current <= 0 or cooldown > 0.0 or player.get_node("Magicules").current < skill.magicule_cost

func record_event(message: String) -> void:
    _events.append(message)
    if _events.size() > 3:
        _events.pop_front()
    _log.text = "\n".join(_events)

func _build_inventory() -> void:
    _modal = Control.new()
    _modal.name = "InventoryPanel"
    _modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_modal)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.8)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _modal.add_child(backdrop)
    var frame := Panel.new()
    frame.position = Vector2(20, 38)
    frame.size = Vector2(440, 240)
    frame.add_theme_stylebox_override("panel", _panel_style())
    _modal.add_child(frame)
    _label("DIMENSIONAL STORAGE", Vector2(32, 46), Vector2(280, 20), _modal, 15)
    _capacity = _label("", Vector2(34, 72), Vector2(190, 16), _modal, 10)
    _label("MATERIAL DETAILS", Vector2(248, 74), Vector2(188, 16), _modal, 10)
    _items = ItemList.new()
    _items.position = Vector2(34, 94)
    _items.size = Vector2(198, 122)
    _items.add_theme_font_size_override("font_size", 12)
    _items.item_selected.connect(_select_item)
    _modal.add_child(_items)
    _details = _label("", Vector2(248, 96), Vector2(192, 115), _modal)
    _discard = _button("Discard 1", Vector2(248, 224), Vector2(118, 30), _modal)
    _discard.pressed.connect(func():
        if session.active:
            session.request_action("discard", {"id": String(_selection)})
        else:
            inventory.discard(_selection)
    )
    _close = _button("Close", Vector2(368, 44), Vector2(80, 26), _modal)
    _close.pressed.connect(close_inventory)
    _label("I / Esc: close · Multiplayer continues while browsing", Vector2(34, 256), Vector2(400, 16), _modal, 10)
    _modal.hide()

func _refresh_inventory() -> void:
    _entries = inventory.entries()
    _items.clear()
    _capacity.text = "BAG · %d / %d units" % [inventory.total_units(), inventory.capacity]
    var selected: int = 0
    for index in range(_entries.size()):
        _items.add_item("%s ×%d" % [_entries[index].name, _entries[index].count])
        if _entries[index].id == _selection:
            selected = index
    if _entries.is_empty():
        _selection = &""
        _details.text = "No materials stored.\n\nAbsorb and analyze a defeated creature to retain its essence."
        _discard.disabled = true
    else:
        _items.select(selected)
        _select_item(selected)

func _select_item(index: int) -> void:
    var entry: Dictionary = _entries[index]
    _selection = entry.id
    _details.text = "%s\n%s · ×%d\n\n%s" % [entry.name, entry.category, entry.count, entry.description]
    _discard.disabled = false

func open_inventory() -> void:
    if menu_open():
        return
    _paused_before_open = get_tree().paused
    if session.active:
        player.input_blocked = true
        session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    _modal.show()
    _close.grab_focus()

func close_inventory() -> void:
    if not _modal.visible:
        return
    _modal.hide()
    if session.active:
        player.input_blocked = false
        session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before_open

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F8:
            if _modal.visible or _ally_dialog.visible:
                return
            _session_panel.visible = not _session_panel.visible
            player.input_blocked = _session_panel.visible
            if session.active:
                session.request_action("menu", {"open": _session_panel.visible})
            get_viewport().set_input_as_handled()
            return
        if event.keycode == KEY_F9:
            var result: Error = session.save_world()
            get_parent()._announce("World saved." if result == OK else "Only the host can save; check the world path if saving failed.")
            get_viewport().set_input_as_handled()
            return
    if event.is_action_pressed("inventory") and not event.is_echo():
        if _modal.visible:
            close_inventory()
        else:
            open_inventory()
        get_viewport().set_input_as_handled()
    elif _modal.visible and event.is_action_pressed("ui_cancel"):
        close_inventory()
        get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    if is_instance_valid(_modal) and _modal.visible:
        get_tree().paused = _paused_before_open

var _session_panel: Panel

func _build_session_panel() -> void:
    _session_panel = Panel.new()
    _session_panel.position = Vector2(70, 90)
    _session_panel.size = Vector2(340, 150)
    _session_panel.add_theme_stylebox_override("panel", _panel_style())
    add_child(_session_panel)
    _label("HOST / JOIN · 8 PLAYERS TOTAL", Vector2(12, 10), Vector2(310, 22), _session_panel, 14)
    var address := LineEdit.new()
    address.text = "127.0.0.1"
    address.position = Vector2(12, 40)
    address.size = Vector2(310, 26)
    _session_panel.add_child(address)
    var host := _button("Host saved world", Vector2(12, 76), Vector2(150, 30), _session_panel)
    var join := _button("Join address", Vector2(172, 76), Vector2(150, 30), _session_panel)
    host.pressed.connect(func():
        if session.start_host() == OK:
            player.input_blocked = false
            _session_panel.hide()
    )
    join.pressed.connect(func():
        if session.join_host(address.text.strip_edges()) == OK:
            player.input_blocked = false
            _session_panel.hide()
    )
    _label("F8 closes · UDP 24560 · F9 host save", Vector2(12, 116), Vector2(310, 24), _session_panel, 10)
    _session_panel.hide()
