extends CanvasLayer
@onready var session: Node = get_node("/root/GameSession")
## The in-game HUD after the user's reference (step 21): a status card (portrait, HP/Magicule/XP
## bars, level), the region title and System line, the cyan analysis box, the skill hotbar with key
## badges, the event log, and the bag. Every value is the local character's live state.

const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
const SKILL_EFFECTS := preload("res://scripts/skills/skill_effects.gd")
var _hp_bar: ProgressBar
var _xp_bar: ProgressBar
var _portrait: TextureRect
var _portrait_id: String = ""
var _name: Label
## Round minimap (24a) and the respawn countdown shown while defeated.
var minimap: Control
var _respawn_label: Label
var _respawn_left: float = 0.0
var _slots: Array[Button] = []
## Skill tree window (K), see skill_tree_panel.gd.
var skill_tree: Control
## Skill fusion window (U), see fusion_panel.gd.
var fusion: Control
## Equipment window (from the bag), see gear_panel.gd.
var gear_panel: Control
## World map (M), see world_map_panel.gd.
var world_map: Control
const WORLD_MAP := preload("res://scripts/world/world_map.gd")
var _modal: Control
var _items: ItemList
var _details: Label
var _capacity: Label
var _discard: Button
## Use a consumable or read a scroll from the bag (M4.5c).
var _use: Button
## Shop and ferry window (M4.5c), see trade_panel.gd.
var trade_panel: Control
## Harbour window: map travel, tickets, passes, ships (M4.5d), see harbour_panel.gd.
var harbour_panel: Control
var _zeni: Label
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
    UI.install(get_tree())
    _build_status()
    _recovery = _label("", Vector2(8, 86), Vector2(300, 14), self, 9)
    _outline(_recovery)
    _trial_back = ColorRect.new()
    _trial_back.position = Vector2(234, 42)
    _trial_back.size = Vector2(206, 20)
    _trial_back.color = Color(0.25, 0.18, 0.05, 0.85)
    _trial_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_trial_back)
    _trial_label = _label("", Vector2(240, 45), Vector2(196, 16), self, 9)
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
    world_map = load("res://scripts/ui/world_map_panel.gd").new(self)
    add_child(world_map)
    trade_panel = load("res://scripts/ui/trade_panel.gd").new(self)
    add_child(trade_panel)
    harbour_panel = load("res://scripts/ui/harbour_panel.gd").new(self)
    add_child(harbour_panel)
    _hook_pause_returns()
    get_parent().system_message.connect(fusion.show_message)
    _ally_dialog = load("res://scripts/ui/ally_dialog.gd").new()
    add_child(_ally_dialog)
    _camp_dialog = load("res://scripts/ui/camp_dialog.gd").new()
    add_child(_camp_dialog)

func menu_open() -> bool:
    return (is_instance_valid(_camp_dialog) and _camp_dialog.visible) or _modal.visible or _pause_panel.visible or (is_instance_valid(_ally_dialog) and _ally_dialog.visible) or (is_instance_valid(skill_tree) and skill_tree.visible) or (is_instance_valid(fusion) and fusion.visible) or (is_instance_valid(gear_panel) and gear_panel.visible) or (is_instance_valid(world_map) and world_map.visible) or (is_instance_valid(trade_panel) and trade_panel.visible) or (is_instance_valid(harbour_panel) and harbour_panel.visible)

func bind_player(actor: Node2D) -> void:
    if player == actor:
        return
    if is_instance_valid(inventory) and inventory.changed.is_connected(_refresh_inventory):
        inventory.changed.disconnect(_refresh_inventory)
    player = actor
    inventory = actor.get_node("Inventory")
    inventory.changed.connect(_refresh_inventory)
    _refresh_inventory()

## Window frames are ornamented (step 22); other kinds are the plain boxes of ui_style.
func _panel_style(kind: String = "frame") -> StyleBox:
    return UI.ornate() if kind == "frame" else UI.box(kind)

## A framed panel drawn behind the scene's HUD nodes (they come first in the scene).
func _backdrop(rect: Rect2, kind: String = "frame") -> Panel:
    var back := Panel.new()
    back.position = rect.position
    back.size = rect.size
    back.add_theme_stylebox_override("panel", UI.ornate("hud") if kind == "frame" else UI.ornate("assistant") if kind == "assistant" else UI.box(kind))
    back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(back)
    move_child(back, 0)
    return back

## Dark outline so text stays readable straight over the world.
func _outline(label: Label) -> void:
    label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05))
    label.add_theme_constant_override("outline_size", 3)

func _bar(rect: Rect2, color: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    # Style first: with the percentage text on, the bar's minimum height is the font's.
    UI.style_bar(bar, color)
    bar.position = rect.position
    bar.size = rect.size
    add_child(bar)
    return bar

## Top-left status card: portrait, race/form, HP, Magicules, XP and level (scene labels reused).
func _build_status() -> void:
    $TopBar.hide()
    $BottomBar.color = Color(0.03, 0.04, 0.06, 0.85)
    _backdrop(Rect2(4, 4, 226, 66))
    var well := Panel.new()
    well.position = Vector2(9, 10)
    well.size = Vector2(42, 42)
    well.add_theme_stylebox_override("panel", UI.box("well"))
    well.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(well)
    _portrait = TextureRect.new()
    _portrait.position = Vector2(14, 13)
    _portrait.size = Vector2(32, 32)
    _portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_portrait)
    _name = UI.heading(_label("", Vector2(56, 6), Vector2(168, 14), self, 10))
    _hp_bar = _bar(Rect2(56, 21, 168, 11), UI.HP)
    UI.style_bar($MagiculeBar, UI.MAGICULES)
    $MagiculeBar.position = Vector2(56, 34)
    $MagiculeBar.size = Vector2(168, 11)
    _xp_bar = _bar(Rect2(56, 47, 168, 5), UI.XP)
    for entry in [[$Health, 20], [$Magicules, 33]]:
        var label: Label = entry[0]
        label.position = Vector2(56, entry[1])
        label.size = Vector2(168, 13)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 9)
        label.add_theme_color_override("font_color", UI.TEXT)
        # Over its bar (later siblings draw on top), but still below every window built after.
        move_child(label, -1)
        _outline(label)
    _level = _label("", Vector2(56, 53), Vector2(168, 14), self, 9)
    _level.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _zeni = _label("", Vector2(8, 86), Vector2(220, 12), self, 9)
    _zeni.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _outline(_zeni)
    $StrikeCost.position = Vector2(8, 72)
    $StrikeCost.add_theme_font_size_override("font_size", 9)
    _outline($StrikeCost)
    # Region title and the System line, top right.
    $Title.text = "THE FIRST CLEARING"
    $Title.set_meta("region", -1)
    $Title.position = Vector2(300, 4)
    $Title.size = Vector2(334, 16)
    $Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    $Title.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _outline($Title)
    $SystemVoice.position = Vector2(234, 20)
    $SystemVoice.size = Vector2(312, 14)
    $SystemVoice.clip_text = true
    $SystemVoice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    $SystemVoice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    $SystemVoice.add_theme_font_size_override("font_size", 9)
    $SystemVoice.add_theme_color_override("font_color", UI.CYAN)
    _outline($SystemVoice)
    # Analysis: the cyan box on the right.
    _backdrop(Rect2(446, 118, 190, 82), "assistant")
    $Analysis.position = Vector2(452, 122)
    $Analysis.size = Vector2(178, 60)
    $Analysis.add_theme_font_size_override("font_size", 10)
    UI.style_bar($AnalysisProgress, UI.CYAN)
    $AnalysisProgress.position = Vector2(452, 186)
    # Minimap under the region name, top right (24a).
    minimap = load("res://scripts/ui/minimap.gd").new(self)
    minimap.position = Vector2(552, 28)
    add_child(minimap)
    var ring: Control = minimap.get_meta("ring")
    ring.position = minimap.position
    add_child(ring)
    _respawn_label = _label("", Vector2(120, 150), Vector2(400, 40), self, 16)
    _respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _respawn_label.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _outline(_respawn_label)
    _respawn_label.hide()
    $AnalysisProgress.size = Vector2(178, 7)

## While defeated in a hosted world: "Respawning in N" (the host respawns after RESPAWN_DELAY;
## clients count down locally from the moment they see the defeat).
func _refresh_respawn(delta: float) -> void:
    var defeated: bool = player.get_node("Health").current <= 0 and session.active
    if defeated and not _respawn_label.visible:
        _respawn_left = player.RESPAWN_DELAY
    _respawn_label.visible = defeated
    if defeated:
        _respawn_left = maxf(0.0, _respawn_left - delta)
        _respawn_label.text = "DEFEATED\nRespawning in %d…" % int(ceil(_respawn_left))

func _cost_text() -> String:
    var cost: float = player.get_node("MeleeAttack").strike_cost()
    return "free" if cost <= 0.0 else "%d Magicules" % int(cost)

## Live status-card values that have no signal of their own.
func _refresh_status() -> void:
    var health: Node = player.get_node("Health")
    _hp_bar.max_value = health.maximum
    _hp_bar.value = health.current
    var level: int = int(player.progression.get("level", 1))
    var floor_xp: int = LEVELING.xp_for_level(level)
    var next_xp: int = LEVELING.xp_for_level(level + 1) if level < LEVELING.LEVEL_CAP else floor_xp + 1
    _xp_bar.max_value = maxi(1, next_xp - floor_xp)
    _xp_bar.value = _xp_bar.max_value if level >= LEVELING.LEVEL_CAP else clampi(int(player.progression.get("experience", 0)) - floor_xp, 0, next_xp - floor_xp)
    var mimic: bool = player.form != player.FORMS.BASE
    _name.text = "%s%s" % [player.race(), " · %s form" % player.FORMS.FORMS[player.form].name if mimic else ""]
    var body: String = player._body_id()
    if body != _portrait_id:
        _portrait_id = body
        var frames: SpriteFrames = SPRITES.frames(body)
        _portrait.texture = frames.get_frame_texture("idle_down" if frames.has_animation("idle_down") else "idle", 0)
    _portrait.modulate = player.MIMIC_TINT if mimic else Color.WHITE

func _button(text: String, position: Vector2, size: Vector2, parent: Node) -> Button:
    var button := Button.new()
    button.text = text
    button.position = position
    button.size = size
    button.add_theme_font_size_override("font_size", 10)
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
    _backdrop(Rect2(176, 294, 304, 46))
    for index in range(4):
        var button := _button("Empty", Vector2(182 + index * 74, 302), Vector2(70, 34), self)
        button.add_theme_font_size_override("font_size", 8)
        button.focus_mode = Control.FOCUS_NONE
        button.clip_text = true
        button.pressed.connect(_activate_slot.bind(index))
        _slots.append(button)
        # Key badge above the slot, like the reference.
        var badge := Label.new()
        badge.text = str(index + 1)
        badge.position = Vector2(182 + index * 74 + 29, 288)
        badge.size = Vector2(12, 12)
        badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        badge.add_theme_font_size_override("font_size", 8)
        badge.add_theme_color_override("font_color", UI.GOLD_LIGHT)
        var badge_box := UI.box("slot")
        badge_box.set_content_margin_all(0)
        badge.add_theme_stylebox_override("normal", badge_box)
        badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(badge)
    _backdrop(Rect2(4, 266, 166, 72))
    _log = RichTextLabel.new()
    _log.position = Vector2(9, 270)
    _log.size = Vector2(158, 66)
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
    var potion_wait: float = player.consumable_cooldown if "consumable_cooldown" in player else 0.0
    var extras := ""
    if potion_wait > 0.0:
        extras += " · potions in %.0f s" % ceilf(potion_wait)
    if not player.riding().is_empty():
        extras += " · riding (H)"
    if player.fishing_bite_in != -INF:
        extras += " · BITE! press F" if player.fishing_bite_in <= 0.0 else " · fishing…"
    _zeni.text = "%d Zeni%s" % [player.zeni(), extras]
    # Region name of where this character stands (M4.5a).
    # The town or village you are in, else the region (M4.5c).
    var place: String = WORLD_MAP.place_name(player.global_position)
    if $Title.get_meta("place", "") != place:
        $Title.set_meta("place", place)
        $Title.text = place.to_upper()
    _refresh_status()
    _refresh_respawn(_delta)
    var trial: Dictionary = get_parent().trial.state if get_parent().get("trial") != null else {}
    _trial_back.visible = trial.get("active", false)
    _trial_label.visible = _trial_back.visible
    if _trial_back.visible:
        _trial_label.text = "%s · %d left · %.0fs%s" % [get_parent().trial.DISPLAY_NAME, trial.remaining, trial.time_left, "" if trial.owner == player.character_id else " (another player)"]
    var shape: Dictionary = player.FORMS.FORMS[player.form]
    var weapon: Dictionary = player.equipped_weapon()
    if not weapon.is_empty():
        $StrikeCost.text = "%s: %d dmg, %s · %s" % [GEAR.WEAPONS[GEAR.BASES[weapon.base].weapon].name, int(weapon.stats.damage), _cost_text(), GEAR.WEAPONS[GEAR.BASES[weapon.base].weapon].text]
    elif player.can_mimic():
        $StrikeCost.text = "Strike: %d dmg, %s · Form: %s%s" % [int(player.race_stats().strike_damage), _cost_text(), shape.name, " (%.1fs)" % player.form_cooldown if player.form_cooldown > 0.0 else " · T: mimic"]
    else:
        $StrikeCost.text = "Strike: %d dmg, %s · %s: %s" % [int(player.race_stats().strike_damage), _cost_text(), player.race(), player.race_stats().ability.get_slice(":", 0).to_lower()]
    _recovery.text = "Recovering: %.1fs · need %.0f Magicules" % [player.exhaustion_left, player.get_node("Magicules").maximum * 0.25]
    for index in range(_slots.size()):
        var skill: Resource = player.get_node("SkillBook").skill_at_slot(index)
        var button := _slots[index]
        if skill == null:
            button.text = "Empty"
            button.disabled = true
            continue
        var cooldown: float = player.get_node("MeleeAttack").cooldown_left
        button.text = "%s\n%s" % [skill.display_name, "%.1fs" % cooldown if cooldown > 0.0 else "%.0f Magicules" % skill.magicule_cost]
        var effect_text: String = SKILL_EFFECTS.describe(String(skill.id))
        button.tooltip_text = "%s · %s\n%d damage · %.1fs cooldown%s" % [skill.tier, skill.display_name, skill.damage, skill.cooldown, "\n" + effect_text.left(1).to_upper() + effect_text.substr(1) if effect_text != "" else ""]
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
    UI.heading(_label("DIMENSIONAL STORAGE", o + Vector2(12, 8), Vector2(240, 20), _modal, 14))
    _capacity = _label("", o + Vector2(14, 34), Vector2(190, 16), _modal, 10)
    UI.heading(_label("MATERIAL DETAILS", o + Vector2(228, 36), Vector2(188, 16), _modal, 10))
    _items = ItemList.new()
    _items.position = o + Vector2(14, 56)
    _items.size = Vector2(198, 122)
    _items.add_theme_font_size_override("font_size", 12)
    _items.item_selected.connect(_select_item)
    _modal.add_child(_items)
    _details = _label("", o + Vector2(228, 58), Vector2(192, 115), _modal)
    _discard = _button("Discard 1", o + Vector2(228, 186), Vector2(96, 30), _modal)
    _use = _button("Use", o + Vector2(330, 186), Vector2(96, 30), _modal)
    _use.pressed.connect(func():
        session.request_action("use_item", {"id": String(_selection)})
        get_tree().create_timer(0.15, true).timeout.connect(_refresh_inventory)
    )
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
        _items.add_item("%s ×%d" % [_entries[index].name, _entries[index].count], UI.icon(String(_entries[index].id)))
        if _entries[index].id == _selection:
            selected = index
    if _entries.is_empty():
        _selection = &""
        _details.text = "No materials stored.\n\nAbsorb and analyze a defeated creature to retain its essence."
        _discard.disabled = true
        _use.disabled = true
    else:
        _items.select(selected)
        _select_item(selected)

func _select_item(index: int) -> void:
    var entry: Dictionary = _entries[index]
    _selection = entry.id
    _details.text = "%s\n%s · ×%d\n\n%s" % [entry.name, entry.category, entry.count, entry.description]
    _discard.disabled = false
    _use.disabled = not preload("res://scripts/trade/trade_catalogue.gd").is_good(String(entry.id))
    _use.text = "Read" if String(entry.id).begins_with("scroll_") else "Use"

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
    if world_map.visible and (event.is_action_pressed("ui_cancel") or (event.is_action_pressed("world_map") and not event.is_echo())):
        world_map.close()
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("world_map") and not event.is_echo() and not menu_open():
        world_map.open()
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
    if is_instance_valid(world_map) and world_map.visible:
        get_tree().paused = world_map._paused_before_open

var _pause_panel: Panel
var _pause_status: Label
var _pause_buttons: Dictionary = {}
var _pause_blocking: bool = false
var _paused_before_pause: bool = false
var _pause_menu: Panel
var _pause_options: Panel
var _pause_card: Dictionary = {}
## A window opened from the pause menu returns to it when closed.
var _back_to_pause: bool = false
const SETTINGS := preload("res://scripts/ui/settings.gd")
const MARKER := preload("res://scripts/ui/menu_marker.gd")
const LAYOUT := preload("res://scripts/world/world_layout.gd")

## Pause overlay after the user's reference (step 22): dimmed world, GAME PAUSED banner, the menu
## with the slime marker, a character/world card, Options, and shortcuts into the bag, skill tree
## and fusion window (closing those returns here).
func _build_pause_panel() -> void:
    _pause_panel = Panel.new()
    _pause_panel.name = "PausePanel"
    _pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var dim := StyleBoxFlat.new()
    dim.bg_color = Color(0.02, 0.02, 0.05, 0.8)
    _pause_panel.add_theme_stylebox_override("panel", dim)
    add_child(_pause_panel)
    var banner := Panel.new()
    banner.position = Vector2(200, 12)
    banner.size = Vector2(240, 40)
    banner.add_theme_stylebox_override("panel", UI.ornate("banner"))
    _pause_panel.add_child(banner)
    var title := UI.heading(_label("GAME PAUSED", Vector2(0, 6), Vector2(240, 28), banner, 22))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _pause_menu = Panel.new()
    _pause_menu.position = Vector2(206, 62)
    _pause_menu.size = Vector2(228, 240)
    _pause_menu.add_theme_stylebox_override("panel", UI.ornate())
    _pause_panel.add_child(_pause_menu)
    var entries := [["resume", "RESUME"], ["bag", "INVENTORY & EQUIPMENT"], ["tree", "SKILL TREE"], ["fusion", "SKILL FUSION"], ["map", "WORLD MAP"], ["open", "OPEN TO FRIENDS"], ["save", "SAVE WORLD"], ["options", "OPTIONS"], ["quit", "SAVE & QUIT TO TITLE"]]
    for index in range(entries.size()):
        var button := _button(entries[index][1], Vector2(10, 8 + index * 25), Vector2(208, 24), _pause_menu)
        UI.menu_entry(button)
        _pause_buttons[entries[index][0]] = button
    _pause_panel.add_child(MARKER.new(_pause_buttons.values()))
    _pause_buttons.resume.pressed.connect(close_pause)
    _pause_buttons.bag.pressed.connect(_from_pause.bind(open_inventory))
    _pause_buttons.tree.pressed.connect(_from_pause.bind(func(): skill_tree.open()))
    _pause_buttons.fusion.pressed.connect(_from_pause.bind(func(): fusion.open()))
    _pause_buttons.map.pressed.connect(_from_pause.bind(func(): world_map.open()))
    _pause_buttons.open.pressed.connect(func(): session.open_to_friends(); _refresh_pause())
    _pause_buttons.save.pressed.connect(func():
        var result: Error = session.save_world()
        get_parent()._announce("World saved." if result == OK else "Saving failed; the previous save is retained.")
    )
    _pause_buttons.options.pressed.connect(func():
        _pause_menu.hide()
        _pause_options.show()
        _pause_options.get_meta("first").grab_focus()
    )
    _pause_buttons.quit.pressed.connect(func():
        session.quit_to_title()
    )
    _pause_options = Panel.new()
    _pause_options.position = Vector2(170, 62)
    _pause_options.size = Vector2(300, 228)
    _pause_options.add_theme_stylebox_override("panel", UI.ornate())
    _pause_panel.add_child(_pause_options)
    _pause_options.set_meta("first", SETTINGS.build(_pause_options, _close_options))
    _pause_options.hide()
    _build_pause_card()
    _pause_status = _label("", Vector2(448, 240), Vector2(186, 90), _pause_panel, 9)
    _outline(_pause_status)
    var hint := _label("Esc: resume · Enter: choose · Arrow keys: move", Vector2(0, 342), Vector2(634, 14), _pause_panel, 9)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    hint.add_theme_color_override("font_color", UI.TEXT_DIM)
    _pause_panel.hide()

## Windows opened from the pause menu bring it back when they close (called once they exist).
func _hook_pause_returns() -> void:
    for window in [_modal, skill_tree, fusion, gear_panel, world_map]:
        window.visibility_changed.connect(func():
            if not window.visible and _back_to_pause:
                _return_to_pause.call_deferred()
        )

## Right-hand card: who you are and where (all live values; nothing invented).
func _build_pause_card() -> void:
    var card := Panel.new()
    card.position = Vector2(446, 62)
    card.size = Vector2(188, 172)
    card.add_theme_stylebox_override("panel", UI.ornate())
    _pause_panel.add_child(card)
    var well := Panel.new()
    well.position = Vector2(8, 8)
    well.size = Vector2(38, 38)
    well.add_theme_stylebox_override("panel", UI.box("well"))
    card.add_child(well)
    var portrait := TextureRect.new()
    portrait.position = Vector2(11, 11)
    portrait.size = Vector2(32, 32)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    card.add_child(portrait)
    _pause_card.portrait = portrait
    _pause_card.name = UI.heading(_label("", Vector2(52, 6), Vector2(130, 14), card, 11))
    _pause_card.level = _label("", Vector2(52, 20), Vector2(130, 14), card, 9)
    for entry in [["hp", 50, UI.HP], ["mag", 64, UI.MAGICULES]]:
        var bar := ProgressBar.new()
        UI.style_bar(bar, entry[2])
        bar.position = Vector2(8, entry[1])
        bar.size = Vector2(172, 11)
        card.add_child(bar)
        _pause_card[entry[0]] = bar
        var text := _label("", Vector2(8, entry[1] - 1), Vector2(172, 13), card, 9)
        text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _outline(text)
        _pause_card[entry[0] + "_text"] = text
    var rows := ["zone", "world", "map", "players", "time"]
    for index in range(rows.size()):
        var key := _label("", Vector2(8, 84 + index * 16), Vector2(70, 14), card, 9)
        key.add_theme_color_override("font_color", UI.GOLD_LIGHT)
        var value := _label("", Vector2(70, 84 + index * 16), Vector2(110, 14), card, 9)
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        value.clip_text = true
        value.autowrap_mode = TextServer.AUTOWRAP_OFF
        _pause_card[rows[index]] = [key, value]

## Open a window from the pause menu; closing it comes back to the pause menu.
func _from_pause(open_window: Callable) -> void:
    close_pause()
    open_window.call()
    _back_to_pause = menu_open()

func _return_to_pause() -> void:
    if menu_open() or not _back_to_pause:
        return
    _back_to_pause = false
    open_pause()

func _close_options() -> void:
    _pause_options.hide()
    _pause_menu.show()
    _pause_buttons.options.grab_focus()

static func play_time_text(seconds: float) -> String:
    var minutes := int(seconds) / 60
    return "%dh %02dm" % [minutes / 60, minutes % 60]

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
    _pause_options.hide()
    _pause_menu.show()
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
    _pause_buttons.open.text = "OPEN TO FRIENDS" if not session.listening else "OPEN TO FRIENDS (ON)"
    _pause_buttons.save.disabled = not hosting
    _pause_buttons.quit.text = "LEAVE TO TITLE" if session.replica_world else "SAVE & QUIT TO TITLE" if hosting else "QUIT TO TITLE"
    # Character and world card.
    var health: Node = player.get_node("Health")
    var magicules: Node = player.get_node("Magicules")
    _pause_card.portrait.texture = _portrait.texture
    _pause_card.portrait.modulate = _portrait.modulate
    _pause_card.name.text = _name.text
    _pause_card.level.text = level_text(player.progression)
    _pause_card.hp.max_value = health.maximum
    _pause_card.hp.value = health.current
    _pause_card.hp_text.text = "HP %d / %d" % [health.current, health.maximum]
    _pause_card.mag.max_value = magicules.maximum
    _pause_card.mag.value = magicules.current
    _pause_card.mag_text.text = "Magicules %.0f / %.0f" % [magicules.current, magicules.maximum]
    var world_time: float = float(get_parent().progression.get("world_time", 0.0))
    var values := {
        "zone": ["ZONE", WORLD_MAP.region_name(player.global_position)],
        "world": ["WORLD", session.world_meta.get("name", "Sandbox") if session.active else "Offline sandbox"],
        "map": ["MAP", LAYOUT.describe(session.world_meta) if session.active else "original map"],
        "players": ["PLAYERS", "%d / 8" % maxi(1, session.owners.size()) if session.active else "1 (offline)"],
        "time": ["WORLD TIME", play_time_text(world_time) if not session.replica_world else "on the host"],
    }
    for key in values:
        _pause_card[key][0].text = values[key][0]
        _pause_card[key][1].text = values[key][1]
