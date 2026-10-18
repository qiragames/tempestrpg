extends Control
## The guild hall window (M14b): F at a Guild Hall in your settlement. Left your bag and unworn
## gear (click to deposit), right the guild bank (click to take — officers and the leader, or every
## member when the leader allows it); Zeni in and out; the guild's level, perks and this week's
## three guild quests. Shift-click moves a whole stack. Only operations go to the host ("guild").
const UI := preload("res://scripts/ui/ui_style.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const GUILDS := preload("res://scripts/guilds/world_guilds.gd")
const FRAME := Rect2(24, 10, 592, 340)
const COLUMN := 180.0

var hud: CanvasLayer
var _title: Label
var _summary: Label
var _mine: VBoxContainer
var _bank: VBoxContainer
var _week: VBoxContainer
var _zeni_amount: SpinBox
var _rule: Button
var _signature := ""
var _paused_before := false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "GuildHallPanel"
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
    _title = UI.heading(hud._label("GUILD HALL", FRAME.position + Vector2(14, 10), Vector2(360, 20), self, 14))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    close.pressed.connect(close_panel)
    _summary = hud._label("", FRAME.position + Vector2(14, 34), Vector2(FRAME.size.x - 28, 14), self, 9)
    _summary.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    var lists: Array = []
    var titles := ["Your bag and gear (click to deposit)", "Guild bank (click to take)", "Level, perks and this week"]
    for index in range(3):
        var x: float = FRAME.position.x + 14 + index * (COLUMN + 10)
        hud._label(titles[index], Vector2(x, FRAME.position.y + 52), Vector2(COLUMN, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
        var scroll := ScrollContainer.new()
        scroll.position = Vector2(x, FRAME.position.y + 68)
        scroll.size = Vector2(COLUMN, FRAME.size.y - (124 if index < 2 else 96))
        add_child(scroll)
        var list := VBoxContainer.new()
        list.custom_minimum_size = Vector2(COLUMN - 14, 0)
        list.add_theme_constant_override("separation", 2)
        scroll.add_child(list)
        lists.append(list)
    _mine = lists[0]
    _bank = lists[1]
    _week = lists[2]
    # Zeni and the withdraw rule.
    var row_y: float = FRAME.position.y + FRAME.size.y - 52
    _zeni_amount = SpinBox.new()
    _zeni_amount.position = Vector2(FRAME.position.x + 14, row_y)
    _zeni_amount.size = Vector2(110, 20)
    _zeni_amount.min_value = 1
    _zeni_amount.max_value = 1000000
    _zeni_amount.value = 100
    _zeni_amount.add_theme_font_size_override("font_size", 8)
    add_child(_zeni_amount)
    var deposit: Button = hud._button("Deposit Zeni", Vector2(FRAME.position.x + 130, row_y), Vector2(96, 20), self)
    deposit.add_theme_font_size_override("font_size", 8)
    deposit.pressed.connect(func(): _send({"operation": "zeni", "id": "", "count": int(_zeni_amount.value)}))
    var take: Button = hud._button("Take Zeni", Vector2(FRAME.position.x + 232, row_y), Vector2(96, 20), self)
    take.add_theme_font_size_override("font_size", 8)
    take.pressed.connect(func(): _send({"operation": "zeni", "id": "", "count": -int(_zeni_amount.value)}))
    _rule = hud._button("", Vector2(FRAME.position.x + 334, row_y), Vector2(180, 20), self)
    _rule.add_theme_font_size_override("font_size", 8)
    _rule.pressed.connect(func():
        var mine: Dictionary = guilds().guild(guilds().guild_of(hud.player.character_id))
        _send({"operation": "withdraw", "id": "members" if mine.get("withdraw") == "officers" else "officers"}))
    hud._label("Shift-click: a whole stack · guild quests renew every %d in-game days · Esc: close" % GUILDS.WEEK_DAYS, FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func guilds() -> Node:
    return hud.get_parent().get("guilds")

func is_open() -> bool:
    return visible

func open() -> void:
    if hud.menu_open() or guilds() == null:
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

func _send(payload: Dictionary) -> void:
    if hud.session.active:
        hud.session.request_action("guild", payload)

func refresh() -> void:
    for list in [_mine, _bank, _week]:
        for child in list.get_children():
            child.queue_free()
    var node := guilds()
    var me: Node = hud.player
    var id: String = node.guild_of(me.character_id)
    if id.is_empty():
        _title.text = "GUILD HALL"
        _summary.text = "Join or found a guild (P → Guild) to use its bank and quests here."
        _rule.visible = false
        return
    var entry: Dictionary = node.guild(id)
    var bank: Dictionary = entry.bank
    var room: Array = node.bank_room(id)
    var level: int = node.level_of(id)
    _title.text = "%s <%s> · LEVEL %d" % [String(entry.name).to_upper(), entry.tag, level]
    _summary.text = "Bank: items %d / %d · gear %d / %d · %d Zeni (you have %d) · %s may take" % [GUILDS.units(bank), int(room[0]), bank.items.size(), int(room[1]), int(bank.zeni), int(me.progression.get("zeni", 0)), "every member" if entry.withdraw == "members" else "officers and the leader"]
    _rule.visible = node.rank_of(me.character_id) == "leader"
    _rule.text = "Let members take" if entry.withdraw == "officers" else "Only officers take"
    var worn: Array = me.progression.get("equipment", {}).values()
    for item in me.gear.items:
        if not item.id in worn:
            _line(_mine, GEAR.display_name(item), GEAR.icon_texture(item.base, int(item.rarity))).pressed.connect(_move.bind("put", item.id, 1))
    for stack in me.get_node("Inventory").entries():
        var stack_id := String(stack.id)
        var count := int(stack.count)
        _line(_mine, "%s ×%d" % [stack.name, count], null).pressed.connect(func(): _move("put", stack_id, count if Input.is_key_pressed(KEY_SHIFT) else 1))
    for item in bank.items:
        _line(_bank, GEAR.display_name(item), GEAR.icon_texture(item.base, int(item.rarity))).pressed.connect(_move.bind("take", item.id, 1))
    for good in bank.goods:
        var have: int = int(bank.goods[good])
        _line(_bank, "%s ×%d" % [TRADE.good_info(good)[0] if TRADE.is_good(good) else String(good).replace("_", " ").capitalize(), have], null).pressed.connect(func(): _move("take", good, have if Input.is_key_pressed(KEY_SHIFT) else 1))
    # Level, perks, this week's goals.
    var next_xp: int = int(GUILDS.LEVEL_XP[level]) if level < GUILDS.LEVEL_XP.size() else -1
    _text(_week, "Guild XP %d%s" % [int(entry.xp), " / %d for level %d" % [next_xp, level + 1] if next_xp > 0 else " (highest level)"], UI.GOLD_LIGHT)
    for perk in GUILDS.perk_lines(level):
        _text(_week, perk[0], Color("8fe3a0") if perk[1] else UI.TEXT_DIM)
    _text(_week, "This week", UI.GOLD_LIGHT)
    for goal in node.goals(id):
        _text(_week, "%s %s  %d / %d" % ["✓" if goal.done else "·", GUILDS.QUEST_KINDS[goal.kind][0], int(goal.have), int(goal.need)], Color("8fe3a0") if goal.done else UI.TEXT)
    _text(_week, "Each: +%d guild XP, +%d Zeni in the bank" % [GUILDS.QUEST_XP, GUILDS.QUEST_ZENI], UI.TEXT_DIM)

func _move(operation: String, item: String, count: int) -> void:
    _send({"operation": operation, "id": item, "count": count})
    await get_tree().process_frame
    _signature = ""
    refresh()

func _text(list: VBoxContainer, text: String, colour: Color) -> void:
    var label: Label = hud._label(text, Vector2.ZERO, Vector2(COLUMN - 16, 14), list, 8)
    label.custom_minimum_size = Vector2(COLUMN - 16, 14)
    label.add_theme_color_override("font_color", colour)

func _line(list: VBoxContainer, text: String, icon: Texture2D) -> Button:
    var button := Button.new()
    button.text = text
    button.icon = icon
    button.expand_icon = true
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.custom_minimum_size = Vector2(COLUMN - 16, 18)
    button.add_theme_font_size_override("font_size", 8)
    button.add_theme_constant_override("icon_max_width", 14)
    button.clip_text = true
    list.add_child(button)
    return button

func _process(_delta: float) -> void:
    if not visible or guilds() == null or not is_instance_valid(hud.player):
        return
    var signature := JSON.stringify([guilds().state.guilds.get(guilds().guild_of(hud.player.character_id), {}), hud.player.gear.items.size(), hud.player.get_node("Inventory").total_units(), hud.player.progression.get("zeni", 0)])
    if signature != _signature:
        _signature = signature
        refresh()

func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        close_panel()
        get_viewport().set_input_as_handled()
