extends Control
## Professions window (M6a, L): every profession's level, experience to the next level, perks and
## milestones, and for the selected one what it can work with — each wood, ore, fish or recipe with
## its required level and your current success chance (soft gates: everything can be tried).
const UI := preload("res://scripts/ui/ui_style.gd")
const PRO := preload("res://scripts/professions/profession_catalogue.gd")
const FISHES := preload("res://scripts/professions/fish_catalogue.gd")
const CRAFT := preload("res://scripts/professions/crafting_catalogue.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const FRAME := Rect2(40, 10, 560, 338)

var hud: CanvasLayer
var _tabs: Array = []
var _selected := "woodcutting"
var _header: Label
var _bar: ProgressBar
var _perks: Label
var _milestones: Label
var _list: VBoxContainer
var _paused_before := false

## M6c / M11e: professions that craft, and their button's word.
const CRAFTS := ["smithing", "alchemy", "cooking", "enchanting", "tailoring"]
const CRAFT_VERB := {"smithing": "Smelt", "alchemy": "Brew", "cooking": "Cook", "enchanting": "Inscribe", "tailoring": "Sew"}

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "ProfessionsPanel"
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
    UI.heading(hud._label("PROFESSIONS", FRAME.position + Vector2(14, 10), Vector2(300, 20), self, 14))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    close.pressed.connect(close_panel)
    # M11e: eight professions share the row.
    var tab_width: float = (FRAME.size.x - 28.0 - 3.0 * (PRO.ORDER.size() - 1)) / PRO.ORDER.size()
    var x := 14.0
    for id in PRO.ORDER:
        var tab: Button = hud._button("", FRAME.position + Vector2(x, 36), Vector2(tab_width, 34), self)
        tab.add_theme_font_size_override("font_size", 8)
        tab.clip_text = true
        # M13b: the profession's icon over its level; the name is the tooltip.
        tab.icon = load("res://assets/game/ui/icons/professions/%s.png" % id)
        tab.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        tab.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
        tab.tooltip_text = PRO.PROFESSIONS[id][0]
        tab.pressed.connect(func(): _select(id))
        tab.set_meta("id", id)
        _tabs.append(tab)
        x += tab_width + 3.0
    _header = hud._label("", FRAME.position + Vector2(14, 76), Vector2(FRAME.size.x - 28, 16), self, 10)
    _header.autowrap_mode = TextServer.AUTOWRAP_OFF
    _header.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _header.clip_text = true
    _bar = ProgressBar.new()
    _bar.position = FRAME.position + Vector2(14, 94)
    _bar.size = Vector2(FRAME.size.x - 28, 8)
    _bar.show_percentage = false
    UI.style_bar(_bar, UI.XP)
    add_child(_bar)
    _perks = hud._label("", FRAME.position + Vector2(14, 106), Vector2(FRAME.size.x - 28, 14), self, 9)
    _perks.add_theme_color_override("font_color", UI.CYAN)
    _milestones = hud._label("", FRAME.position + Vector2(14, 122), Vector2(FRAME.size.x - 28, 40), self, 8)
    _milestones.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var scroll := ScrollContainer.new()
    scroll.position = FRAME.position + Vector2(14, 166)
    scroll.size = Vector2(FRAME.size.x - 28, FRAME.size.y - 190)
    add_child(scroll)
    _list = VBoxContainer.new()
    _list.custom_minimum_size = Vector2(FRAME.size.x - 44, 0)
    _list.add_theme_constant_override("separation", 1)
    scroll.add_child(_list)
    hud._label("Everything can be tried: below the level it is slower and fails more · the % is your chance per try · L / Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
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
    refresh()

func close_panel() -> void:
    if not visible:
        return
    hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before

func _select(id: String) -> void:
    _selected = id
    refresh()

static func chance_colour(chance: float) -> Color:
    return Color("7ee07e") if chance >= 0.6 else (Color("f0d060") if chance >= 0.3 else Color("ff7a6a"))

## Rows for the selected profession: [name, required level] of what it works with.
func _entries(profession: String) -> Array:
    var rows: Array = []
    match profession:
        "woodcutting":
            for id in PRO.WOODS:
                rows.append([PRO.WOODS[id][0], int(PRO.WOODS[id][1]), ", ".join(PRO.WOODS[id][5])])
        "mining":
            for id in PRO.ORES:
                rows.append([PRO.ORES[id][0], int(PRO.ORES[id][1]), ", ".join(PRO.ORES[id][5])])
        "fishing":
            rows = FISHES.entries()
        _:
            rows = PRO.entries_for(profession)
    rows.sort_custom(func(a, b): return a[1] < b[1])
    return rows

func refresh() -> void:
    var progression: Dictionary = hud.player.progression
    for tab in _tabs:
        var id: String = tab.get_meta("id")
        tab.text = "Lv %d" % PRO.level_of(progression, id)
        tab.modulate = Color(1, 1, 1) if id == _selected else Color(0.7, 0.7, 0.7)
    var xp: int = int(progression.get("professions", {}).get(_selected, 0))
    var level := PRO.level_for(xp)
    var span_from := PRO.xp_for(level)
    var span_to := PRO.xp_for(mini(PRO.MAX_LEVEL, level + 1))
    _header.text = "%s — level %d / %d · %s" % [PRO.PROFESSIONS[_selected][0], level, PRO.MAX_LEVEL, PRO.PROFESSIONS[_selected][1]]
    _bar.max_value = maxi(1, span_to - span_from)
    _bar.value = xp - span_from if level < PRO.MAX_LEVEL else _bar.max_value
    var speed := int(round((1.0 - PRO.work_seconds(1.0, level, 0)) * 100.0))
    _perks.text = "%s · %d%% faster · %.1f%% double yield%s" % ["%d / %d XP to level %d" % [xp - span_from, span_to - span_from, level + 1] if level < PRO.MAX_LEVEL else "Max level", speed, PRO.double_chance(level) * 100.0, " · +5% chance" if level >= 10 else ""]
    var parts: Array = []
    for milestone in PRO.MILESTONES[_selected]:
        parts.append("%s Lv %d %s: %s" % ["✓" if level >= milestone[0] else "·", milestone[0], milestone[1], milestone[2]])
    _milestones.text = "   ".join(parts)
    for child in _list.get_children():
        child.queue_free()
    var rows := _entries(_selected)
    if _selected == "fishing":
        var log: Dictionary = progression.get("fish_log", {})
        var rod: int = int(progression.get("tools", {}).get("rod", 0))
        var line: Label = hud._label("Fish log: %d / %d kinds caught · the %% is the green zone (your chance per press)" % [log.size(), FISHES.FISH.size()], Vector2.ZERO, Vector2(FRAME.size.x - 44, 13), _list, 8)
        line.custom_minimum_size = Vector2(FRAME.size.x - 44, 13)
        line.add_theme_color_override("font_color", UI.GOLD_LIGHT)
        for row in rows:
            var caught: int = int(log.get(row[4], 0))
            var zone := FISHES.zone(level, row[4], rod)
            var known: bool = caught > 0 or int(row[3]) < 5
            var text := "%s%s · %s · needs Lv %d · zone %d%% · %s%s" % ["" if caught > 0 else "○ ", row[0] if known else "???", FISHES.RARITIES[row[3]], row[1], int(round(zone * 100.0)), row[2], " · caught ×%d" % caught if caught > 0 else ""]
            var fish_line: Label = hud._label(text, Vector2.ZERO, Vector2(FRAME.size.x - 44, 13), _list, 8)
            fish_line.custom_minimum_size = Vector2(FRAME.size.x - 44, 13)
            fish_line.add_theme_color_override("font_color", FISHES.RARITY_COLOURS[row[3]] if caught > 0 else FISHES.RARITY_COLOURS[row[3]].darkened(0.35))
        return
    if _selected in CRAFTS:
        _craft_rows(_selected, level)
    for row in rows:
        var chance := PRO.chance(level, row[1])
        var line: Label = hud._label("%-22s needs Lv %2d · your chance %d%%%s" % [row[0], row[1], int(round(chance * 100.0)), "   (%s)" % row[2] if row.size() > 2 and not String(row[2]).is_empty() else ""], Vector2.ZERO, Vector2(FRAME.size.x - 44, 13), _list, 8)
        line.custom_minimum_size = Vector2(FRAME.size.x - 44, 13)
        line.add_theme_color_override("font_color", chance_colour(chance))
    if rows.is_empty() and not _selected in CRAFTS:
        hud._label("Nothing here yet.", Vector2.ZERO, Vector2(FRAME.size.x - 44, 13), _list, 8).add_theme_color_override("font_color", UI.TEXT_DIM)

## Name of an ingredient ("log_*"/"gem_*" are any log or gem).
static func ingredient_name(id: String) -> String:
    if id == "log_*":
        return "any log"
    if id == "gem_*":
        return "any gem"
    if id == "fish_*":
        return "any fish"
    if TRADE.is_good(id):
        return TRADE.good_info(id)[0]
    return id.replace("_", " ").capitalize()

func _needs_text(needs: Dictionary) -> String:
    var parts: Array = []
    for id in needs:
        parts.append("%d %s (%d)" % [int(needs[id]), ingredient_name(id), hud.player.ingredient_count(id)])
    return ", ".join(parts)

func _can_make(needs: Dictionary) -> bool:
    for id in needs:
        if hud.player.ingredient_count(id) < int(needs[id]):
            return false
    return true

func _row(text: String, colour: Color, button_text: String, enabled: bool, action: Callable, picker: OptionButton = null) -> void:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(FRAME.size.x - 44, 16)
    _list.add_child(row)
    var label: Label = hud._label(text, Vector2.ZERO, Vector2(10, 13), row, 8)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    # One line, trimmed with "…" (wrapping would collapse the label inside the row).
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    label.tooltip_text = text
    label.mouse_filter = Control.MOUSE_FILTER_PASS
    label.add_theme_color_override("font_color", colour)
    if picker != null:
        row.add_child(picker)
    var button: Button = hud._button(button_text, Vector2.ZERO, Vector2(58, 15), row)
    button.custom_minimum_size = Vector2(58, 15)
    button.add_theme_font_size_override("font_size", 8)
    button.disabled = not enabled
    button.pressed.connect(action)

## M6c: Smithing and Alchemy recipes with their chance, ingredients (what you have) and a button.
func _craft_rows(profession: String, level: int) -> void:
    var station: String = hud.player.craft_station(profession)
    var where := {"town": "in a town", "forge": "at the camp's Forge", "shrine": "at the camp's Essence Shrine"}
    var head: Label = hud._label("Crafting %s · a failed try loses the ingredients" % where[station] if not station.is_empty() else "Go to a town or the camp's %s to craft." % ("Forge" if profession in ["smithing", "tailoring"] else "Essence Shrine"), Vector2.ZERO, Vector2(FRAME.size.x - 44, 13), _list, 8)
    head.custom_minimum_size = Vector2(FRAME.size.x - 44, 13)
    head.add_theme_color_override("font_color", UI.GOLD_LIGHT if not station.is_empty() else Color("ff9a7a"))
    var recipes: Dictionary = CRAFT.recipes(profession)
    for id in recipes:
        if id.begins_with("forge:") or id.begins_with("tailor:"):
            continue
        var recipe: Array = recipes[id]
        # Boss uniques show once you carry some of that boss's material.
        if id.begins_with("bossforge:") and not recipe[2].keys().any(func(need): return String(need).begins_with("bossmat_") and hud.player.ingredient_count(need) > 0):
            continue
        var chance := PRO.chance(level, recipe[1])
        _row("%s · Lv %d · %d%% · %s" % [recipe[0], recipe[1], int(round(chance * 100.0)), _needs_text(recipe[2])], chance_colour(chance), CRAFT_VERB[profession], not station.is_empty() and _can_make(recipe[2]), _craft.bind(id))
    if profession == "tailoring":
        # M11e: one row per cloth with a picker for the piece.
        for cloth in CRAFT.CLOTHS:
            var cloth_required: int = int(CRAFT.CLOTHS[cloth][1]) + 2
            var cloth_chance := PRO.chance(level, cloth_required)
            var piece_picker := OptionButton.new()
            piece_picker.add_theme_font_size_override("font_size", 8)
            piece_picker.custom_minimum_size = Vector2(96, 15)
            for slot in CRAFT.TAILOR:
                piece_picker.add_item("%s (%d)" % [CRAFT.TAILOR[slot][0], CRAFT.TAILOR[slot][1]])
                piece_picker.set_item_metadata(piece_picker.item_count - 1, slot)
            var cloth_band: Array = CRAFT.CLOTHS[cloth][2]
            _row("Sew %s (item Lv %d-%d) · Lv %d · %d%% · you have %d %s" % [CRAFT.CLOTHS[cloth][0], cloth_band[0], cloth_band[1], cloth_required, int(round(cloth_chance * 100.0)), hud.player.ingredient_count(cloth), ingredient_name(cloth)], chance_colour(cloth_chance), "Sew", not station.is_empty() and hud.player.ingredient_count(cloth) >= 2, func(): _craft("tailor:%s:%s" % [cloth, piece_picker.get_item_metadata(piece_picker.selected)]), piece_picker)
        return
    if profession != "smithing":
        return
    # Forging: one row per bar with a picker for what to make.
    for bar in CRAFT.BARS:
        var required: int = int(CRAFT.BARS[bar][1]) + 2
        var chance := PRO.chance(level, required)
        var picker := OptionButton.new()
        picker.add_theme_font_size_override("font_size", 8)
        picker.custom_minimum_size = Vector2(96, 15)
        for kind in CRAFT.FORGE:
            picker.add_item(forge_label(kind))
            picker.set_item_metadata(picker.item_count - 1, kind)
        var band: Array = CRAFT.BAR_LEVELS[bar]
        _row("Forge %s gear (item Lv %d-%d) · Lv %d · %d%% · you have %d" % [CRAFT.BARS[bar][0].trim_suffix(" Bar"), band[0], band[1], required, int(round(chance * 100.0)), hud.player.ingredient_count(bar)], chance_colour(chance), "Forge", not station.is_empty() and hud.player.ingredient_count(bar) > 0, func(): _craft("forge:%s:%s" % [bar, picker.get_item_metadata(picker.selected)]), picker)

## "Sword (3 bars, 1 log)" for the forge picker.
static func forge_label(kind: String) -> String:
    var spec: Array = CRAFT.FORGE[kind]
    var parts: Array = ["%d bar%s" % [spec[1], "" if spec[1] == 1 else "s"]]
    if spec[2] > 0:
        parts.append("%d log%s" % [spec[2], "" if spec[2] == 1 else "s"])
    if spec[3] > 0:
        parts.append("%d gem" % spec[3])
    return "%s (%s)" % [spec[0], ", ".join(parts)]

func _craft(id: String) -> void:
    hud.session.request_action("craft", {"id": id})
    # Online the host answers with the next snapshot; refresh a moment later.
    get_tree().create_timer(0.15, true, false, true).timeout.connect(func():
        if visible:
            refresh()
    )

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if event.is_action_pressed("ui_cancel") or (event.is_action_pressed("professions") and not event.is_echo()):
        close_panel()
        get_viewport().set_input_as_handled()
