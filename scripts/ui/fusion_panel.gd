extends Control
## Skill fusion window (U). Your skills are listed on the right; drag one into the fusion area,
## then drag another onto it. If the two fuse, both are replaced by the fused skill (host decides).
## A fused skill in the area has a Split button that turns it back into its two skills.
## Functional placeholder layout; reference-style presentation follows in step 21.
const CATALOGUE := preload("res://scripts/skills/skill_catalogue.gd")
const TREE := preload("res://scripts/skills/skill_tree.gd")
const ORIGIN := Vector2(30, 34)
const FRAME := Vector2(580, 292)
const AREA := Rect2(12, 36, 360, 182)
const TILE := Vector2(104, 34)
const MAX_TILES := 6

var hud: CanvasLayer
var area: Panel
var _detail: Label
var _close: Button
var _list_buttons: Array = []
## Skills placed in the fusion area: [{id, position, button, split}]
var tiles: Array = []
## A fusion sent to the host: the result appears where the target tile was once it arrives.
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
    frame.add_theme_stylebox_override("panel", hud._panel_style())
    add_child(frame)
    hud._label("SKILL FUSION", ORIGIN + Vector2(12, 8), Vector2(300, 20), self, 14)
    _close = hud._button("Close", ORIGIN + Vector2(FRAME.x - 88, 6), Vector2(80, 24), self)
    _close.pressed.connect(close)
    area = Panel.new()
    area.position = ORIGIN + AREA.position
    area.size = AREA.size
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.06, 0.14, 0.9)
    style.border_color = Color(0.55, 0.42, 0.85)
    style.set_border_width_all(1)
    area.add_theme_stylebox_override("panel", style)
    area.set_drag_forwarding(Callable(), _can_drop, _drop_on_area)
    add_child(area)
    hud._label("Drop a skill here, then drop another skill onto it", ORIGIN + AREA.position + Vector2(8, AREA.size.y - 20), Vector2(340, 16), self, 9)
    hud._label("YOUR SKILLS (drag)", ORIGIN + Vector2(388, 36), Vector2(180, 16), self, 10)
    _detail = hud._label("", ORIGIN + Vector2(12, 224), Vector2(556, 44), self, 10)
    hud._label("U / Esc: close · Fusing replaces both skills; Split always gives them back", ORIGIN + Vector2(12, 270), Vector2(500, 16), self, 9)
    hide()

## Every skill this character holds, in hotbar-independent order: learned skills, then tree skills.
func _held() -> Array:
    var book = hud.player.get_node("SkillBook")
    return book.known_ids()

## The skill resource, also for skills this character does not hold (e.g. a refused drop).
func _skill(id: String) -> Resource:
    var held: Resource = hud.player.get_node("SkillBook").get_skill(StringName(id))
    if held != null:
        return held
    if CATALOGUE.SKILLS.has(id):
        return load(CATALOGUE.SKILLS[id])
    return load(TREE.SKILLS[id]) if TREE.SKILLS.has(id) else null

func _active(id: String) -> bool:
    return hud.player.get_node("SkillBook").is_active(StringName(id))

func _rebuild_list() -> void:
    var held: Array = _held()
    while _list_buttons.size() < held.size():
        var button: Button = hud._button("", Vector2.ZERO, Vector2(180, 24), self)
        var index := _list_buttons.size()
        button.position = ORIGIN + Vector2(388, 56 + index * 28)
        button.set_drag_forwarding(_drag_from_list.bind(index), Callable(), Callable())
        button.mouse_entered.connect(func(): _describe(_held()[index] if index < _held().size() else ""))
        _list_buttons.append(button)
    for index in range(_list_buttons.size()):
        var button: Button = _list_buttons[index]
        button.visible = index < held.size()
        if button.visible:
            var skill: Resource = _skill(held[index])
            button.text = "%s%s" % [skill.display_name, "" if _active(held[index]) else " (inactive)"]
            button.disabled = not _active(held[index])

func _describe(id: String) -> void:
    if id.is_empty() or _skill(id) == null:
        return
    var skill: Resource = _skill(id)
    _detail.text = "%s (%s) — %s%s" % [skill.display_name, skill.tier, skill.description, " Fused from %s." % " + ".join(CATALOGUE.components(id).map(func(part): return load(CATALOGUE.SKILLS[part]).display_name)) if CATALOGUE.is_fused(id) else ""]

func _drag_from_list(_at: Vector2, index: int) -> Variant:
    var held: Array = _held()
    if index >= held.size() or not _active(held[index]):
        return null
    _preview(held[index])
    return {"skill": held[index]}

func _drag_from_tile(_at: Vector2, tile_index: int) -> Variant:
    if tile_index >= tiles.size():
        return null
    _preview(tiles[tile_index].id)
    return {"skill": tiles[tile_index].id, "from_tile": tile_index}

func _preview(id: String) -> void:
    # Only valid inside a real drag (tests call the drag handlers directly).
    if not get_viewport().gui_is_dragging():
        return
    var label := Label.new()
    label.text = _skill(id).display_name
    label.add_theme_font_size_override("font_size", 11)
    set_drag_preview(label)

func _can_drop(_at: Vector2, data: Variant) -> bool:
    return data is Dictionary and data.get("skill") is String

## Dropping on empty area places a tile (or moves a dragged tile).
func _drop_on_area(at: Vector2, data: Variant) -> void:
    if not _can_drop(at, data):
        return
    var position: Vector2 = (at - TILE / 2).clamp(Vector2(4, 4), AREA.size - TILE - Vector2(4, 24))
    if data.has("from_tile"):
        tiles[data.from_tile].position = position
        _layout_tiles()
        return
    if tiles.any(func(tile): return tile.id == data.skill):
        _detail.text = "That skill is already in the fusion area."
        return
    if tiles.size() >= MAX_TILES:
        _detail.text = "The fusion area is full. Fuse or clear skills first."
        return
    _add_tile(data.skill, position)
    _detail.text = "%s placed. Drag another skill onto it to try a fusion." % _skill(data.skill).display_name

## Dropping a skill onto a tile tries to fuse the two.
func _drop_on_tile(_at: Vector2, data: Variant, tile_index: int) -> void:
    if not _can_drop(_at, data) or tile_index >= tiles.size():
        return
    var target: Dictionary = tiles[tile_index]
    if data.skill == target.id:
        return
    var result: String = CATALOGUE.fusion_for(target.id, data.skill)
    if result.is_empty():
        _detail.text = "%s and %s do not fuse." % [_skill(target.id).display_name, _skill(data.skill).display_name]
        return
    _pending = {"result": result, "parts": [target.id, data.skill], "position": target.position}
    if hud.session.active:
        hud.session.request_action("fusion", {"operation": "fuse", "a": target.id, "b": data.skill})
    else:
        hud.player.fuse_skills(target.id, data.skill)
    refresh()

func _split(tile_index: int) -> void:
    if tile_index >= tiles.size():
        return
    var id: String = tiles[tile_index].id
    _pending = {"split": id, "parts": CATALOGUE.components(id), "position": tiles[tile_index].position}
    if hud.session.active:
        hud.session.request_action("fusion", {"operation": "split", "id": id})
    else:
        hud.player.split_skill(id)
    refresh()

func _add_tile(id: String, position: Vector2) -> void:
    var button: Button = hud._button(_skill(id).display_name, Vector2.ZERO, TILE, area)
    var split: Button = hud._button("Split", Vector2.ZERO, Vector2(52, 18), area)
    split.visible = CATALOGUE.is_fused(id)
    tiles.append({"id": id, "position": position, "button": button, "split": split})
    button.mouse_entered.connect(func(): _describe(id))
    _layout_tiles()

## Re-binds drag/drop and split handlers to tile indices after any change.
func _layout_tiles() -> void:
    for index in range(tiles.size()):
        var tile: Dictionary = tiles[index]
        tile.button.position = tile.position
        tile.button.set_drag_forwarding(_drag_from_tile.bind(index), _can_drop, _drop_on_tile.bind(index))
        tile.split.position = tile.position + Vector2(TILE.x / 2 - 26, TILE.y + 2)
        for connection in tile.split.pressed.get_connections():
            tile.split.pressed.disconnect(connection.callable)
        tile.split.pressed.connect(_split.bind(index))

func _remove_tile(index: int) -> void:
    tiles[index].button.queue_free()
    tiles[index].split.queue_free()
    tiles.remove_at(index)

## Keeps the area in step with what the character holds (host results arrive by snapshot).
func refresh() -> void:
    _rebuild_list()
    var held: Array = _held()
    if not _pending.is_empty():
        var done: bool = (_pending.has("result") and _pending.result in held) or (_pending.has("split") and not _pending.split in held and _pending.parts.all(func(part): return part in held))
        if done:
            for index in range(tiles.size() - 1, -1, -1):
                if tiles[index].id in _pending.parts or tiles[index].id == _pending.get("split", ""):
                    _remove_tile(index)
            if _pending.has("result"):
                _add_tile(_pending.result, _pending.position)
                _detail.text = "Fused: %s (%s). Both skills were replaced; Split gives them back." % [_skill(_pending.result).display_name, _skill(_pending.result).tier]
            else:
                _add_tile(_pending.parts[0], _pending.position)
                _add_tile(_pending.parts[1], (_pending.position + Vector2(TILE.x + 10, 0)).clamp(Vector2(4, 4), AREA.size - TILE - Vector2(4, 24)))
                _detail.text = "Split back into %s." % " + ".join(_pending.parts.map(func(part): return _skill(part).display_name))
            _pending = {}
    for index in range(tiles.size() - 1, -1, -1):
        if not tiles[index].id in held and not tiles[index].id in _pending.get("parts", []):
            _remove_tile(index)
    _layout_tiles()

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
    _detail.text = "Drag a skill from the right into the fusion area, then drag another skill onto it."
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
