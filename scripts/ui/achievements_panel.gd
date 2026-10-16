extends Control
## Achievements and titles on screen (M9e): the window (Y) with every achievement by category, its
## progress and its title, a button to wear a title (only the id goes to the host, the "title"
## intent), and a gold banner whenever one of your achievements unlocks.
const UI := preload("res://scripts/ui/ui_style.gd")
const ACH := preload("res://scripts/progression/achievements.gd")
const FRAME := Rect2(40, 10, 560, 338)
const BANNER_SECONDS := 4.0

var hud: CanvasLayer
var _list: VBoxContainer
var _summary: Label
var _tabs: HBoxContainer
var _category := "Combat"
var _paused_before := false
var banner: Label
var _banner_left := 0.0
var _seen: Dictionary = {}
var _seen_ready := false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "AchievementsPanel"
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
    UI.heading(hud._label("ACHIEVEMENTS", FRAME.position + Vector2(14, 10), Vector2(300, 20), self, 14))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    close.pressed.connect(close_panel)
    _summary = hud._label("", FRAME.position + Vector2(14, 34), Vector2(FRAME.size.x - 28, 14), self, 9)
    _summary.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _tabs = HBoxContainer.new()
    _tabs.position = FRAME.position + Vector2(14, 52)
    _tabs.add_theme_constant_override("separation", 4)
    add_child(_tabs)
    for category in ACH.CATEGORIES:
        var tab: Button = hud._button(category, Vector2.ZERO, Vector2(82, 20), _tabs)
        tab.custom_minimum_size = Vector2(82, 20)
        tab.add_theme_font_size_override("font_size", 9)
        tab.pressed.connect(func():
            _category = category
            refresh()
        )
    var scroll := ScrollContainer.new()
    scroll.position = FRAME.position + Vector2(14, 78)
    scroll.size = Vector2(FRAME.size.x - 28, FRAME.size.y - 104)
    add_child(scroll)
    _list = VBoxContainer.new()
    _list.custom_minimum_size = Vector2(FRAME.size.x - 44, 0)
    _list.add_theme_constant_override("separation", 3)
    scroll.add_child(_list)
    hud._label("Unlocked titles can be worn: they show on your status card and above your head · Y / Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()
    banner = Label.new()
    banner.name = "AchievementBanner"
    banner.position = Vector2(170, 64)
    banner.size = Vector2(300, 30)
    banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    banner.add_theme_font_size_override("font_size", 11)
    banner.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    banner.add_theme_stylebox_override("normal", UI.ornate())
    banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.hide()
    hud.add_child.call_deferred(banner)

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
    var me: Node = hud.player
    var total: int = ACH.ACHIEVEMENTS.size()
    var done: int = ACH.ACHIEVEMENTS.keys().filter(func(id): return ACH.has(me, id)).size()
    var worn := ACH.worn_title(me)
    _summary.text = "%d of %d unlocked · title: %s" % [done, total, worn if not worn.is_empty() else "none"]
    for tab in _tabs.get_children():
        tab.modulate = Color.WHITE if tab.text == _category else Color(0.7, 0.7, 0.7)
    for id in ACH.ACHIEVEMENTS:
        var spec: Array = ACH.ACHIEVEMENTS[id]
        if spec[2] != _category:
            continue
        var got := ACH.has(me, id)
        var state := ACH.progress(me, id)
        var row := HBoxContainer.new()
        row.custom_minimum_size = Vector2(FRAME.size.x - 44, 30)
        _list.add_child(row)
        var text := "%s %s\n   %s%s" % ["★" if got else "☆", spec[0], spec[1], "" if got or int(state[1]) <= 1 else " (%d/%d)" % [mini(int(state[0]), int(state[1])), int(state[1])]]
        var label: Label = hud._label(text, Vector2.ZERO, Vector2(10, 28), row, 9)
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.add_theme_color_override("font_color", UI.GOLD_LIGHT if got else UI.TEXT_DIM)
        if not String(spec[3]).is_empty():
            var wearing: bool = String(me.progression.get("title", "")) == id
            var button: Button = hud._button(("Worn: " if wearing else "Title: ") + spec[3], Vector2.ZERO, Vector2(150, 20), row)
            button.custom_minimum_size = Vector2(150, 20)
            button.add_theme_font_size_override("font_size", 8)
            button.disabled = not got
            button.pressed.connect(func():
                hud.session.request_action("title", {"id": "" if wearing else id})
                await get_tree().process_frame
                refresh()
            )

## A gold banner for each achievement that unlocks (not for those a loaded save already had).
func _process(delta: float) -> void:
    if not is_instance_valid(hud.player):
        return
    for id in ACH.unlocked(hud.player):
        if _seen.has(id):
            continue
        _seen[id] = true
        if _seen_ready:
            banner.text = "Achievement unlocked: %s%s" % [ACH.ACHIEVEMENTS[id][0] if ACH.ACHIEVEMENTS.has(id) else id, "  ·  title: %s" % ACH.title_of(id) if not ACH.title_of(id).is_empty() else ""]
            _banner_left = BANNER_SECONDS
    _seen_ready = true
    _banner_left -= delta
    banner.visible = _banner_left > 0.0 and not hud.menu_open()

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if event.is_action_pressed("ui_cancel") or (event.is_action_pressed("achievements") and not event.is_echo()):
        close_panel()
        get_viewport().set_input_as_handled()
