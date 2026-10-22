extends Control
## The owner's mod menu (F10; dev build or editor only, host only): boosts (super speed, XP,
## loot, Zeni, god mode), quick gifts (Zeni, levels, skill points, healing) and every item in the
## game to give yourself: all gear bases at any rarity, and every bag good and material.
const DEV := preload("res://scripts/dev/dev_tools.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const FRAME := Rect2(16, 8, 608, 344)
const KINDS := ["All gear", "dagger", "sword", "bow", "spear", "scythe", "head", "body", "hands", "feet", "accessory", "Bag goods"]

var hud: CanvasLayer
var _toggles: Dictionary = {}
var _kind: OptionButton
var _rarity: OptionButton
var _search: LineEdit
var _list: ItemList
var _ids: Array = []
var _amount: SpinBox
var _status: Label

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "DevPanel"
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.85)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var frame := Panel.new()
    frame.position = FRAME.position
    frame.size = FRAME.size
    frame.add_theme_stylebox_override("panel", UI.ornate("panel", Color("ff4d6d")))
    add_child(frame)
    var title: Label = UI.heading(hud._label("MOD MENU (owner only)", FRAME.position + Vector2(14, 10), Vector2(300, 20), self, 13))
    title.add_theme_color_override("font_color", Color("ff8aa0"))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    close.pressed.connect(close_panel)
    # Boosts.
    var y := 40.0
    for entry in [["speed", "Super speed (×3)"], ["xp", "Super XP (×10)"], ["loot", "Super loot (every kill drops, mostly Epic+)"], ["zeni", "Super Zeni (×10)"], ["god", "God mode (no damage)"], ["free_gear", "Wear anything (no level/class/attribute needs)"]]:
        var check := CheckButton.new()
        check.text = entry[1]
        check.position = FRAME.position + Vector2(14, y)
        check.size = Vector2(250, 22)
        check.add_theme_font_size_override("font_size", 9)
        var key: String = entry[0]
        check.toggled.connect(func(on: bool): DEV.set_flag(key, on))
        add_child(check)
        _toggles[key] = check
        y += 24.0
    # Quick gifts.
    y += 6.0
    var gift_index := 0
    for entry in [["+10,000 Zeni", "zeni"], ["+1 level", "level"], ["+5 skill points", "points"], ["Full heal", "heal"], ["Max level", "max"], ["Every Mythic weapon", "mythics"]]:
        # Two columns, so everything fits above the status line.
        var column: int = gift_index % 2
        var button: Button = hud._button(entry[0], FRAME.position + Vector2(14 + column * 128, y), Vector2(122, 22), self)
        button.add_theme_font_size_override("font_size", 9)
        button.pressed.connect(_gift.bind(entry[1]))
        gift_index += 1
        if column == 1:
            y += 25.0
    _status = hud._label("", FRAME.position + Vector2(14, FRAME.size.y - 40), Vector2(250, 30), self, 8)
    _status.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    # Item browser.
    UI.heading(hud._label("GIVE YOURSELF ITEMS", FRAME.position + Vector2(280, 40), Vector2(200, 14), self, 9))
    _kind = OptionButton.new()
    _kind.position = FRAME.position + Vector2(280, 56)
    _kind.size = Vector2(110, 22)
    for kind in KINDS:
        _kind.add_item(kind)
    _kind.item_selected.connect(func(_i): _refresh_list())
    add_child(_kind)
    _rarity = OptionButton.new()
    _rarity.position = FRAME.position + Vector2(396, 56)
    _rarity.size = Vector2(100, 22)
    for name in GEAR.RARITIES:
        _rarity.add_item(name)
    _rarity.select(GEAR.RARITIES.size() - 1)
    add_child(_rarity)
    _search = LineEdit.new()
    _search.position = FRAME.position + Vector2(502, 56)
    _search.size = Vector2(92, 22)
    _search.placeholder_text = "search"
    _search.add_theme_font_size_override("font_size", 9)
    _search.text_changed.connect(func(_t): _refresh_list())
    add_child(_search)
    _list = ItemList.new()
    _list.position = FRAME.position + Vector2(280, 82)
    _list.size = Vector2(314, 214)
    _list.add_theme_font_size_override("font_size", 9)
    _list.fixed_icon_size = Vector2i(16, 16)
    _list.item_activated.connect(func(_i): _give())
    add_child(_list)
    _amount = SpinBox.new()
    _amount.position = FRAME.position + Vector2(280, 302)
    _amount.size = Vector2(100, 22)
    _amount.min_value = 1
    _amount.max_value = 99
    _amount.value = 1
    add_child(_amount)
    var give: Button = hud._button("Give (or double-click)", FRAME.position + Vector2(388, 302), Vector2(206, 22), self)
    give.add_theme_font_size_override("font_size", 9)
    give.pressed.connect(_give)
    hud._label("F10 / Esc: close · boosts last until the game restarts · only in worlds you host", FRAME.position + Vector2(14, FRAME.size.y - 20), Vector2(FRAME.size.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func is_open() -> bool:
    return visible

static func goods() -> Array:
    var all: Array = preload("res://scripts/skills/skill_catalogue.gd").MATERIALS.keys() + TRADE.CONSUMABLES.keys()
    var upgrades := preload("res://scripts/items/upgrade_catalogue.gd")
    all += upgrades.RUNES.keys() + upgrades.AUGMENTS.keys() + preload("res://scripts/travel/travel_catalogue.gd").FISH.keys()
    for skill in TRADE.COMMON_SCROLLS + TRADE.RARE_SCROLLS:
        all.append(TRADE.scroll_id(skill))
    var realm := preload("res://scripts/realm/realm_catalogue.gd")
    for index in range(realm.ORB_COUNT):
        all.append(realm.orb_id(index))
    return all

static func good_name(id: String) -> String:
    if TRADE.is_good(id):
        return TRADE.good_info(id)[0]
    var catalogue := preload("res://scripts/skills/skill_catalogue.gd")
    return load(catalogue.SPECIMENS[catalogue.MATERIALS[id]]).material_name if catalogue.MATERIALS.has(id) else id

func _refresh_list() -> void:
    _list.clear()
    _ids.clear()
    var kind: String = KINDS[_kind.selected]
    var query := _search.text.strip_edges().to_lower()
    if kind == "Bag goods":
        for id in goods():
            var name := good_name(id)
            if query.is_empty() or name.to_lower().contains(query):
                _list.add_item(name)
                _ids.append(id)
        return
    var ids: Array = GEAR.BASES.keys()
    ids.sort_custom(func(a, b): return int(GEAR.BASES[a].get("level", 1)) < int(GEAR.BASES[b].get("level", 1)))
    for id in ids:
        var spec: Dictionary = GEAR.BASES[id]
        var type: String = spec.get("weapon", spec.slot)
        if kind != "All gear" and type != kind:
            continue
        if not query.is_empty() and not String(spec.name).to_lower().contains(query):
            continue
        var tag := ""
        if spec.has("unique"):
            tag = " ★ unique"
        elif spec.has("set"):
            tag = " · set"
        _list.add_item("%s (Lv %d%s%s)" % [spec.name, int(spec.get("level", 1)), ", " + String(spec.element) if not String(spec.get("element", "")).is_empty() else "", tag], GEAR.icon_texture(id, _rarity.selected))
        _ids.append(id)
        if _list.item_count >= 400:
            break

func _player() -> Node:
    return hud.player

func _give() -> void:
    var selected := _list.get_selected_items()
    if selected.is_empty() or not DEV.applies(_player()):
        return
    var id: String = _ids[selected[0]]
    var player := _player()
    if KINDS[_kind.selected] == "Bag goods":
        var added: int = player.get_node("Inventory").add_material(id, int(_amount.value))
        _status.text = "Added %d × %s." % [added, good_name(id)] if added > 0 else "No room in the bag (20 units)."
        return
    var rarity: int = maxi(_rarity.selected, int(GEAR.BASES[id].get("min_rarity", 0)))
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var given := 0
    for _i in range(int(_amount.value)):
        if player.gear.items.size() >= GEAR.MAX_ITEMS:
            break
        player.add_item(GEAR.roll(id, rarity, rng))
        given += 1
    _status.text = "Gave %d × %s %s." % [given, GEAR.RARITIES[rarity], GEAR.BASES[id].name] if given > 0 else "Gear bag full (%d items)." % GEAR.MAX_ITEMS

func _gift(kind: String) -> void:
    var player := _player()
    if not DEV.applies(player):
        return
    var leveling := preload("res://scripts/progression/leveling.gd")
    match kind:
        "zeni":
            player.gain_zeni(10000, "mod menu")
        "level":
            leveling.grant(player, leveling.xp_for_level(mini(leveling.LEVEL_CAP, int(player.progression.level) + 1)) - int(player.progression.experience))
        "max":
            leveling.grant(player, leveling.max_experience() - int(player.progression.experience))
        "points":
            # Points beyond the level go through the wish bonus (the saves check points per level).
            var extra: int = mini(5, 30 - int(player.progression.get("bonus_points", 0)))
            player.progression["bonus_points"] = int(player.progression.get("bonus_points", 0)) + extra
            player.progression["skill_points"] = int(player.progression.skill_points) + extra
        "mythics":
            var result: Array = DEV.give_mythics(player)
            _status.text = "%d Mythic weapons in the bag, %d at your feet." % [result[0], result[1]]
            hud.session.queue_save()
            return
        "heal":
            player.get_node("Health").heal(player.get_node("Health").maximum)
            player.get_node("Magicules").restore(player.get_node("Magicules").maximum)
    _status.text = "Done: %s." % kind
    hud.session.queue_save()

func open() -> void:
    if hud.menu_open() or not DEV.applies(_player()):
        return
    for key in _toggles:
        _toggles[key].set_pressed_no_signal(DEV.flag(key))
    _refresh_list()
    show()

func close_panel() -> void:
    if visible:
        hide()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
        if visible:
            close_panel()
        else:
            open()
        get_viewport().set_input_as_handled()
    elif visible and event.is_action_pressed("ui_cancel"):
        close_panel()
        get_viewport().set_input_as_handled()
