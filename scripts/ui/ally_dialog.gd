extends Panel
## UI sends an entity ID only; the host validates the actual interacting character.
var ally_id: String = ""
var _title: Label
var _details: Label
var _recruit: Button
var _name_field: LineEdit
var _close: Button
var _paused_before: bool = false
@onready var hud = get_parent()
@onready var session: Node = get_node("/root/GameSession")

func _ready() -> void:
    position = Vector2(150, 75)
    size = Vector2(340, 210)
    add_theme_stylebox_override("panel", hud._panel_style())
    _title = hud.UI.heading(hud._label("NAMELESS GOBLIN", Vector2(12, 10), Vector2(260, 24), self, 14))
    _details = hud._label("", Vector2(12, 39), Vector2(316, 88), self, 11)
    _recruit = hud._button("Recruit", Vector2(12, 168), Vector2(170, 28), self)
    _name_field = LineEdit.new()
    _name_field.position = Vector2(12, 130)
    _name_field.size = Vector2(316, 28)
    _name_field.max_length = 24
    _name_field.placeholder_text = "Ally name (2-24 characters)"
    _name_field.add_theme_font_size_override("font_size", 11)
    add_child(_name_field)
    _recruit.pressed.connect(_confirm)
    _close = hud._button("Close", Vector2(190, 168), Vector2(138, 28), self)
    _close.pressed.connect(close_dialog)
    hide()

func open_nearest() -> void:
    if hud.menu_open() or hud.player.get_node("Health").current <= 0:
        return
    # F at the trial stone starts the (placeholder) Proving Trial instead.
    var trial = hud.get_parent().trial
    if trial.near(hud.player):
        # The host explains any refusal through the System Voice.
        session.request_action("trial", {"operation": "start"})
        return
    # F next to an unopened chest opens it (17g).
    var chest: String = hud.get_parent().nearest_chest(hud.player)
    if not chest.is_empty():
        session.request_action("chest", {"id": chest})
        return
    # M4.5c: F next to a merchant opens its shop; on a pier, the ferry.
    var trade = hud.get_parent().get("trade")
    if trade != null:
        var merchant: String = trade.nearest_merchant(hud.player)
        if not merchant.is_empty():
            hud.trade_panel.open(merchant)
            return
    # M4.5d: harbours (travel by map), wild animals to tame, fishing.
    var harbours = hud.get_parent().get("harbours")
    if harbours != null:
        var harbour: String = harbours.nearest_harbour(hud.player)
        if not harbour.is_empty():
            hud.harbour_panel.open(harbour)
            return
    var wild: String = preload("res://scripts/travel/wild_mounts.gd").nearest(hud.player.global_position)
    if not wild.is_empty():
        session.request_action("mount", {"operation": "tame", "id": wild})
        return
    if hud.player.fishing_bite_in != -INF:
        session.request_action("fish", {"operation": "reel"})
        return
    if int(hud.player.progression.get("tools", {}).get("rod", 0)) > 0 and _facing_water():
        session.request_action("fish", {"operation": "cast"})
        return
    var closest: Node2D
    var distance: float = 40.1
    for candidate in get_tree().get_nodes_in_group("allies"):
        var current: float = hud.player.global_position.distance_to(candidate.global_position)
        if current <= 40.0 and current < distance:
            closest = candidate
            distance = current
    if closest == null:
        hud.record_event("No ally nearby. Find the goblin to the west.")
        return
    ally_id = closest.entity_id
    _name_field.text = ""
    _paused_before = get_tree().paused
    if session.active:
        hud.player.input_blocked = true
        session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    show()
    _refresh()
    _close.grab_focus()

func _process(_delta: float) -> void:
    if visible:
        _refresh()

func _refresh() -> void:
    var ally = hud.get_parent().entity_by_id(ally_id)
    if ally == null:
        close_dialog()
        return
    var ours: bool = ally.owner_id == hud.player.character_id
    _title.text = "NAMELESS GOBLIN" if ally.display_name.is_empty() else ally.display_name
    _details.text = "%s · HP %d · Power %d\n%s" % [ally.race, ally.maximum_hp, ally.power, "Joined you. The goblin will follow." if ours else "Already follows another player." if not ally.owner_id.is_empty() else "Defeat the clearing's Gnasher, then offer your friendship."]
    var naming: bool = ours and ally.display_name.is_empty()
    _name_field.visible = naming
    if naming:
        _details.text = "Joined you. Name → Hobgoblin: HP 30 → 60, power 4 → 8.\nCost: %d Magicules (80%% of your maximum). Below 25%% reserves: sleep for at least 8s, until reserves reach 25%%." % int(ally.naming_cost(hud.player))
    _recruit.text = ("Confirm: %d Magicules" % int(ally.naming_cost(hud.player))) if naming else "Ally recruited" if ours else "Recruit"
    _recruit.disabled = not ally.can_reach(hud.player) or hud.player.get_node("Health").current <= 0 or hud.player.is_exhausted()
    if naming:
        _recruit.disabled = _recruit.disabled or not ally.valid_name(_name_field.text.strip_edges()) or hud.player.get_node("Magicules").current < ally.naming_cost(hud.player)
    else:
        _recruit.disabled = _recruit.disabled or not ally.owner_id.is_empty() or not ally.threat_cleared()

func _confirm() -> void:
    var ally = hud.get_parent().entity_by_id(ally_id)
    if ally != null and ally.owner_id == hud.player.character_id:
        session.request_action("name_ally", {"id": ally_id, "name": _name_field.text})
    else:
        session.request_action("recruit", {"id": ally_id})

func _facing_water() -> bool:
    var map := preload("res://scripts/world/world_map.gd")
    var tile: Vector2i = map.to_tile(hud.player.global_position + hud.player.facing.normalized() * preload("res://scripts/travel/travel_catalogue.gd").FISH_REACH)
    if not map.in_grid(tile):
        return false
    var data: Dictionary = map.data()
    return data.ocean[map.vertex_index(tile.x, tile.y)] == 1 or data.lake[map.vertex_index(tile.x, tile.y)] == 1

func close_dialog() -> void:
    if not visible:
        return
    hide()
    if session.active:
        hud.player.input_blocked = false
        session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and not event.is_echo():
        if visible:
            close_dialog()
        else:
            open_nearest()
        get_viewport().set_input_as_handled()
    elif visible and event.is_action_pressed("ui_cancel"):
        close_dialog()
        get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    if visible:
        get_tree().paused = _paused_before
