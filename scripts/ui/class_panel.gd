extends Control
## The class window (M12b): talking to the old master (F). Your class and subclass, the seven
## classes with their weapon, main attributes and skills; Choose / Change (with the price) for the
## main class and, from level 20, the subclass; resetting attribute points. Only ids go to the
## host (the "class" intent).
const UI := preload("res://scripts/ui/ui_style.gd")
const CLASSES := preload("res://scripts/progression/class_catalogue.gd")
const ATTRIBUTES := preload("res://scripts/progression/attributes.gd")
const FRAME := Rect2(40, 14, 560, 332)

var hud: CanvasLayer
var _list: VBoxContainer
var _summary: Label
var _reset: Button
var _paused_before := false
var _signature := ""

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "ClassPanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.8)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var frame := Panel.new()
    frame.position = FRAME.position
    frame.size = FRAME.size
    frame.add_theme_stylebox_override("panel", UI.ornate())
    add_child(frame)
    var face := TextureRect.new()
    face.texture = load("res://assets/game/sprites/npc_class_master/npc_class_master_face.png")
    face.position = FRAME.position + Vector2(14, 10)
    face.size = Vector2(30, 30)
    face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(face)
    UI.heading(hud._label("THE OLD MASTER", FRAME.position + Vector2(50, 10), Vector2(300, 20), self, 14))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    close.pressed.connect(close_panel)
    _summary = hud._label("", FRAME.position + Vector2(50, 30), Vector2(FRAME.size.x - 160, 26), self, 9)
    _summary.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _reset = hud._button("Reset attributes", FRAME.position + Vector2(FRAME.size.x - 150, 36), Vector2(136, 20), self)
    _reset.add_theme_font_size_override("font_size", 8)
    _reset.pressed.connect(func(): hud.session.request_action("class", {"operation": "reset", "slot": "", "id": ""}))
    var scroll := ScrollContainer.new()
    scroll.position = FRAME.position + Vector2(14, 62)
    scroll.size = Vector2(FRAME.size.x - 28, FRAME.size.y - 88)
    add_child(scroll)
    _list = VBoxContainer.new()
    _list.custom_minimum_size = Vector2(FRAME.size.x - 44, 0)
    _list.add_theme_constant_override("separation", 3)
    scroll.add_child(_list)
    hud._label("\"A weapon is only as good as the hand that knows it.\" Main class: its weapon and skills · subclass (level %d): its weapon · Esc: close" % CLASSES.SUB_LEVEL, FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func is_open() -> bool:
    return visible

func open() -> void:
    if hud.menu_open():
        return
    _paused_before = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    show()
    _signature = ""
    refresh()

func close_panel() -> void:
    if not visible:
        return
    hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before

func refresh() -> void:
    for child in _list.get_children():
        child.queue_free()
    var progression: Dictionary = hud.player.progression
    var mine := CLASSES.chosen(progression)
    var level: int = int(progression.get("level", 1))
    var price := CLASSES.change_price(progression)
    _summary.text = "Class: %s · subclass: %s · a change costs %d Zeni (you have %d)" % [CLASSES.CLASSES[mine.main][0] if not mine.main.is_empty() else "none yet", CLASSES.CLASSES[mine.sub][0] if not mine.sub.is_empty() else ("from level %d" % CLASSES.SUB_LEVEL if level < CLASSES.SUB_LEVEL else "none yet"), price, int(progression.get("zeni", 0))]
    _reset.disabled = ATTRIBUTES.total_points(progression) == ATTRIBUTES.unspent(progression)
    var skills: Node = hud.get_parent().get("class_skills")
    for id in CLASSES.ORDER:
        var info: Array = CLASSES.CLASSES[id]
        var row := HBoxContainer.new()
        row.custom_minimum_size = Vector2(FRAME.size.x - 44, 32)
        row.add_theme_constant_override("separation", 6)
        _list.add_child(row)
        var taught: String = skills.skill_text(id) if skills != null else ""
        var label: Label = hud._label("%s — %s weapons · %s / %s\n   %s%s" % [info[0], info[1], ATTRIBUTES.SHORT[info[2]], ATTRIBUTES.SHORT[info[3]], info[4], "  Skills: " + taught if not taught.is_empty() else ""], Vector2.ZERO, Vector2(10, 30), row, 8)
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.autowrap_mode = TextServer.AUTOWRAP_OFF
        label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        label.add_theme_color_override("font_color", UI.GOLD_LIGHT if id == mine.main else (UI.CYAN if id == mine.sub else UI.TEXT))
        var main_button: Button = hud._button("Class" if id != mine.main else "Your class", Vector2.ZERO, Vector2(70, 20), row)
        main_button.custom_minimum_size = Vector2(70, 20)
        main_button.add_theme_font_size_override("font_size", 8)
        main_button.disabled = id == mine.main or id == mine.sub
        main_button.pressed.connect(_choose.bind("main", id))
        var sub_button: Button = hud._button("Subclass" if id != mine.sub else "Your sub", Vector2.ZERO, Vector2(70, 20), row)
        sub_button.custom_minimum_size = Vector2(70, 20)
        sub_button.add_theme_font_size_override("font_size", 8)
        sub_button.disabled = id == mine.sub or id == mine.main or mine.main.is_empty() or level < CLASSES.SUB_LEVEL
        sub_button.pressed.connect(_choose.bind("sub", id))

func _choose(slot: String, id: String) -> void:
    hud.session.request_action("class", {"operation": "choose", "slot": slot, "id": id})

func _process(_delta: float) -> void:
    if not visible or not is_instance_valid(hud.player):
        return
    var signature := JSON.stringify([hud.player.progression.get("classes", {}), hud.player.progression.get("attributes", {}), hud.player.progression.get("zeni", 0)])
    if signature != _signature:
        _signature = signature
        refresh()

func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        close_panel()
        get_viewport().set_input_as_handled()
