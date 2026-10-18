extends Control
## The guild window (M14a; from the Party window's "Guild" button). Without a guild: found one
## (name, tag, emblem, 1000 Zeni) or answer an invitation. In a guild: its members with their rank
## and what your rank may do to them (promote, demote, hand over the lead, remove), inviting the
## characters online, leaving and disbanding. Only names and ids go to the host ("guild" intent).
const UI := preload("res://scripts/ui/ui_style.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const GUILDS := preload("res://scripts/guilds/world_guilds.gd")
const FRAME := Rect2(110, 30, 420, 290)
const GUILD_COLOR := Color("8fe3a0")

var hud: CanvasLayer
var _title: Label
var _info: Label
var _list: VBoxContainer
var _form: Control
var _name: LineEdit
var _tag: LineEdit
var _emblem: OptionButton
var _invite_label: Label
var _accept: Button
var _decline: Button
var _close: Button
var _paused_before := false
var _signature := ""

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "GuildPanel"
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
    _title = UI.heading(hud._label("GUILD", FRAME.position + Vector2(14, 10), Vector2(300, 20), self, 14))
    _close = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    _close.pressed.connect(close_panel)
    _info = hud._label("", FRAME.position + Vector2(14, 34), Vector2(FRAME.size.x - 28, 14), self, 9)
    _info.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _invite_label = hud._label("", FRAME.position + Vector2(14, 52), Vector2(FRAME.size.x - 28, 14), self, 9)
    _invite_label.add_theme_color_override("font_color", GUILD_COLOR)
    _accept = hud._button("Join", FRAME.position + Vector2(14, 68), Vector2(90, 20), self)
    _accept.pressed.connect(func(): _send({"operation": "accept"}))
    _decline = hud._button("Decline", FRAME.position + Vector2(110, 68), Vector2(90, 20), self)
    _decline.pressed.connect(func(): _send({"operation": "decline"}))
    # Founding form.
    _form = Control.new()
    _form.name = "FoundForm"
    _form.position = FRAME.position + Vector2(14, 96)
    add_child(_form)
    hud._label("Found a guild (%d Zeni): a name, a tag of %d-%d capitals, an emblem" % [GUILDS.FOUND_PRICE, GUILDS.TAG_MIN, GUILDS.TAG_MAX], Vector2.ZERO, Vector2(FRAME.size.x - 28, 14), _form, 9)
    _name = LineEdit.new()
    _name.name = "GuildName"
    _name.position = Vector2(0, 20)
    _name.size = Vector2(190, 18)
    _name.max_length = GUILDS.NAME_MAX
    _name.placeholder_text = "Guild name"
    _name.add_theme_font_size_override("font_size", 8)
    _form.add_child(_name)
    _tag = LineEdit.new()
    _tag.name = "GuildTag"
    _tag.position = Vector2(196, 20)
    _tag.size = Vector2(60, 18)
    _tag.max_length = GUILDS.TAG_MAX
    _tag.placeholder_text = "TAG"
    _tag.add_theme_font_size_override("font_size", 8)
    _tag.text_changed.connect(func(text):
        var caret := _tag.caret_column
        _tag.text = text.to_upper()
        _tag.caret_column = caret)
    _form.add_child(_tag)
    _emblem = OptionButton.new()
    _emblem.name = "GuildEmblem"
    _emblem.position = Vector2(262, 20)
    _emblem.size = Vector2(130, 18)
    _emblem.add_theme_font_size_override("font_size", 8)
    for emblem in NATION.EMBLEMS:
        _emblem.add_item(emblem)
    _form.add_child(_emblem)
    var found: Button = hud._button("Found guild", Vector2(0, 46), Vector2(120, 22), _form)
    found.name = "Found"
    found.pressed.connect(func(): _send({"operation": "found", "id": "", "name": _name.text.strip_edges(), "tag": _tag.text.strip_edges(), "emblem": _emblem.selected}))
    # Members.
    var scroll := ScrollContainer.new()
    scroll.position = FRAME.position + Vector2(14, 56)
    scroll.size = Vector2(FRAME.size.x - 28, FRAME.size.y - 84)
    add_child(scroll)
    _list = VBoxContainer.new()
    _list.custom_minimum_size = Vector2(FRAME.size.x - 44, 0)
    _list.add_theme_constant_override("separation", 2)
    scroll.add_child(_list)
    hud._label("Leader and officers invite · officers remove members · /g in chat talks to the guild · Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
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

func _row() -> HBoxContainer:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 22)
    row.add_theme_constant_override("separation", 4)
    _list.add_child(row)
    return row

func _small_button(text: String, row: Node, payload: Dictionary) -> void:
    var button: Button = hud._button(text, Vector2.ZERO, Vector2(66, 20), row)
    button.custom_minimum_size = Vector2(66, 20)
    button.add_theme_font_size_override("font_size", 8)
    button.pressed.connect(func(): _send(payload))

func refresh() -> void:
    for child in _list.get_children():
        child.queue_free()
    var node: Node = guilds()
    var me: String = hud.player.character_id
    var id: String = node.guild_of(me)
    var invite: Dictionary = node.state.invites.get(me, {})
    var invited: bool = id.is_empty() and not invite.is_empty() and node.state.guilds.has(invite.guild)
    _invite_label.text = "%s invites you to %s <%s>." % [invite.from, node.state.guilds[invite.guild].name, node.state.guilds[invite.guild].tag] if invited else ""
    _accept.visible = invited
    _decline.visible = invited
    _form.visible = id.is_empty()
    _list.get_parent().visible = not id.is_empty()
    if id.is_empty():
        _title.text = "GUILD"
        _info.text = "You are in no guild. %d guild%s in this world." % [node.state.guilds.size(), "" if node.state.guilds.size() == 1 else "s"]
        return
    var entry: Dictionary = node.guild(id)
    var rank: String = node.rank_of(me)
    _title.text = "%s <%s>" % [String(entry.name).to_upper(), entry.tag]
    _info.text = "%s emblem · %d / %d members · you are %s" % [NATION.EMBLEMS[int(entry.emblem)], entry.members.size(), node.MAX_MEMBERS, "the leader" if rank == "leader" else ("an officer" if rank == "officer" else "a member")]
    for member in entry.members:
        var row := _row()
        var their: String = node.rank_of(member)
        var online: bool = hud.get_parent().player_by_id(member) != null
        var label: Label = hud._label("%s%s%s" % ["★ " if their == "leader" else ("◆ " if their == "officer" else ""), member, " (you)" if member == me else ("" if online else " · away")], Vector2.ZERO, Vector2(150, 20), row, 9)
        label.custom_minimum_size = Vector2(150, 20)
        label.add_theme_color_override("font_color", GUILD_COLOR if online else UI.TEXT_DIM)
        if member == me:
            _small_button("Leave", row, {"operation": "leave"})
            if rank == "leader":
                _small_button("Disband", row, {"operation": "disband"})
            continue
        if rank == "leader":
            _small_button("Demote" if their == "officer" else "Promote", row, {"operation": "demote" if their == "officer" else "promote", "id": member})
            _small_button("Make leader", row, {"operation": "transfer", "id": member})
        if rank == "leader" or (rank == "officer" and their == "member"):
            _small_button("Remove", row, {"operation": "kick", "id": member})
    # Characters online who could be invited.
    if rank in ["leader", "officer"]:
        for character in get_tree().get_nodes_in_group("player"):
            var other: String = character.character_id
            if other == me or not node.guild_of(other).is_empty() or character.get_parent() != hud.get_parent():
                continue
            var row := _row()
            var label: Label = hud._label(other + " · not in a guild", Vector2.ZERO, Vector2(150, 20), row, 9)
            label.custom_minimum_size = Vector2(150, 20)
            _small_button("Invite", row, {"operation": "invite", "id": other})

func _process(_delta: float) -> void:
    if not visible or guilds() == null:
        return
    var signature := JSON.stringify([guilds().state, get_tree().get_nodes_in_group("player").size()])
    if signature != _signature:
        _signature = signature
        refresh()

func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        close_panel()
        get_viewport().set_input_as_handled()
