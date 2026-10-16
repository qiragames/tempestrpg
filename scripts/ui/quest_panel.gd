extends Control
## Quests on screen (M9c): talking to quest givers and bounty boards (F) through the dialogue
## window — taking quests, handing things in — the quest log (O) with every active quest and its
## objective (the main story first), the tracked objective under the minimap, and the story's
## words (Lumi's and everyone else's) whenever one of your quest steps is done. Only ids go to the
## host (the "quest" intent); progress comes back with the character's save data.
const UI := preload("res://scripts/ui/ui_style.gd")
const QUESTS := preload("res://scripts/quests/quest_catalogue.gd")
const LOG := preload("res://scripts/quests/quest_log.gd")
const FRAME := Rect2(40, 10, 560, 338)

var hud: CanvasLayer
var _list: VBoxContainer
var _summary: Label
var _paused_before := false
## Story lines waiting to be shown: [[speaker, text], ...].
var _queue: Array = []
## The steps last seen per quest (to notice progress): {id: step or -1 when done}.
var _seen: Dictionary = {}
var _seen_ready := false
var tracked := ""
## The story's lines show in a small speech box at the bottom of the screen: it never pauses the
## game or blocks other windows; each line stays a few seconds (longer for longer lines).
var speech: Control
var _speech_face: TextureRect
var _speech_name: Label
var _speech_text: Label
var _speech_left := 0.0
## M9d: the ending choice opens by itself once (later from the quest log's Decide button).
var _choice_offered: Dictionary = {}

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "QuestPanel"
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
    UI.heading(hud._label("QUESTS", FRAME.position + Vector2(14, 10), Vector2(300, 20), self, 14))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    close.pressed.connect(close_panel)
    _summary = hud._label("", FRAME.position + Vector2(14, 34), Vector2(FRAME.size.x - 28, 14), self, 9)
    _summary.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    var scroll := ScrollContainer.new()
    scroll.position = FRAME.position + Vector2(14, 52)
    scroll.size = Vector2(FRAME.size.x - 28, FRAME.size.y - 78)
    add_child(scroll)
    _list = VBoxContainer.new()
    _list.custom_minimum_size = Vector2(FRAME.size.x - 44, 0)
    _list.add_theme_constant_override("separation", 4)
    scroll.add_child(_list)
    hud._label("Quest givers show ! (a quest) and ? (something to hand in) · bounty boards in every town · O / Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()
    speech = Panel.new()
    speech.name = "StorySpeech"
    speech.position = Vector2(150, 242)
    speech.size = Vector2(340, 58)
    speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
    speech.add_theme_stylebox_override("panel", UI.ornate())
    _speech_face = TextureRect.new()
    _speech_face.position = Vector2(6, 6)
    _speech_face.size = Vector2(46, 46)
    _speech_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _speech_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _speech_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    speech.add_child(_speech_face)
    _speech_name = hud._label("", Vector2(58, 5), Vector2(274, 12), speech, 9)
    _speech_name.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _speech_text = hud._label("", Vector2(58, 18), Vector2(274, 36), speech, 8)
    _speech_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    speech.hide()
    hud.add_child.call_deferred(speech)

func quests_node() -> Node:
    return hud.get_parent().get("quests")

static func face(npc: String) -> Texture2D:
    if QUESTS.NPCS.has(npc):
        var path := "res://assets/game/sprites/%s/%s_face.png" % [QUESTS.NPCS[npc][1], QUESTS.NPCS[npc][1]]
        return load(path) if ResourceLoader.exists(path) else null
    return null

static func speaker_face(name: String) -> Texture2D:
    for id in QUESTS.NPCS:
        if QUESTS.NPCS[id][0] == name:
            return face(id)
    return null

## --- Talking (F at a giver or board).
func talk_to(npc: String) -> void:
    var log: Node = quests_node()
    var me: Node = hud.player
    # Someone waiting for you: talk (their lines follow when the step is done).
    if log.marker(me, npc) == "?":
        var lines: Array = []
        for id in LOG.quests_of(me):
            var step: Dictionary = LOG.current_step(me, id)
            if LOG.active(me, id) and ((step.get("type") == "talk" and step.get("npc") == npc) or (step.get("type") == "bring" and QUESTS.quest(id).giver == npc)):
                lines.append("%s — %s" % [QUESTS.quest(id).title, LOG.objective(me, id)])
        hud.dialog_panel.open(QUESTS.npc_name(npc), "\n".join(lines), [["Here you are.", func(): hud.session.request_action("quest", {"operation": "talk", "id": npc})], ["Later.", func(): pass]], face(npc))
        return
    var offered: Array = QUESTS.offered_by(npc).filter(func(id): return log.available(me, id))
    if not offered.is_empty():
        var options: Array = []
        for id in offered:
            options.append([("Bounty: " if QUESTS.quest(id).kind == "bounty" else ("Story: " if QUESTS.is_main(id) else "")) + String(QUESTS.quest(id).title).trim_prefix("Bounty: "), _offer.bind(npc, id)])
        options.append(["Goodbye.", func(): pass])
        hud.dialog_panel.open(QUESTS.npc_name(npc), "Board notices:" if npc.begins_with("board_") else "What brings you here?", options, face(npc))
        return
    var busy: Array = []
    for id in QUESTS.offered_by(npc):
        if LOG.active(me, id):
            busy.append("%s — %s" % [QUESTS.quest(id).title, LOG.objective(me, id)])
    var words := "\n".join(busy) if not busy.is_empty() else ("No new notices. Bounties return a day after they are claimed." if npc.begins_with("board_") else "Safe travels, friend.")
    hud.dialog_panel.open(QUESTS.npc_name(npc), words, [["Goodbye.", func(): pass]], face(npc))

func _offer(npc: String, id: String) -> void:
    var quest := QUESTS.quest(id)
    var intro: Array = quest.get("intro", [["", ""]])[0]
    _seen[id] = 0
    var options: Array = [["Accept: %s" % quest.title, _accept.bind(id)], ["Not now.", func(): pass]]
    hud.dialog_panel.open(intro[0] if not String(intro[0]).is_empty() else QUESTS.npc_name(npc), intro[1], options, face(npc))

func _accept(id: String) -> void:
    hud.session.request_action("quest", {"operation": "accept", "id": id})
    if QUESTS.is_main(id) or tracked.is_empty():
        tracked = id

## --- The story's words when your steps are done.
func _watch() -> void:
    var me: Node = hud.player
    if not is_instance_valid(me):
        return
    var quests: Dictionary = LOG.quests_of(me)
    for id in quests:
        var quest := QUESTS.quest(id)
        if quest.is_empty() or not quests[id] is Dictionary:
            continue
        var now := -1 if bool(quests[id].get("done", false)) else int(quests[id].get("s", 0))
        if not _seen.has(id):
            _seen[id] = now
            # A story just begun (Lumi's first words) — not when a save is loaded.
            if _seen_ready and now == 0:
                for line in quest.get("intro", []):
                    _queue.append(line)
            continue
        var before: int = _seen[id]
        if before == now:
            continue
        var last: int = quest.steps.size() if now == -1 else now
        if before >= 0:
            for index in range(before, mini(last, quest.steps.size())):
                for line in quest.steps[index].get("say", []):
                    _queue.append(line)
        _seen[id] = now
        if now == -1 and tracked == id:
            tracked = ""
    _seen_ready = true

func _show_queue(delta: float) -> void:
    _speech_left -= delta
    if _speech_left > 0.0:
        speech.visible = not hud.menu_open()
        return
    if _queue.is_empty():
        speech.hide()
        return
    var line: Array = _queue.pop_front()
    var face_texture := speaker_face(line[0])
    if face_texture == null and line[0] == "Lumi":
        face_texture = _lumi_face()
    _speech_face.texture = face_texture
    _speech_name.text = line[0]
    _speech_text.text = line[1]
    _speech_left = clampf(2.5 + String(line[1]).length() * 0.05, 4.0, 9.0)
    speech.visible = not hud.menu_open()

static func _lumi_face() -> Texture2D:
    var path := "res://assets/game/sprites/npc_lumi/npc_lumi_face.png"
    return load(path) if ResourceLoader.exists(path) else null

## --- The story's ending (M9d): Lumi asks what becomes of the moon's core.
func open_choice() -> void:
    var me: Node = hud.player
    var id := LOG.choice_pending(me)
    if id.is_empty() or hud.menu_open():
        return
    _choice_offered[id] = true
    var options: Array = []
    for option in LOG.current_step(me, id).options:
        options.append([option[0], _choose.bind(id, option[1])])
    options.append(["Not yet — let me think.", func(): pass])
    hud.dialog_panel.open("Lumi", "The Regent's shards lie on the stones, and the moon's core glows between them. What should become of it?", options, _lumi_face())

func _choose(id: String, key: String) -> void:
    hud.session.request_action("quest", {"operation": "choose", "id": key})
    for option in QUESTS.quest(id).steps[QUESTS.quest(id).steps.size() - 1].get("options", []):
        if option[1] == key:
            for line in option[3]:
                _queue.append(line)

## --- Tracking.
func tracked_quest() -> String:
    var me: Node = hud.player
    if not tracked.is_empty() and LOG.active(me, tracked):
        return tracked
    for id in LOG.quests_of(me):
        if QUESTS.is_main(id) and LOG.active(me, id):
            return id
    for id in LOG.quests_of(me):
        if LOG.active(me, id) and not QUESTS.quest(id).is_empty():
            return id
    return ""

func tracker_text() -> String:
    var id := tracked_quest()
    if id.is_empty():
        return ""
    return "◆ %s\n%s" % [QUESTS.quest(id).title, LOG.objective(hud.player, id)]

func _process(delta: float) -> void:
    if not is_instance_valid(hud.player) or quests_node() == null:
        return
    _watch()
    _show_queue(delta)
    var pending := LOG.choice_pending(hud.player)
    if not pending.is_empty() and not _choice_offered.has(pending) and _queue.is_empty() and _speech_left <= 0.0 and not hud.menu_open():
        open_choice()

## --- The log.
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

func refresh() -> void:
    for child in _list.get_children():
        child.queue_free()
    var me: Node = hud.player
    var ids: Array = LOG.quests_of(me).keys().filter(func(id): return LOG.active(me, id) and not QUESTS.quest(id).is_empty())
    ids.sort_custom(func(a, b): return (0 if QUESTS.is_main(a) else (2 if QUESTS.quest(a).kind == "bounty" else 1)) < (0 if QUESTS.is_main(b) else (2 if QUESTS.quest(b).kind == "bounty" else 1)))
    var done := 0
    for id in LOG.quests_of(me):
        if LOG.finished(me, id) and QUESTS.quest(id).get("kind", "") != "bounty":
            done += 1
    _summary.text = "%d active · %d completed · tracked: %s" % [ids.size(), done, QUESTS.quest(tracked_quest()).get("title", "—")]
    for id in ids:
        var quest := QUESTS.quest(id)
        var row := HBoxContainer.new()
        row.custom_minimum_size = Vector2(FRAME.size.x - 44, 30)
        _list.add_child(row)
        var label: Label = hud._label("%s%s\n   %s" % ["MAIN STORY · " if QUESTS.is_main(id) else ("BOUNTY · " if quest.kind == "bounty" else ""), quest.title, LOG.objective(me, id)], Vector2.ZERO, Vector2(10, 28), row, 9)
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.autowrap_mode = TextServer.AUTOWRAP_OFF
        label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        label.add_theme_color_override("font_color", UI.GOLD_LIGHT if QUESTS.is_main(id) else UI.TEXT)
        var deciding: bool = LOG.current_step(me, id).get("type") == "choice"
        var track: Button = hud._button("Decide" if deciding else ("Tracked" if tracked_quest() == id else "Track"), Vector2.ZERO, Vector2(64, 20), row)
        track.custom_minimum_size = Vector2(64, 20)
        track.add_theme_font_size_override("font_size", 8)
        if deciding:
            track.pressed.connect(func():
                close_panel()
                open_choice()
            )
        else:
            track.pressed.connect(func():
                tracked = id
                refresh()
            )
    if ids.is_empty():
        hud._label("No active quests. Look for ! above people in the towns, or a town's bounty board.", Vector2.ZERO, Vector2(FRAME.size.x - 44, 14), _list, 9).add_theme_color_override("font_color", UI.TEXT_DIM)

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if event.is_action_pressed("ui_cancel") or (event.is_action_pressed("quests") and not event.is_echo()):
        close_panel()
        get_viewport().set_input_as_handled()
