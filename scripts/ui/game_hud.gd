extends CanvasLayer
@onready var session: Node = get_node("/root/GameSession")
## A functional prototype of the reference's hotbar, bag/details, and event log.

var _slots: Array[Button] = []
## Skill tree window (K), see skill_tree_panel.gd.
var skill_tree: Control
## Skill fusion window (U), see fusion_panel.gd.
var fusion: Control
## Equipment window (from the bag), see gear_panel.gd.
var gear_panel: Control
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
var _recovery: Label
## Level and experience readout, top right of the title bar.
var _level: Label
var _trial_back: ColorRect
var _trial_label: Label
var _camp_dialog: Panel
var _ally_dialog: Panel
@onready var player = get_parent().get_node("Player")
@onready var inventory = player.get_node("Inventory")

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_parent().system_message.connect(record_event)
    # Translucent panels keep the stat block and analysis text readable over any terrain.
    _backdrop(Rect2(6, 42, 206, 88))
    _backdrop(Rect2(446, 42, 188, 80))
    _recovery = _label("", Vector2(12, 110), Vector2(300, 30), self, 11)
    _level = _label("", Vector2(380, 4), Vector2(248, 16), self, 11)
    _level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _level.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
    _trial_back = ColorRect.new()
    _trial_back.position = Vector2(220, 44)
    _trial_back.size = Vector2(220, 22)
    _trial_back.color = Color(0.25, 0.18, 0.05, 0.75)
    _trial_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_trial_back)
    _trial_label = _label("", Vector2(226, 47), Vector2(210, 18), self, 10)
    _build_hotbar()
    _build_inventory()
    inventory.changed.connect(_refresh_inventory)
    _refresh_inventory()
    record_event("Reincarnation confirmed.")
    _build_pause_panel()
    skill_tree = load("res://scripts/ui/skill_tree_panel.gd").new(self)
    add_child(skill_tree)
    fusion = load("res://scripts/ui/fusion_panel.gd").new(self)
    add_child(fusion)
    gear_panel = load("res://scripts/ui/gear_panel.gd").new(self)
    add_child(gear_panel)
    get_parent().system_message.connect(fusion.show_message)
    _ally_dialog = load("res://scripts/ui/ally_dialog.gd").new()
    add_child(_ally_dialog)
    _camp_dialog = load("res://scripts/ui/camp_dialog.gd").new()
    add_child(_camp_dialog)

func menu_open() -> bool:
    return (is_instance_valid(_camp_dialog) and _camp_dialog.visible) or _modal.visible or _pause_panel.visible or (is_instance_valid(_ally_dialog) and _ally_dialog.visible) or (is_instance_valid(skill_tree) and skill_tree.visible) or (is_instance_valid(fusion) and fusion.visible) or (is_instance_valid(gear_panel) and gear_panel.visible)

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

## Drawn behind the scene's HUD labels (just after the top bar).
func _backdrop(rect: Rect2) -> void:
    var back := ColorRect.new()
    back.position = rect.position
    back.size = rect.size
    back.color = Color(0.04, 0.09, 0.12, 0.55)
    back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(back)
    move_child(back, 1)

func _button(text: String, position: Vector2, size: Vector2, parent: Node) -> Button:
    var button := Button.new()
    button.text = text
    button.position = position
    button.size = size
    button.add_theme_font_size_override("font_size", 10)
    button.add_theme_stylebox_override("normal", _panel_style())
    parent.add_child(button)
    return button

static func level_text(progression: Dictionary) -> String:
    var leveling := preload("res://scripts/progression/leveling.gd")
    var level: int = int(progression.get("level", 1))
    var points: int = int(progression.get("skill_points", 0))
    var xp := "XP max" if level >= leveling.LEVEL_CAP else "XP %d / %d" % [int(progression.get("experience", 0)), leveling.xp_for_level(level + 1)]
    return "Lv %d · %s%s" % [level, xp, " · %d skill point%s" % [points, "" if points == 1 else "s"] if points > 0 else ""]

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
    for index in range(4):
        var button := _button("%d: Empty" % (index + 1), Vector2(176 + index * 86, 294), Vector2(82, 38), self)
        button.add_theme_font_size_override("font_size", 9)
        button.focus_mode = Control.FOCUS_NONE
        button.pressed.connect(_activate_slot.bind(index))
        _slots.append(button)
    _backdrop(Rect2(6, 246, 162, 90))
    _log = RichTextLabel.new()
    _log.position = Vector2(12, 250)
    _log.size = Vector2(154, 84)
    _log.add_theme_font_size_override("normal_font_size", 9)
    # Newest lines stay visible; no scrollbar over the play area.
    _log.scroll_following = true
    _log.scroll_active = false
    _log.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
    if _pause_panel.visible:
        # A friend joined while this host was paused alone: resume the shared world, keep this player stopped.
        if not _pause_blocking and get_tree().paused and session.active and session.owners.size() > 1:
            get_tree().paused = _paused_before_pause
            _pause_blocking = true
            player.input_blocked = true
        _refresh_pause()
    _recovery.visible = player.is_exhausted()
    _level.text = level_text(player.progression)
    var trial: Dictionary = get_parent().trial.state if get_parent().get("trial") != null else {}
    _trial_back.visible = trial.get("active", false)
    _trial_label.visible = _trial_back.visible
    if _trial_back.visible:
        _trial_label.text = "%s · %d left · %.0fs%s" % [get_parent().trial.DISPLAY_NAME, trial.remaining, trial.time_left, "" if trial.owner == player.character_id else " (another player)"]
    var shape: Dictionary = player.FORMS.FORMS[player.form]
    if player.race_stats().mimic:
        $StrikeCost.text = "Strike: 8 Magicules · Form: %s%s" % [shape.name, " (%.1fs)" % player.form_cooldown if player.form_cooldown > 0.0 else " · T: mimic"]
    else:
        $StrikeCost.text = "Strike: 8 Magicules · %s: %s" % [player.race(), player.race_stats().ability.get_slice(":", 0).to_lower()]
    _recovery.text = "Recovering: %.1fs · need %.0f Magicules" % [player.exhaustion_left, player.get_node("Magicules").maximum * 0.25]
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
        button.disabled = player.is_exhausted() or get_tree().paused or player.input_blocked or (session.replica_world and not session.active) or player.get_node("Health").current <= 0 or cooldown > 0.0 or player.get_node("Magicules").current < skill.magicule_cost

func record_event(message: String) -> void:
    _events.append(message)
    if _events.size() > 3:
        _events.pop_front()
    _log.text = "\n".join(_events)

func _build_inventory() -> void:
    # Centered 440x240 frame; children are placed relative to its top-left corner.
    var o := Vector2(100, 60)
    _modal = Control.new()
    _modal.name = "InventoryPanel"
    _modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_modal)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.8)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _modal.add_child(backdrop)
    var frame := Panel.new()
    frame.position = o
    frame.size = Vector2(440, 240)
    frame.add_theme_stylebox_override("panel", _panel_style())
    _modal.add_child(frame)
    _label("DIMENSIONAL STORAGE", o + Vector2(12, 8), Vector2(280, 20), _modal, 15)
    _capacity = _label("", o + Vector2(14, 34), Vector2(190, 16), _modal, 10)
    _label("MATERIAL DETAILS", o + Vector2(228, 36), Vector2(188, 16), _modal, 10)
    _items = ItemList.new()
    _items.position = o + Vector2(14, 56)
    _items.size = Vector2(198, 122)
    _items.add_theme_font_size_override("font_size", 12)
    _items.item_selected.connect(_select_item)
    _modal.add_child(_items)
    _details = _label("", o + Vector2(228, 58), Vector2(192, 115), _modal)
    _discard = _button("Discard 1", o + Vector2(228, 186), Vector2(118, 30), _modal)
    _discard.pressed.connect(func():
        if session.active:
            session.request_action("discard", {"id": String(_selection)})
        else:
            inventory.discard(_selection)
    )
    _close = _button("Close", o + Vector2(348, 6), Vector2(80, 26), _modal)
    _close.pressed.connect(close_inventory)
    var equipment_button := _button("Equipment", o + Vector2(258, 6), Vector2(84, 26), _modal)
    equipment_button.pressed.connect(func():
        close_inventory()
        gear_panel.open()
    )
    _label("I / Esc: close · Multiplayer continues while browsing", o + Vector2(14, 218), Vector2(400, 16), _modal, 10)
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
        if event.keycode == KEY_F9:
            var result: Error = session.save_world()
            get_parent()._announce("World saved." if result == OK else "Only the host can save; check the world path if saving failed.")
            get_viewport().set_input_as_handled()
            return
    if event.is_action_pressed("skill_tree") and not event.is_echo() and not _modal.visible and not fusion.visible:
        if skill_tree.visible:
            skill_tree.close()
        else:
            skill_tree.open()
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("fusion") and not event.is_echo() and not _modal.visible and not skill_tree.visible:
        if fusion.visible:
            fusion.close()
        else:
            fusion.open()
        get_viewport().set_input_as_handled()
        return
    if gear_panel.visible and (event.is_action_pressed("ui_cancel") or (event.is_action_pressed("inventory") and not event.is_echo())):
        gear_panel.close()
        get_viewport().set_input_as_handled()
        return
    if fusion.visible and event.is_action_pressed("ui_cancel"):
        fusion.close()
        get_viewport().set_input_as_handled()
        return
    if skill_tree.visible and event.is_action_pressed("ui_cancel"):
        skill_tree.close()
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
    elif event.is_action_pressed("ui_cancel") and not event.is_echo():
        # Esc with no other menu open toggles the pause menu (dialogs consume Esc first).
        if _pause_panel.visible:
            close_pause()
        elif not menu_open():
            open_pause()
        get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    if is_instance_valid(_modal) and _modal.visible:
        get_tree().paused = _paused_before_open
    if is_instance_valid(skill_tree) and skill_tree.visible:
        get_tree().paused = skill_tree._paused_before_open
    if is_instance_valid(fusion) and fusion.visible:
        get_tree().paused = fusion._paused_before_open
    if is_instance_valid(gear_panel) and gear_panel.visible:
        get_tree().paused = gear_panel._paused_before_open

var _pause_panel: Panel
var _pause_status: Label
var _pause_buttons: Dictionary = {}
var _pause_blocking: bool = false
var _paused_before_pause: bool = false

## Pause menu: resume, open the hosted world to friends, save, and leave to the title menu.
func _build_pause_panel() -> void:
    _pause_panel = Panel.new()
    _pause_panel.position = Vector2(190, 56)
    _pause_panel.size = Vector2(260, 244)
    _pause_panel.add_theme_stylebox_override("panel", _panel_style())
    add_child(_pause_panel)
    _label("PAUSED", Vector2(14, 10), Vector2(232, 22), _pause_panel, 15)
    _pause_status = _label("", Vector2(14, 34), Vector2(232, 62), _pause_panel, 10)
    var entries := [["resume", "Resume"], ["open", "Open to friends"], ["save", "Save world"], ["quit", "Save & quit to title"]]
    for index in range(entries.size()):
        var button := _button(entries[index][1], Vector2(14, 104 + index * 32), Vector2(232, 26), _pause_panel)
        _pause_buttons[entries[index][0]] = button
    _pause_buttons.resume.pressed.connect(close_pause)
    _pause_buttons.open.pressed.connect(func(): session.open_to_friends(); _refresh_pause())
    _pause_buttons.save.pressed.connect(func():
        var result: Error = session.save_world()
        get_parent()._announce("World saved." if result == OK else "Saving failed; the previous save is retained.")
    )
    _pause_buttons.quit.pressed.connect(func():
        session.quit_to_title()
    )
    _pause_panel.hide()

func open_pause() -> void:
    if menu_open():
        return
    _paused_before_pause = get_tree().paused
    # Alone (or offline) the world freezes; with guests connected only this character stops.
    _pause_blocking = session.active and (session.replica_world or session.owners.size() > 1)
    if _pause_blocking:
        player.input_blocked = true
        session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    _pause_panel.show()
    _refresh_pause()
    _pause_buttons.resume.grab_focus()

func close_pause() -> void:
    if not _pause_panel.visible:
        return
    _pause_panel.hide()
    if _pause_blocking:
        player.input_blocked = false
        session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before_pause if not _pause_blocking else get_tree().paused

func _refresh_pause() -> void:
    var hosting: bool = session.active and not session.replica_world
    if session.replica_world:
        _pause_status.text = "Joined a friend's world. Leaving keeps your character on their save."
    elif not session.active:
        _pause_status.text = "Offline sandbox (not saved)."
    elif session.listening:
        var addresses: Array = session.lan_addresses()
        _pause_status.text = "\"%s\" · open to friends on UDP %d · %d/8 players\nJoin with: %s" % [session.world_meta.get("name", "World"), session.listen_port, session.owners.size(), ", ".join(addresses) if not addresses.is_empty() else "your IP address"]
    else:
        _pause_status.text = "\"%s\" · %s · playing solo\nOpen to friends lets up to 7 friends join." % [session.world_meta.get("name", "World"), load("res://scripts/world/world_layout.gd").describe(session.world_meta)]
    _pause_buttons.open.disabled = not hosting or session.listening
    _pause_buttons.open.text = "Open to friends" if not session.listening else "Open to friends (on)"
    _pause_buttons.save.disabled = not hosting
    _pause_buttons.quit.text = "Leave to title" if session.replica_world else "Save & quit to title" if hosting else "Quit to title"
