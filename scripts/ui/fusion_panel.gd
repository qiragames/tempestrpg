extends Control
## Skill fusion window (U) — the Recipe Book (user's choice from the fusion proposals,
## 2026-10-22). Every fusion is listed on the left: ready ones, ones you hold a part of, and
## undiscovered ones as "???". The selected recipe's page shows both parts, the result with its
## stats and description, what it needs (both skills held and active, the creature analyzed) and
## Fuse; a fused skill shows Split, which always gives both skills back. The host decides.
const UI := preload("res://scripts/ui/ui_style.gd")
const CATALOGUE := preload("res://scripts/skills/skill_catalogue.gd")
const TREE := preload("res://scripts/skills/skill_tree.gd")
const ORIGIN := Vector2(20, 8)
const FRAME := Vector2(600, 344)
const LIST := Rect2(14, 40, 280, 270)
const PAGE := Rect2(306, 40, 280, 270)
## Recipe states, best first (the list is sorted by them).
const STATES := ["fused", "ready", "partial", "undiscovered"]
const STATE_TEXT := {"fused": "Fused", "ready": "Ready", "partial": "%d / 2 known", "undiscovered": "Undiscovered"}

var hud: CanvasLayer
var _detail: Label
var _close: Button
var _list: VBoxContainer
var _rows: Dictionary = {}
var _part_icons: Array = []
var _part_names: Array = []
var _result_icon: TextureRect
var _result_name: Label
var _description: Label
var _stats: Label
var _needs: RichTextLabel
var _fuse: Button
var _split: Button
var selected := ""
## A fusion or split sent to the host, until its result shows up.
var _pending: Dictionary = {}
var _paused_before_open: bool = false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "FusionPanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.8)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var frame := Panel.new()
    frame.position = ORIGIN
    frame.size = FRAME
    frame.add_theme_stylebox_override("panel", UI.ornate())
    add_child(frame)
    UI.heading(hud._label("SKILL FUSION · RECIPE BOOK", ORIGIN + Vector2(14, 10), Vector2(400, 20), self, 14))
    _close = hud._button("Close", ORIGIN + Vector2(FRAME.x - 94, 8), Vector2(80, 24), self)
    _close.pressed.connect(close)
    # The recipe list.
    var well := Panel.new()
    well.position = ORIGIN + LIST.position
    well.size = LIST.size
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.06, 0.14, 0.9)
    style.border_color = Color(0.55, 0.42, 0.85)
    style.set_border_width_all(1)
    well.add_theme_stylebox_override("panel", style)
    add_child(well)
    var scroll := ScrollContainer.new()
    scroll.name = "Recipes"
    scroll.position = ORIGIN + LIST.position + Vector2(4, 4)
    scroll.size = LIST.size - Vector2(8, 8)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    _list = VBoxContainer.new()
    _list.add_theme_constant_override("separation", 3)
    _list.custom_minimum_size = Vector2(LIST.size.x - 20, 0)
    scroll.add_child(_list)
    # The recipe page.
    var page := Panel.new()
    page.position = ORIGIN + PAGE.position
    page.size = PAGE.size
    page.add_theme_stylebox_override("panel", UI.round_slot("slot"))
    add_child(page)
    var p := ORIGIN + PAGE.position
    for index in range(2):
        var icon := _icon(p + Vector2(10 + index * 74, 10), 40)
        _part_icons.append(icon)
        var label: Label = hud._label("", p + Vector2(index * 74, 52), Vector2(70, 14), self, 8)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _part_names.append(label)
    hud._label("+", p + Vector2(58, 20), Vector2(14, 20), self, 14).add_theme_color_override("font_color", UI.GOLD_LIGHT)
    hud._label("→", p + Vector2(132, 20), Vector2(20, 20), self, 14).add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _result_icon = _icon(p + Vector2(160, 6), 48)
    _result_name = hud._label("", p + Vector2(150, 56), Vector2(124, 14), self, 9)
    _result_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _result_name.add_theme_color_override("font_color", Color("6fd0ff"))
    _description = hud._label("", p + Vector2(10, 76), Vector2(PAGE.size.x - 20, 48), self, 9)
    _stats = hud._label("", p + Vector2(10, 126), Vector2(PAGE.size.x - 20, 30), self, 9)
    _stats.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _needs = RichTextLabel.new()
    _needs.bbcode_enabled = true
    _needs.fit_content = true
    _needs.scroll_active = false
    _needs.position = p + Vector2(10, 160)
    _needs.size = Vector2(PAGE.size.x - 20, 60)
    _needs.add_theme_font_size_override("normal_font_size", 9)
    _needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_needs)
    _fuse = hud._button("Fuse", p + Vector2(10, PAGE.size.y - 40), Vector2(126, 30), self)
    _fuse.add_theme_font_size_override("font_size", 12)
    _fuse.pressed.connect(fuse_selected)
    _split = hud._button("Split", p + Vector2(144, PAGE.size.y - 40), Vector2(126, 30), self)
    _split.pressed.connect(split_selected)
    _detail = hud._label("", ORIGIN + Vector2(14, LIST.end.y + 4), Vector2(FRAME.x - 28, 14), self, 9)
    hud._label("U / Esc: close · fusing replaces both skills; Split always gives them back · new recipes appear as you find their skills", ORIGIN + Vector2(14, FRAME.y - 18), Vector2(FRAME.x - 28, 12), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func _icon(at: Vector2, side: float) -> TextureRect:
    var icon := TextureRect.new()
    icon.position = at
    icon.size = Vector2(side, side)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(icon)
    return icon

func _book() -> Node:
    return hud.player.get_node("SkillBook")

## The skill resource, also for skills this character does not hold.
func _skill(id: String) -> Resource:
    var held: Resource = _book().get_skill(StringName(id))
    if held != null:
        return held
    if CATALOGUE.SKILLS.has(id):
        return load(CATALOGUE.SKILLS[id])
    return load(TREE.SKILLS[id]) if TREE.SKILLS.has(id) else null

## Every fusion recipe (the fused skills of the catalogue).
static func recipe_ids() -> Array:
    return CATALOGUE.RULES.keys().filter(func(id): return CATALOGUE.is_fused(id) and CATALOGUE.components(id).size() == 2)

## How far this character is with a recipe: "fused", "ready", "partial" or "undiscovered".
func state(id: String) -> String:
    var book := _book()
    if book.knows(StringName(id)):
        return "fused"
    var parts: Array = CATALOGUE.components(id)
    var known: int = parts.filter(func(part): return book.knows(StringName(part))).size()
    if known == 2:
        return "ready"
    return "partial" if known == 1 else "undiscovered"

func _problems(id: String) -> Array:
    var book := _book()
    var lines: Array = []
    for part in CATALOGUE.components(id):
        var skill: Resource = _skill(part)
        var name: String = skill.display_name if skill != null and state(id) != "undiscovered" else "???"
        lines.append([book.knows(StringName(part)) or state(id) == "fused", "You hold %s" % name])
        if book.knows(StringName(part)) and not book.is_active(StringName(part)):
            lines.append([false, "%s is active (skill tree, K)" % name])
    var specimen: String = CATALOGUE.RULES[id].analysis
    var species: String = load(CATALOGUE.SPECIMENS[specimen]).species if CATALOGUE.SPECIMENS.has(specimen) else specimen
    lines.append([specimen in book.evidence.analyzed, "Analyzed a %s" % (species if state(id) != "undiscovered" else "???")])
    return lines

func _rebuild_list() -> void:
    var ids := recipe_ids()
    ids.sort_custom(func(a, b): return STATES.find(state(a)) < STATES.find(state(b)) or (STATES.find(state(a)) == STATES.find(state(b)) and a < b))
    if selected.is_empty() or not selected in ids:
        selected = ids[0] if not ids.is_empty() else ""
    for id in _rows.keys():
        if not id in ids:
            _rows[id].queue_free()
            _rows.erase(id)
    for index in range(ids.size()):
        var id: String = ids[index]
        if not _rows.has(id):
            _rows[id] = _make_row(id)
        var row: Button = _rows[id]
        _list.move_child(row, index)
        _fill_row(row, id)

func _make_row(id: String) -> Button:
    var row := Button.new()
    row.name = "Recipe_" + id
    row.custom_minimum_size = Vector2(LIST.size.x - 20, 40)
    row.toggle_mode = true
    row.focus_mode = Control.FOCUS_NONE
    row.pressed.connect(func(): select(id))
    _list.add_child(row)
    var box := HBoxContainer.new()
    box.name = "Box"
    box.position = Vector2(6, 4)
    box.size = Vector2(LIST.size.x - 32, 32)
    box.add_theme_constant_override("separation", 4)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(box)
    for part in ["A", "plus", "B", "arrow", "R", "state"]:
        if part in ["A", "B", "R"]:
            var icon := TextureRect.new()
            icon.name = part
            icon.custom_minimum_size = Vector2(32, 32)
            icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
            box.add_child(icon)
        else:
            var label := Label.new()
            label.name = part
            label.text = {"plus": "+", "arrow": "→", "state": ""}[part]
            label.add_theme_font_size_override("font_size", 12 if part != "state" else 9)
            label.add_theme_color_override("font_color", UI.GOLD_LIGHT)
            label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            label.custom_minimum_size = Vector2(0, 32)
            if part == "state":
                label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
            label.mouse_filter = Control.MOUSE_FILTER_IGNORE
            box.add_child(label)
    return row

## Unknown parts show as a question mark (no icon).
func _shown_icon(id: String, known: bool) -> Texture2D:
    return UI.skill_icon(id) if known else null

func _fill_row(row: Button, id: String) -> void:
    var now := state(id)
    var parts: Array = CATALOGUE.components(id)
    var book := _book()
    var box: Node = row.get_node("Box")
    var discovered: bool = now != "undiscovered"
    box.get_node("A").texture = _shown_icon(parts[0], now == "fused" or book.knows(StringName(parts[0])))
    box.get_node("B").texture = _shown_icon(parts[1], now == "fused" or book.knows(StringName(parts[1])))
    box.get_node("R").texture = _shown_icon(id, now in ["fused", "ready"])
    var label: Label = box.get_node("state")
    label.text = STATE_TEXT[now] % 1 if now == "partial" else STATE_TEXT[now]
    label.add_theme_color_override("font_color", {"fused": Color("6fd0ff"), "ready": Color("8fe08a"), "partial": UI.TEXT_DIM, "undiscovered": UI.TEXT_DIM}[now])
    row.set_pressed_no_signal(id == selected)
    row.tooltip_text = _skill(id).display_name if discovered else "An undiscovered fusion"
    row.modulate = Color.WHITE if discovered else Color(1, 1, 1, 0.6)

func select(id: String) -> void:
    selected = id
    refresh()

func _fill_page() -> void:
    if selected.is_empty():
        _description.text = "No fusions known yet."
        _fuse.disabled = true
        _split.disabled = true
        return
    var now := state(selected)
    var parts: Array = CATALOGUE.components(selected)
    var book := _book()
    for index in range(2):
        var part: String = parts[index]
        var known: bool = now == "fused" or book.knows(StringName(part))
        _part_icons[index].texture = _shown_icon(part, known)
        _part_names[index].text = _skill(part).display_name if known else "?"
    var revealed: bool = now in ["fused", "ready"]
    var result: Resource = _skill(selected)
    _result_icon.texture = _shown_icon(selected, revealed)
    _result_name.text = "%s · %s" % [result.display_name, result.tier] if revealed else "???"
    _description.text = result.description if revealed else "Hold both skills to see what they become."
    _stats.text = "%d damage · %.0f Magicules · %.1f s cooldown" % [result.damage, result.magicule_cost, result.cooldown] if revealed else ""
    var lines: Array = _problems(selected)
    _needs.text = "\n".join(lines.map(func(line): return "[color=#%s]%s[/color] %s" % ["8fe08a" if line[0] else "ff8a7a", "✓" if line[0] else "✗", line[1]]))
    _fuse.visible = now != "fused"
    _split.visible = now == "fused"
    _fuse.disabled = now != "ready" or not lines.all(func(line): return line[0]) or not _pending.is_empty()
    _split.disabled = not _pending.is_empty()

## Fuse the selected recipe's two skills (the host checks everything again).
func fuse_selected() -> void:
    if selected.is_empty() or state(selected) != "ready":
        return
    var parts: Array = CATALOGUE.components(selected)
    _pending = {"result": selected}
    if hud.session.active:
        hud.session.request_action("fusion", {"operation": "fuse", "a": parts[0], "b": parts[1]})
    else:
        hud.player.fuse_skills(parts[0], parts[1])
    refresh()

func split_selected() -> void:
    if selected.is_empty() or state(selected) != "fused":
        return
    _pending = {"split": selected}
    if hud.session.active:
        hud.session.request_action("fusion", {"operation": "split", "id": selected})
    else:
        hud.player.split_skill(selected)
    refresh()

## Keeps the book in step with what the character holds (host results arrive by snapshot).
func refresh() -> void:
    if not is_instance_valid(hud.player):
        return
    if not _pending.is_empty():
        if _pending.has("result") and state(_pending.result) == "fused":
            _detail.text = "Fused: %s (%s). Both skills were replaced; Split gives them back." % [_skill(_pending.result).display_name, _skill(_pending.result).tier]
            _pending = {}
        elif _pending.has("split") and state(_pending.split) != "fused":
            _detail.text = "Split back into %s." % " + ".join(CATALOGUE.components(_pending.split).map(func(part): return _skill(part).display_name))
            _pending = {}
    _rebuild_list()
    _fill_page()

func _process(_delta: float) -> void:
    if visible:
        refresh()

## Shows the latest System Voice reason when the host refused a fusion.
func show_message(text: String) -> void:
    if visible and not _pending.is_empty() and not text.begins_with("Fusion:") and not text.begins_with("Split:"):
        _pending = {}
        _detail.text = text

func open() -> void:
    if hud.menu_open():
        return
    _paused_before_open = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    _detail.text = "Pick a recipe on the left."
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
