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

## M5b: a field's choices — plant a crop, wait, or harvest.
func _talk_field(camp_node: Node2D, field: String) -> void:
    var NATION := preload("res://scripts/nation/nation_catalogue.gd")
    var send := func(operation: String, id: String):
        session.request_action("camp", {"operation": operation, "id": id})
    var growth: float = camp_node.field_growth(field)
    if growth < 0.0:
        var options: Array = []
        for crop in NATION.CROPS:
            var spec: Array = NATION.CROPS[crop]
            options.append(["Plant %s (ripe in %d min, %d food)" % [spec[0].to_lower(), int(spec[1] / 60.0), spec[2]], send.bind("plant", "%s:%s" % [field, crop])])
        options.append(["Leave it fallow.", func(): pass])
        hud.dialog_panel.open("Field", "Bare soil, ready for seed. Citizens eat %d food a day each." % NATION.FOOD_PER_DAY, options)
    elif growth >= 1.0:
        session.request_action("camp", {"operation": "harvest", "id": field})
    else:
        var crop: String = camp_node.state.nation.fields[field].crop
        session.notify_character(hud.player.character_id, "%s growing: %d%%." % [NATION.CROPS[crop][0], int(growth * 100.0)])

## M4.7: what a realm person says and offers (requests go to the host, which decides).
func _talk_realm(person: String) -> void:
    var REALM := preload("res://scripts/realm/realm_catalogue.gd")
    var send := func(operation: String, id: String = ""):
        session.request_action("realm", {"operation": operation, "id": id})
    var options: Array = []
    match person:
        "secret_hermit":
            for index in range(REALM.HERMIT_ANSWERS.size()):
                options.append([REALM.HERMIT_ANSWERS[index], send.bind("answer", str(index))])
            hud.dialog_panel.open("Old Hermit", REALM.HERMIT_QUESTION, options)
        "realm_guide":
            hud.dialog_panel.open("Realm Guide", "The hermit's door works both ways. Shall I send you back to Sakura Vale?", [["Take me back.", send.bind("leave")], ["I'll stay a while.", func(): pass]])
        "announcer":
            hud.dialog_panel.open("Announcer", "Welcome to the World Martial Grounds! Five bouts in the ring; leave it or fall and you lose. Fighters must be level %d." % REALM.TOURNAMENT_LEVEL, [["Enter the tournament (%d Zeni)" % REALM.ENTRY_FEE, send.bind("enter")], ["Not today.", func(): pass]])
        "altar":
            var wishes := {"item": "A Legendary treasure", "zeni": "%d Zeni" % REALM.WISH_ZENI, "points": "%d skill points" % REALM.WISH_POINTS, "aura": "A greater transformation"}
            for wish in REALM.WISHES:
                options.append(["I wish for... %s" % wishes[wish], send.bind("wish", wish)])
            hud.dialog_panel.open("The Guardian's Altar", "Seven hollows wait in the stone. Place all seven orbs and speak your wish.", options)
        _:
            var mentor: Array = REALM.mentor(person)
            if mentor.is_empty():
                return
            var what: String = REALM.AURAS[mentor[5]][0] if mentor[4] == "aura" else load(preload("res://scripts/skills/skill_catalogue.gd").SKILLS[mentor[5]]).display_name
            hud.dialog_panel.open(mentor[1], "\"%s\"" % mentor[8], [["Learn %s (level %d, %d Zeni)" % [what, mentor[6], mentor[7]], send.bind("learn", person)], ["Maybe later.", func(): pass]])

func open_nearest() -> void:
    if hud.menu_open() or hud.player.get_node("Health").current <= 0:
        return
    # F at the trial stone starts the (placeholder) Proving Trial instead.
    var trial = hud.get_parent().trial
    if trial.near(hud.player):
        # The host explains any refusal through the System Voice.
        session.request_action("trial", {"operation": "start"})
        return
    # M4.6: F beside a defeated party member revives them.
    var party = hud.get_parent().get("party")
    if party != null:
        var fallen: String = party.revivable_near(hud.player)
        if not fallen.is_empty():
            session.request_action("party", {"operation": "revive", "id": fallen})
            return
    # M5b: F at one of your fields plants or harvests.
    var camp_node = hud.get_parent().get("camp")
    if camp_node != null and camp_node.state.founded:
        var field: String = camp_node.nearest_field(hud.player)
        if not field.is_empty():
            _talk_field(camp_node, field)
            return
    # M5d: a rival nation's leader.
    var rivals = hud.get_parent().get("rivals")
    if rivals != null:
        var leader: String = rivals.nearest_leader(hud.player)
        if not leader.is_empty():
            var entry: Array = rivals.rival(leader)
            hud.dialog_panel.open("%s of the %s" % [entry[7], entry[1]], "\"%s\"\n(The %s, %s, rule from %s. They are neither friend nor foe — for now.)" % [entry[8], entry[1], entry[2], preload("res://scripts/world/world_map.gd").town(entry[3])[1]], [["Farewell.", func(): pass]])
            return
    # M4.7: the Ki Realm's people, the wish altar and the orbs.
    var realm = hud.get_parent().get("realm")
    if realm != null:
        var orb: int = realm.nearest_orb(hud.player)
        if orb >= 0:
            session.request_action("realm", {"operation": "orb", "id": str(orb)})
            return
        var person: String = realm.nearest_person(hud.player)
        if not person.is_empty():
            _talk_realm(person)
            return
    # User request: F at a tree or rock chops or mines it.
    var camp_node_f = hud.get_parent().get("camp")
    if camp_node_f != null:
        var deposit: String = camp_node_f.nearest_deposit(hud.player)
        if not deposit.is_empty():
            session.request_action("camp", {"operation": "chop", "id": deposit})
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
    # M6a: F at a tree or ore rock of the world works it (professions).
    var nodes = hud.get_parent().get("nodes")
    if nodes != null and hud.player.fishing_bite_in == -INF:
        var node: int = nodes.nearest(hud.player)
        if node >= 0:
            session.request_action("node", {"index": node})
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
