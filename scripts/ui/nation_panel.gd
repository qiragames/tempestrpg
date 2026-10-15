extends Control
## Nation window (M5a, key N): the nation's name and banner (the founder chooses), its tier and
## what the next one needs (Rank up at the camp flag), and the buildings to place. Picking a
## building starts the build mode: a ghost follows the mouse on the tile grid (green = fits,
## red = the reason is shown), left click builds, right click or Esc stops; "Demolish" removes a
## building under the mouse. Only names and tiles travel to the host (FirstCamp checks all).
const UI := preload("res://scripts/ui/ui_style.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const TERRAIN := preload("res://scripts/world/world_terrain.gd")
const FRAME := Rect2(70, 14, 500, 330)

var hud: CanvasLayer
var _title: Label
var _tier: Label
var _rank: Button
var _name: LineEdit
var _rename: Button
var _colors: Array = []
var _emblems: Array = []
var _build_buttons: Dictionary = {}
var _demolish: Button
var _banner: Control
var _paused_before := false
## Build mode: the kind being placed ("demolish" to tear down), the ghost in the world.
var mode := ""
var _ghost: Node2D
var _hint: Label
var ghost_tile := Vector2i.ZERO
## Aimed from code (tests, playtest) until the mouse moves again.
var _manual := false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "NationPanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var window := Control.new()
    window.name = "Window"
    window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(window)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.8)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    window.add_child(backdrop)
    var frame := Panel.new()
    frame.position = FRAME.position
    frame.size = FRAME.size
    frame.add_theme_stylebox_override("panel", UI.ornate())
    window.add_child(frame)
    _title = UI.heading(hud._label("", FRAME.position + Vector2(56, 10), Vector2(330, 20), window, 14))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), window)
    close.pressed.connect(close_panel)
    _banner = Control.new()
    _banner.position = FRAME.position + Vector2(16, 8)
    _banner.size = Vector2(34, 40)
    _banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _banner.draw.connect(_draw_banner)
    window.add_child(_banner)
    # Name and banner (founder).
    hud._label("Name", FRAME.position + Vector2(56, 38), Vector2(40, 16), window, 9).add_theme_color_override("font_color", UI.TEXT_DIM)
    _name = LineEdit.new()
    _name.position = FRAME.position + Vector2(92, 34)
    _name.size = Vector2(180, 22)
    _name.max_length = NATION.NAME_LENGTH
    _name.add_theme_font_size_override("font_size", 10)
    _name.placeholder_text = "Name your nation"
    window.add_child(_name)
    _rename = hud._button("Rename", FRAME.position + Vector2(278, 34), Vector2(70, 22), window)
    _rename.add_theme_font_size_override("font_size", 9)
    _rename.pressed.connect(func(): _send("name", _name.text))
    for index in range(NATION.COLORS.size()):
        var swatch: Button = hud._button("", FRAME.position + Vector2(56 + index * 20, 62), Vector2(16, 16), window)
        var style := StyleBoxFlat.new()
        style.bg_color = NATION.COLORS[index]
        swatch.add_theme_stylebox_override("normal", style)
        swatch.add_theme_stylebox_override("hover", style)
        swatch.pressed.connect(func(): _send("banner", "%d,%d" % [index, int(_nation().emblem)]))
        _colors.append(swatch)
    for index in range(NATION.EMBLEMS.size()):
        var emblem: Button = hud._button(NATION.EMBLEMS[index], FRAME.position + Vector2(222 + index * 44, 60), Vector2(42, 20), window)
        emblem.add_theme_font_size_override("font_size", 8)
        emblem.pressed.connect(func(): _send("banner", "%d,%d" % [int(_nation().color), index]))
        _emblems.append(emblem)
    # Tier.
    _tier = hud._label("", FRAME.position + Vector2(16, 84), Vector2(FRAME.size.x - 130, 46), window, 9)
    _rank = hud._button("Rank up", FRAME.position + Vector2(FRAME.size.x - 108, 90), Vector2(96, 26), window)
    _rank.pressed.connect(func(): _send("rank", "next"))
    # Buildings.
    UI.heading(hud._label("BUILD", FRAME.position + Vector2(16, 130), Vector2(200, 16), window, 11))
    var index := 0
    for kind in NATION.BUILDINGS:
        var button: Button = hud._button("", FRAME.position + Vector2(16 + (index % 3) * 158, 150 + int(index / 3) * 40), Vector2(152, 36), window)
        button.add_theme_font_size_override("font_size", 8)
        button.pressed.connect(start_mode.bind(kind))
        button.tooltip_text = NATION.BUILDINGS[kind][6]
        _build_buttons[kind] = button
        index += 1
    _demolish = hud._button("Demolish…", FRAME.position + Vector2(16 + (index % 3) * 158, 150 + int(index / 3) * 40), Vector2(152, 36), window)
    _demolish.add_theme_font_size_override("font_size", 9)
    _demolish.pressed.connect(start_mode.bind("demolish"))
    hud._label("Build anywhere inside your settlement's ring · materials come from the camp stock (B) · N / Esc: close", FRAME.position + Vector2(16, FRAME.size.y - 22), Vector2(FRAME.size.x - 32, 14), window, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    window.hide()
    _hint = hud._label("", Vector2(120, 300), Vector2(400, 40), self, 10)
    _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hint.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _hint.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05))
    _hint.add_theme_constant_override("outline_size", 4)
    _hint.hide()

func window() -> Control:
    return get_node("Window")

func camp() -> Node2D:
    return hud.get_parent().camp

func _nation() -> Dictionary:
    return camp().state.nation

func is_open() -> bool:
    return window().visible or not mode.is_empty()

func open() -> void:
    if hud.menu_open() or not camp().state.founded:
        if not camp().state.founded:
            hud.session.notify_character(hud.player.character_id, "Found the camp first (B at the camp flag).")
        return
    _paused_before = get_tree().paused
    _block(true)
    if not hud.session.active:
        get_tree().paused = true
    _name.text = _nation().name
    window().show()
    _refresh()

func close_panel() -> void:
    if not window().visible:
        return
    window().hide()
    _block(false)
    get_tree().paused = _paused_before

func _block(on: bool) -> void:
    if hud.session.active:
        hud.player.input_blocked = on
        hud.session.request_action("menu", {"open": on})

func _send(operation: String, id: String) -> void:
    hud.session.request_action("camp", {"operation": operation, "id": id})
    _refresh()

func _refresh() -> void:
    var nation := _nation()
    var founder: bool = camp().state.founder == hud.player.character_id
    _title.text = ("%s · %s" % [nation.name, NATION.tier_name(int(nation.tier))] if not String(nation.name).is_empty() else "YOUR NATION · %s" % NATION.tier_name(int(nation.tier))).to_upper()
    _name.editable = founder
    _rename.disabled = not founder
    for button in _colors + _emblems:
        button.disabled = not founder
    var problem := NATION.tier_problem(nation, camp().state)
    var next: int = int(nation.tier) + 1
    var hungry: String = " · HUNGRY" if int(nation.hunger) > 0 else ""
    _tier.text = "%s with %d buildings · stock %d wood, %d stone, %d essence\nPopulation %d / %d homes · food %d (%d a day)%s · next newcomer in %d s\n%s" % [NATION.tier_name(int(nation.tier)), nation.buildings.size(), camp().state.wood, camp().state.stone, camp().state.essence,
        nation.citizens.size(), NATION.housing(nation, camp().state), int(nation.food), nation.citizens.size() * NATION.FOOD_PER_DAY, hungry, int(ceil(NATION.ARRIVAL_SECONDS - float(nation.arrival))),
        ("Next: %s (%s) — ready! Rank up at the camp flag." % [NATION.TIERS[next][0], NATION.cost_text(NATION.TIERS[next][2])]) if problem.is_empty() else problem]
    _rank.disabled = not problem.is_empty() or not camp().can_reach(hud.player, camp().SITE, 55)
    for kind in _build_buttons:
        var spec: Array = NATION.BUILDINGS[kind]
        var locked: bool = int(spec[4]) > int(nation.tier)
        _build_buttons[kind].text = "%s\n%s" % [spec[0], ("needs a %s" % NATION.tier_name(int(spec[4])).to_lower()) if locked else NATION.cost_text(spec[3])]
        _build_buttons[kind].disabled = locked or (spec[5] and NATION.count(nation, kind) > 0)
    _demolish.disabled = nation.buildings.is_empty()
    _banner.queue_redraw()

func _draw_banner() -> void:
    var color: Color = NATION.COLORS[int(_nation().color)]
    _banner.draw_rect(Rect2(2, 0, 2, 40), Color("6b4a2b"))
    _banner.draw_rect(Rect2(4, 2, 28, 20), color)
    _banner.draw_rect(Rect2(4, 2, 28, 20), color.darkened(0.4), false, 1.0)
    camp().draw_emblem(_banner, int(_nation().emblem), Vector2(18, 12), color.darkened(0.5) if color.get_luminance() > 0.6 else Color(1, 1, 1, 0.9), 2.0)

## --- Build mode
func start_mode(kind: String) -> void:
    close_panel()
    mode = kind
    _manual = false
    _block(true)
    _ghost = Node2D.new()
    _ghost.name = "BuildGhost"
    _ghost.z_index = 50
    _ghost.draw.connect(_draw_ghost)
    hud.get_parent().add_child(_ghost)
    _hint.show()
    _update_ghost()

func stop_mode() -> void:
    if mode.is_empty():
        return
    mode = ""
    if is_instance_valid(_ghost):
        _ghost.queue_free()
    _hint.hide()
    _block(false)

func _mouse_world() -> Vector2:
    return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()

## Builds go where the mouse points (on the tile grid); `aim` holds a tile chosen from code.
func aim(world: Vector2) -> void:
    _manual = true
    _aim(world)

func _aim(world: Vector2) -> void:
    ghost_tile = MAP.to_tile(world)
    if is_instance_valid(_ghost):
        _ghost.queue_redraw()
    _hint.text = _status()

func _status() -> String:
    if mode == "demolish":
        var id: String = camp().building_at(MAP.to_world(Vector2(ghost_tile)) + Vector2(8, 8))
        return "Click a building to tear it down (materials are lost) · right click / Esc: stop" if id.is_empty() else "Tear down this %s? Click to confirm · right click / Esc: stop" % NATION.BUILDINGS[_entry(id).kind][0]
    var problem: String = camp().place_problem(hud.player, mode, ghost_tile)
    return "%s · %s · click to build · right click / Esc: stop" % [NATION.BUILDINGS[mode][0], NATION.cost_text(NATION.BUILDINGS[mode][3])] if problem.is_empty() else problem

func _entry(id: String) -> Dictionary:
    for entry in _nation().buildings:
        if entry.id == id:
            return entry
    return {}

func _update_ghost() -> void:
    if not _manual:
        _aim(_mouse_world())

func _process(_delta: float) -> void:
    if not mode.is_empty():
        _update_ghost()
        if not is_instance_valid(hud.player) or hud.player.get_node("Health").current <= 0:
            stop_mode()
    elif window().visible:
        _refresh()

func _draw_ghost() -> void:
    var area_color := Color(0.3, 0.9, 0.4)
    # The settlement's ring.
    var site: Vector2 = camp().SITE
    _ghost.draw_arc(site, NATION.radius(int(_nation().tier)), 0, TAU, 128, Color(0.1, 0.08, 0.05, 0.5), 4.0)
    _ghost.draw_arc(site, NATION.radius(int(_nation().tier)), 0, TAU, 128, Color(1.0, 0.85, 0.4, 0.9), 2.0)
    if mode == "demolish":
        var id: String = camp().building_at(MAP.to_world(Vector2(ghost_tile)) + Vector2(8, 8))
        if not id.is_empty():
            var entry := _entry(id)
            var area := NATION.footprint(entry.kind, Vector2i(entry.tile[0], entry.tile[1]))
            _ghost.draw_rect(area.grow(2), Color(0.95, 0.3, 0.25, 0.45))
        _ghost.draw_rect(Rect2(MAP.to_world(Vector2(ghost_tile)), Vector2(MAP.TILE, MAP.TILE)), Color(0.95, 0.3, 0.25, 0.8), false, 1.0)
        return
    var fits: bool = camp().place_problem(hud.player, mode, ghost_tile).is_empty()
    if not fits:
        area_color = Color(0.95, 0.3, 0.25)
    var spec: Array = NATION.BUILDINGS[mode]
    var foot := NATION.foot(ghost_tile)
    if not String(spec[1]).is_empty():
        var art: Array = TERRAIN.PROPS[spec[1]]
        var region: Rect2 = art[1]
        _ghost.draw_texture_rect_region(load(art[0]), Rect2(foot - Vector2(region.size.x / 2.0, region.size.y), region.size), region, Color(1, 1, 1, 0.55))
    else:
        _ghost.draw_rect(Rect2(foot + Vector2(-1, -30), Vector2(2, 30)), Color(0.42, 0.29, 0.17, 0.7))
        _ghost.draw_rect(Rect2(foot + Vector2(1, -29), Vector2(14, 10)), Color(NATION.COLORS[int(_nation().color)], 0.7))
    _ghost.draw_rect(NATION.footprint(mode, ghost_tile), Color(area_color, 0.35))
    _ghost.draw_rect(NATION.footprint(mode, ghost_tile), area_color, false, 1.0)

## Build or tear down at the aimed tile (also used by the tests and the playtest).
func confirm() -> void:
    if mode == "demolish":
        var id: String = camp().building_at(MAP.to_world(Vector2(ghost_tile)) + Vector2(8, 8))
        if not id.is_empty():
            hud.session.request_action("camp", {"operation": "demolish", "id": id})
        return
    hud.session.request_action("camp", {"operation": "place", "id": "%s@%d,%d" % [mode, ghost_tile.x, ghost_tile.y]})

func _unhandled_input(event: InputEvent) -> void:
    if not mode.is_empty():
        if event is InputEventMouseMotion:
            _manual = false
        if event is InputEventMouseButton and event.pressed:
            if event.button_index == MOUSE_BUTTON_LEFT:
                _manual = false
                _aim(_mouse_world())
                confirm()
            elif event.button_index == MOUSE_BUTTON_RIGHT:
                stop_mode()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("ui_cancel") or (event.is_action_pressed("nation") and not event.is_echo()):
            stop_mode()
            get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("nation") and not event.is_echo():
        if window().visible:
            close_panel()
        elif not _name.has_focus():
            open()
        get_viewport().set_input_as_handled()
    elif window().visible and event.is_action_pressed("ui_cancel"):
        close_panel()
        get_viewport().set_input_as_handled()
