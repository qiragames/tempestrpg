extends Control
## Skill tree window (K). Left: this race's tree, three rows of two stat nodes and a skill node.
## Right: skills learned by absorbing or trials, each activated with a point before use.
## Functional placeholder layout; reference-style presentation follows in step 21.
const TREE := preload("res://scripts/skills/skill_tree.gd")
const ORIGIN := Vector2(30, 34)
const FRAME := Vector2(580, 292)

var hud: CanvasLayer
var _title: Label
var _detail: Label
var _close: Button
var _node_buttons: Dictionary = {}
var _activate_buttons: Array = []
var _skill_labels: Array = []
var _race: String = ""
var _paused_before_open: bool = false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "SkillTreePanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.8)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var frame := Panel.new()
    frame.position = ORIGIN
    frame.size = FRAME
    frame.add_theme_stylebox_override("panel", hud._panel_style())
    add_child(frame)
    _title = hud._label("", ORIGIN + Vector2(12, 8), Vector2(440, 20), self, 14)
    _title.add_theme_color_override("font_color", hud.UI.GOLD_LIGHT)
    _close = hud._button("Close", ORIGIN + Vector2(FRAME.x - 88, 6), Vector2(80, 24), self)
    _close.pressed.connect(close)
    hud.UI.heading(hud._label("LEARNED SKILLS", ORIGIN + Vector2(388, 36), Vector2(180, 16), self, 10))
    for index in range(4):
        _skill_labels.append(hud._label("", ORIGIN + Vector2(388, 56 + index * 40), Vector2(180, 16), self, 10))
        var button: Button = hud._button("", ORIGIN + Vector2(388, 72 + index * 40), Vector2(180, 20), self)
        button.pressed.connect(_activate.bind(index))
        _activate_buttons.append(button)
    _detail = hud._label("", ORIGIN + Vector2(12, 222), Vector2(556, 44), self, 10)
    hud._label("K / Esc: close · Each level gives 1 skill point", ORIGIN + Vector2(12, 270), Vector2(400, 16), self, 9)
    hide()

## Node buttons are rebuilt when the character's race changes (each race has its own tree).
func _build_nodes(race: String) -> void:
    for button in _node_buttons.values():
        button.queue_free()
    _node_buttons.clear()
    _race = race
    var columns := {}
    for id in TREE.nodes_for(race):
        var node: Dictionary = TREE.NODES[id]
        var column: int = columns.get(node.row, 0)
        columns[node.row] = column + 1
        var button: Button = hud._button("", ORIGIN + Vector2(12 + column * 122, 36 + node.row * 60), Vector2(116, 50), self)
        button.pressed.connect(_buy.bind(id))
        button.mouse_entered.connect(func(): _detail.text = "%s — %s" % [node.name, TREE.describe_node(id)])
        _node_buttons[id] = button

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
        var summary: String = ("Skill: " + node.name) if node.has("skill") else (TREE.STAT_TEXT[node.stat] % str(node.amount))
        _node_buttons[id].text = "%s%s\n%s" % ["✓ " if owned else "", node.name if not node.has("skill") else "★ " + node.name, summary if not node.has("skill") else ("learned" if owned else "1 point")]
        _node_buttons[id].disabled = not owned and not problem.is_empty()
    var book = player.get_node("SkillBook")
    var learned: Array = book.evidence_ids()
    for index in range(_activate_buttons.size()):
        var has_skill: bool = index < learned.size()
        _skill_labels[index].visible = has_skill
        _activate_buttons[index].visible = has_skill
        if has_skill:
            var skill: Resource = book.get_skill(StringName(learned[index]))
            var active: bool = learned[index] in progression.tree.active
            _skill_labels[index].text = "%s (%s)" % [skill.display_name, skill.tier]
            _activate_buttons[index].text = "Active ✓" if active else "Activate · 1 point"
            _activate_buttons[index].disabled = active or points < TREE.ACTIVATE_COST
    if learned.is_empty():
        _skill_labels[0].visible = true
        _skill_labels[0].text = "Absorb creatures to learn skills."

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
    _detail.text = "Hover a node to see what it gives. Buy nodes left to right, row by row."
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
