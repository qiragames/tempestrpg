extends Control
## Skill tree (K), after the user's feedback: a real tree — small nodes connected by lines, top to
## bottom (a node sits one level below everything it needs), gold along the bought path, skills
## as larger diamonds. Hover a node for what it gives; click to buy. Learned skills (analysed,
## trials, scrolls, mentors) are listed on the right with Activate (scrolls when many).
const TREE := preload("res://scripts/skills/skill_tree.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const ORIGIN := Vector2(30, 20)
const FRAME := Vector2(580, 320)
const TREE_AREA := Rect2(14, 40, 330, 236)
const NODE := 30.0
const SKILL_NODE := 36.0

var hud: CanvasLayer
var _title: Label
var _detail: Label
var _close: Button
var _node_buttons: Dictionary = {}
var _node_labels: Dictionary = {}
var _activate_buttons: Array = []
var _skill_labels: Array = []
var _list: VBoxContainer
var _lines: Control
var _race: String = ""
var _learned_for: Array = []
var _paused_before_open: bool = false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "SkillTreePanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.85)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var frame := Panel.new()
    frame.position = ORIGIN
    frame.size = FRAME
    frame.add_theme_stylebox_override("panel", UI.ornate())
    add_child(frame)
    _title = hud._label("", ORIGIN + Vector2(14, 10), Vector2(440, 20), self, 12)
    _title.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _close = hud._button("Close", ORIGIN + Vector2(FRAME.x - 92, 8), Vector2(80, 24), self)
    _close.pressed.connect(close)
    var tree_box := Panel.new()
    tree_box.position = ORIGIN + TREE_AREA.position
    tree_box.size = TREE_AREA.size
    tree_box.add_theme_stylebox_override("panel", UI.hud_box())
    tree_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(tree_box)
    _lines = Control.new()
    _lines.position = ORIGIN + TREE_AREA.position
    _lines.size = TREE_AREA.size
    _lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _lines.draw.connect(_draw_lines)
    add_child(_lines)
    UI.heading(hud._label("LEARNED SKILLS", ORIGIN + Vector2(356, 40), Vector2(210, 14), self, 9))
    var scroll := ScrollContainer.new()
    scroll.position = ORIGIN + Vector2(356, 56)
    scroll.size = Vector2(210, 220)
    add_child(scroll)
    _list = VBoxContainer.new()
    _list.custom_minimum_size = Vector2(196, 0)
    scroll.add_child(_list)
    _detail = hud._label("", ORIGIN + Vector2(14, 280), Vector2(552, 22), self, 8)
    hud._label("K / Esc: close · every level gives 1 skill point · click a node to buy it", ORIGIN + Vector2(14, FRAME.y - 18), Vector2(500, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

## Depth of a node: one below everything it requires.
static func depth(id: String) -> int:
    var needs: Array = TREE.NODES[id].requires
    var deepest := -1
    for need in needs:
        deepest = maxi(deepest, depth(need))
    return deepest + 1

## Where each node sits inside the tree area (levels top to bottom, spread left to right).
func layout(race: String) -> Dictionary:
    var levels := {}
    for id in TREE.nodes_for(race):
        var level: int = depth(id)
        if not levels.has(level):
            levels[level] = []
        levels[level].append(id)
    var places := {}
    var count: int = levels.size()
    for level in levels:
        var row: Array = levels[level]
        for index in range(row.size()):
            var x: float = TREE_AREA.size.x * (index + 1) / float(row.size() + 1)
            var y: float = 22.0 + (TREE_AREA.size.y - 52.0) * level / float(maxi(1, count - 1))
            places[row[index]] = Vector2(x, y)
    return places

## Node buttons are rebuilt when the character's race changes (each race has its own tree).
func _build_nodes(race: String) -> void:
    for button in _node_buttons.values():
        button.queue_free()
    for label in _node_labels.values():
        label.queue_free()
    _node_buttons.clear()
    _node_labels.clear()
    _race = race
    var places := layout(race)
    for id in places:
        var node: Dictionary = TREE.NODES[id]
        var size := SKILL_NODE if node.has("skill") else NODE
        var at: Vector2 = ORIGIN + TREE_AREA.position + places[id] - Vector2(size, size) / 2.0
        var button: Button = hud._button("", at, Vector2(size, size), self)
        button.add_theme_font_size_override("font_size", 11)
        button.pressed.connect(_buy.bind(id))
        button.mouse_entered.connect(func(): _detail.text = "%s — %s" % [node.name, TREE.describe_node(id)])
        _node_buttons[id] = button
        var label: Label = hud._label(node.name, at + Vector2(size / 2.0 - 40, size + 1), Vector2(80, 10), self, 7)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.autowrap_mode = TextServer.AUTOWRAP_OFF
        label.clip_text = true
        _node_labels[id] = label

func _draw_lines() -> void:
    if _race.is_empty():
        return
    var places := layout(_race)
    var owned: Array = hud.player.progression.tree.nodes
    for id in places:
        for need in TREE.NODES[id].requires:
            if not places.has(need):
                continue
            var lit: bool = need in owned
            var colour: Color = UI.GOLD if lit and id in owned else (Color(UI.GOLD, 0.6) if lit else Color(0.35, 0.36, 0.42))
            _lines.draw_line(places[need], places[id], Color(0, 0, 0, 0.5), 4.0)
            _lines.draw_line(places[need], places[id], colour, 2.0)

func _style(button: Button, kind: String, skill: bool) -> void:
    var style := StyleBoxFlat.new()
    style.set_corner_radius_all(int((SKILL_NODE if skill else NODE) / 2.0) if not skill else 4)
    style.set_border_width_all(2)
    match kind:
        "owned":
            style.bg_color = Color(0.36, 0.28, 0.1)
            style.border_color = UI.GOLD_LIGHT
        "ready":
            style.bg_color = Color(0.1, 0.14, 0.2)
            style.border_color = UI.CYAN
        _:
            style.bg_color = Color(0.07, 0.08, 0.1)
            style.border_color = Color(0.3, 0.3, 0.34)
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        button.add_theme_stylebox_override(state, style)
    # Skill nodes are diamonds.
    button.rotation = PI / 4.0 if skill else 0.0
    button.pivot_offset = button.size / 2.0

func _buy(id: String) -> void:
    var player = hud.player
    if hud.session.active:
        hud.session.request_action("tree", {"operation": "buy", "id": id})
    else:
        player.buy_node(id)

func _activate(index: int) -> void:
    var learned: Array = hud.player.get_node("SkillBook").evidence_ids()
    if index >= learned.size():
        return
    if hud.session.active:
        hud.session.request_action("tree", {"operation": "activate", "id": learned[index]})
    else:
        hud.player.activate_skill(learned[index])

## The learned-skills list (rebuilt when skills are learned).
func _build_list(learned: Array) -> void:
    for child in _list.get_children():
        _list.remove_child(child)
        child.queue_free()
    _activate_buttons.clear()
    _skill_labels.clear()
    _learned_for = learned.duplicate()
    if learned.is_empty():
        var hint: Label = hud._label("Absorb creatures, read scrolls or find mentors to learn skills.", Vector2.ZERO, Vector2(196, 30), _list, 8)
        hint.custom_minimum_size = Vector2(196, 30)
        _skill_labels.append(hint)
        return
    for index in range(learned.size()):
        var label: Label = hud._label("", Vector2.ZERO, Vector2(196, 12), _list, 8)
        label.custom_minimum_size = Vector2(196, 12)
        _skill_labels.append(label)
        var button: Button = hud._button("", Vector2.ZERO, Vector2(196, 18), _list)
        button.custom_minimum_size = Vector2(196, 18)
        button.add_theme_font_size_override("font_size", 8)
        button.pressed.connect(_activate.bind(index))
        _activate_buttons.append(button)

func refresh() -> void:
    var player = hud.player
    var progression: Dictionary = player.progression
    if progression.race != _race:
        _build_nodes(progression.race)
    var points: int = int(progression.skill_points)
    _title.text = "SKILL TREE · %s · Lv %d · %d skill point%s" % [progression.race, progression.level, points, "" if points == 1 else "s"]
    for id in _node_buttons:
        var node: Dictionary = TREE.NODES[id]
        var owned: bool = id in progression.tree.nodes
        var problem: String = TREE.buy_problem(progression, id)
        var skill: bool = node.has("skill")
        _node_buttons[id].text = "✓" if owned else ("★" if skill else "+")
        _node_buttons[id].disabled = not owned and not problem.is_empty()
        _style(_node_buttons[id], "owned" if owned else ("ready" if problem.is_empty() else "locked"), skill)
        _node_labels[id].add_theme_color_override("font_color", UI.GOLD_LIGHT if owned else (UI.TEXT if problem.is_empty() else UI.TEXT_DIM))
    _lines.queue_redraw()
    var book = player.get_node("SkillBook")
    var learned: Array = book.evidence_ids()
    if learned != _learned_for:
        _build_list(learned)
    for index in range(_activate_buttons.size()):
        var skill: Resource = book.get_skill(StringName(learned[index]))
        var active: bool = learned[index] in progression.tree.active
        _skill_labels[index].text = "%s (%s)" % [skill.display_name if skill != null else learned[index], skill.tier if skill != null else "?"]
        _activate_buttons[index].text = "Active ✓" if active else "Activate · 1 point"
        _activate_buttons[index].disabled = active or points < TREE.ACTIVATE_COST

func _process(_delta: float) -> void:
    if visible:
        refresh()

func open() -> void:
    if hud.menu_open():
        return
    _paused_before_open = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    _detail.text = "Hover a node to see what it gives. Each node needs the ones above it."
    refresh()
    show()
    _close.grab_focus()

func close() -> void:
    if not visible:
        return
    hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before_open
