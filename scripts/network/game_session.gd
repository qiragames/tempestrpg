extends Node
## One RPC endpoint. Peer-to-character ownership is assigned and verified by the host.

signal character_assigned(id: String)
signal player_joined(actor: Node2D)
signal session_failed(message: String)
const MAX_PLAYERS := 8
const DEFAULT_PORT := 24560
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const LAYOUT := preload("res://scripts/world/world_layout.gd")
const RACES := preload("res://scripts/races/race_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
var active: bool = false
var replica_world: bool = false
var world: Node2D
var world_id: String = ""
var local_character_id: String = "host"
var save_path: String = "user://worlds/forest.json"
var identity_path: String = "user://profiles/characters.json"
var records: Dictionary = {}
var owners: Dictionary = {}
var latest_snapshot: Dictionary = {}
var rejected_requests: int = 0
var _snapshot_time: float = 0.0
var _save_time: float = 0.0
var _revision: int = 0
var _received_revision: int = -1
var _join_deadline: int = 0
var _action_budgets: Dictionary = {}
var _save_queued: bool = false
## True once the hosted world accepts guests ("Open to friends"); solo worlds open no port.
var listening: bool = false
var listen_port: int = DEFAULT_PORT
## Name, seed and dates of the hosted world (saved with it).
## Race requested for a new character when joining (ignored for returning characters).
var join_race: String = "Slime"
var world_meta: Dictionary = {}
## A world chosen in the title menu, started once the game scene is ready.
var pending_launch: Dictionary = {}
const TITLE_SCENE := "res://scenes/menu/title_menu.tscn"
const WORLD_SCENE := "res://scenes/world/forest.tscn"

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    multiplayer.peer_connected.connect(_peer_connected)
    multiplayer.peer_disconnected.connect(_peer_disconnected)
    multiplayer.connection_failed.connect(func(): _fail("Connection failed."))
    multiplayer.server_disconnected.connect(func(): _fail("Host disconnected. Reconnect to restore your character."))
    get_tree().root.close_requested.connect(_close_requested)
    call_deferred("_launch_arguments")

func _launch_arguments() -> void:
    var options: Dictionary = {}
    for argument in OS.get_cmdline_user_args():
        var pair := argument.trim_prefix("--").split("=", true, 1)
        options[pair[0]] = pair[1] if pair.size() == 2 else ""
    if not options.has("host") and not options.has("join"):
        return
    # Command-line hosting/joining skips the title menu.
    if options.has("host"):
        pending_launch = {"mode": "host", "port": int(options.get("port", DEFAULT_PORT)), "path": options.get("save", save_path), "listen": true, "race": options.get("race", RACES.DEFAULT)}
    else:
        pending_launch = {"mode": "join", "address": options.join, "port": int(options.get("port", DEFAULT_PORT)), "identity": options.get("identity", identity_path), "race": options.get("race", RACES.DEFAULT)}
    if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == WORLD_SCENE:
        await get_tree().process_frame
        bind_world(get_tree().current_scene)
        launch_pending()
    else:
        get_tree().change_scene_to_file(WORLD_SCENE)

## Called by the world scene when it is ready: start what the title menu (or CLI) asked for.
func launch_pending() -> void:
    if pending_launch.is_empty() or not is_instance_valid(world):
        return
    var launch := pending_launch
    pending_launch = {}
    if launch.mode == "host":
        start_host(launch.get("port", DEFAULT_PORT), launch.path, launch.get("listen", false), launch.get("meta", {}), launch.get("race", RACES.DEFAULT))
    else:
        join_host(launch.address, launch.get("port", DEFAULT_PORT), launch.get("identity", identity_path), launch.get("race", RACES.DEFAULT))

## Leave the current world (saving when hosting) and return to the title menu.
func quit_to_title() -> Error:
    if active and multiplayer.is_server():
        var error := save_world()
        if error != OK:
            world._announce("Saving failed. Your world is still open; retry Save & quit after correcting the save path or disk problem.")
            return error
    stop_session(false)
    get_tree().paused = false
    get_tree().change_scene_to_file(TITLE_SCENE)
    return OK

func bind_world(value: Node2D) -> void:
    if not active and value != world:
        replica_world = false
        local_character_id = "host"
    world = value

func new_id(prefix: String = "") -> String:
    return prefix + Crypto.new().generate_random_bytes(16).hex_encode()

## Host a saved world. With listen = false nothing is opened on the network (solo play); the
## world is still hosted and saved, and open_to_friends() can start accepting guests later.
## `race` applies only when the host's character is created (a world without a host record).
func start_host(port: int = DEFAULT_PORT, path: String = "user://worlds/forest.json", listen: bool = true, meta: Dictionary = {}, race: String = RACES.DEFAULT) -> Error:
    if active or replica_world or not is_instance_valid(world) or port < 1 or port > 65535:
        return ERR_INVALID_PARAMETER
    var loaded: Dictionary = {}
    if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
        var result := STORE.load_world(path)
        if not result.ok:
            _fail("Save is invalid; preserved on disk. Choose a different world path or restore a valid backup.")
            return ERR_FILE_CORRUPT
        loaded = result.data
    # Clients talk only to the host. No client-to-client relay is needed for
    # authoritative snapshots, and disabling it avoids stale relay peers on exit.
    (multiplayer as SceneMultiplayer).server_relay = false
    listening = false
    listen_port = port
    if listen:
        var error := _listen(port)
        if error != OK:
            return error
    else:
        multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    active = true
    Engine.max_fps = 60
    get_tree().auto_accept_quit = false
    save_path = path
    world_id = loaded.get("world_id", new_id("world_"))
    world_meta = loaded.get("meta", meta if not meta.is_empty() else {"name": path.get_file().get_basename().capitalize(), "seed": 0, "created": int(Time.get_unix_time_from_system()), "last_played": 0}).duplicate(true)
    world_meta.last_played = int(Time.get_unix_time_from_system())
    # New worlds are laid out from their seed; migrated ones say `seeded: false`.
    world_meta["seeded"] = world_meta.get("seeded", true)
    records = loaded.get("players", {}).duplicate(true)
    owners = {1: "host"}
    local_character_id = "host"
    var host_actor = world.get_local_player()
    host_actor.character_id = "host"
    host_actor.local_controlled = true
    if not records.has("host"):
        host_actor.choose_race(race if RACES.valid(race) else RACES.DEFAULT)
    # Seed 0 is the reference map (also every world saved before seeds existed).
    world.apply_layout(LAYOUT.seed_of(world_meta), loaded.is_empty())
    if not loaded.is_empty():
        world.progression = loaded.progression.duplicate(true)
        CODEC.apply_entities(world, loaded, false)
        CODEC.apply_player(host_actor, records.host, world, false)
    world.bind_local_player(host_actor)
    _track_actor(host_actor)
    _update_records()
    var saved := save_world()
    if saved != OK:
        stop_session(false)
        _fail("Could not save the hosted world; hosting stopped.")
        return saved
    world._announce("Hosting for up to 8 players on UDP %d. F9 saves." % port if listening else "World \"%s\" loaded. Esc: pause menu, open to friends." % world_meta.name)
    character_assigned.emit("host")
    return OK

func _listen(port: int) -> Error:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(port, MAX_PLAYERS - 1)
    if error != OK:
        _fail("Could not host on UDP port %d." % port)
        return error
    multiplayer.multiplayer_peer = peer
    listening = true
    listen_port = port
    return OK

## Start accepting guests in the running hosted world, without restarting it.
func open_to_friends(port: int = DEFAULT_PORT) -> Error:
    if not active or replica_world or listening or not multiplayer.is_server():
        return ERR_UNAVAILABLE
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(port, MAX_PLAYERS - 1)
    if error != OK:
        world._announce("Could not open UDP port %d. Is another game using it?" % port)
        return error
    multiplayer.multiplayer_peer = peer
    listening = true
    listen_port = port
    world._announce("Open to friends on UDP %d. They join with: %s" % [port, ", ".join(lan_addresses()) if not lan_addresses().is_empty() else "your IP address"])
    save_world()
    return OK

## Private IPv4 addresses friends on the same network can use to join.
static func lan_addresses() -> Array:
    var result: Array = []
    for address in IP.get_local_addresses():
        if address.begins_with("192.168.") or address.begins_with("10.") or (address.begins_with("172.") and address.split(".").size() == 4 and int(address.split(".")[1]) >= 16 and int(address.split(".")[1]) <= 31):
            result.append(address)
    return result

## `race` is used only if this world has no character for this profile yet.
func join_host(address: String, port: int = DEFAULT_PORT, profile: String = "user://profiles/characters.json", race: String = RACES.DEFAULT) -> Error:
    if active or not is_instance_valid(world) or address.is_empty() or port < 1 or port > 65535:
        return ERR_INVALID_PARAMETER
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_client(address, port)
    if error != OK:
        return error
    identity_path = profile
    join_race = race
    replica_world = true
    multiplayer.multiplayer_peer = peer
    active = true
    Engine.max_fps = 60
    local_character_id = ""
    _join_deadline = Time.get_ticks_msec() + 8000
    world.get_local_player().local_controlled = false
    for actor in world.get_children():
        if actor.is_in_group("player"):
            actor.configure_replica()
        elif actor.is_in_group("enemies") or actor.is_in_group("magicule_pickups"):
            actor.set_physics_process(false)
            if actor.has_node("Health"):
                actor.get_node("Health").set_process(false)
    return OK

func _peer_connected(peer: int) -> void:
    if active and multiplayer.is_server():
        _hello.rpc_id(peer, world_id)

@rpc("authority", "call_remote", "reliable")
func _hello(id: String) -> void:
    world_id = id
    var profiles: Variant = {}
    if FileAccess.file_exists(identity_path):
        var parser := JSON.new()
        profiles = parser.data if parser.parse(FileAccess.get_file_as_string(identity_path)) == OK else null
        if not profiles is Dictionary:
            _fail("Character profile is invalid; preserve it and restore a valid profile before joining.")
            return
    var profile: Variant = profiles.get(id, {})
    if not profile is Dictionary:
        _fail("Character profile is invalid.")
        return
    if not profile.get("character", "") is String or not profile.get("credential", "") is String:
        _fail("Character profile fields are invalid.")
        return
    _join_world.rpc_id(1, profile.get("character", ""), profile.get("credential", ""), join_race)

@rpc("any_peer", "call_remote", "reliable")
func _join_world(character: String, credential: String, race: String) -> void:
    if not active or not multiplayer.is_server():
        return
    var peer := multiplayer.get_remote_sender_id()
    if owners.has(peer):
        return
    if owners.size() >= MAX_PLAYERS:
        _deny(peer, "The eight-player session is full.")
        return
    if not character.is_empty():
        if character == "host" or not records.has(character) or credential.length() != 64 or records[character].get("token_hash", "") != (world_id + credential).sha256_text() or owners.values().has(character):
            _deny(peer, "Character identity could not be verified or is already connected.")
            return
    else:
        # New characters choose their race once; returning characters keep theirs.
        if not RACES.valid(race):
            rejected_requests += 1
            _deny(peer, "Unknown race. Choose Slime, Human or Demon.")
            return
        character = new_id("character_")
        credential = Crypto.new().generate_random_bytes(32).hex_encode()
    var actor = load("res://scenes/player/player.tscn").instantiate()
    actor.name = "Character_" + character
    actor.character_id = character
    actor.local_controlled = false
    actor.network_controlled = true
    actor.position = Vector2(480 + (owners.size() - 1) * 20, 340)
    world.add_child(actor)
    if records.has(character):
        CODEC.apply_player(actor, records[character], world, false)
    else:
        actor.choose_race(race)
        records[character] = CODEC.capture_player(actor)
        records[character]["token_hash"] = (world_id + credential).sha256_text()
    owners[peer] = character
    _wire_remote(actor)
    player_joined.emit(actor)
    _accepted.rpc_id(peer, character, credential)
    save_world()
    _broadcast()

func _deny(peer: int, message: String) -> void:
    _denied.rpc_id(peer, message)
    await get_tree().create_timer(0.2).timeout
    # The denied player may already have left; disconnecting a gone peer is an engine error.
    if active and multiplayer.is_server() and multiplayer.get_peers().has(peer):
        multiplayer.multiplayer_peer.disconnect_peer(peer)

@rpc("authority", "call_remote", "reliable")
func _denied(message: String) -> void:
    _fail(message)

@rpc("authority", "call_remote", "reliable")
func _accepted(character: String, credential: String) -> void:
    var profiles: Dictionary = {}
    if FileAccess.file_exists(identity_path):
        var parser := JSON.new()
        if parser.parse(FileAccess.get_file_as_string(identity_path)) != OK or not parser.data is Dictionary:
            _fail("Cannot overwrite an invalid reconnect profile.")
            return
        profiles = parser.data
    profiles[world_id] = {"character": character, "credential": credential}
    var absolute := ProjectSettings.globalize_path(identity_path)
    DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
    var file := FileAccess.open(absolute + ".tmp", FileAccess.WRITE)
    if file == null:
        _fail("Cannot save the reconnect profile; connection stopped.")
        return
    file.store_string(JSON.stringify(profiles))
    file.flush()
    var write_error := file.get_error()
    file.close()
    if write_error != OK or DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
        _fail("Cannot save the reconnect profile; connection stopped.")
        return
    local_character_id = character
    _join_deadline = 0
    var actor = world.get_local_player()
    actor.character_id = character
    actor.local_controlled = true
    world.bind_local_player(actor)
    character_assigned.emit(character)

func send_move(direction: Vector2) -> void:
    if active and not multiplayer.is_server() and not local_character_id.is_empty():
        _move_input.rpc_id(1, direction)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _move_input(direction: Vector2) -> void:
    if not multiplayer.is_server():
        return
    var peer := multiplayer.get_remote_sender_id()
    if not owners.has(peer) or not is_finite(direction.x) or not is_finite(direction.y) or absf(direction.x) > 1 or absf(direction.y) > 1:
        rejected_requests += 1
        return
    var actor = world.player_by_id(owners[peer])
    if actor:
        actor.remote_direction = direction.limit_length(1.0)
        actor.last_input_msec = Time.get_ticks_msec()

func request_action(action: String, payload: Dictionary = {}) -> void:
    if active and not multiplayer.is_server():
        if not local_character_id.is_empty():
            _request_action.rpc_id(1, action, payload)
    else:
        apply_action(world.get_local_player(), action, payload)

@rpc("any_peer", "call_remote", "reliable")
func _request_action(action: String, payload: Dictionary) -> void:
    if not multiplayer.is_server():
        return
    var peer := multiplayer.get_remote_sender_id()
    if not owners.has(peer):
        rejected_requests += 1
        return
    var now: int = int(Time.get_ticks_msec() / 1000.0)
    var budget: Dictionary = _action_budgets.get(peer, {"second": now, "count": 0})
    if budget.second != now:
        budget = {"second": now, "count": 0}
    budget.count += 1
    _action_budgets[peer] = budget
    if budget.count > 30:
        rejected_requests += 1
        return
    apply_action(world.player_by_id(owners[peer]), action, payload)

## Host: bring a defeated character back (24a): at the camp flag if the camp is founded, else at
## the clearing's spawn, with full HP and Magicules.
func respawn_character(actor: Node2D) -> void:
    if actor.get_node("Health").current > 0 or not is_instance_valid(world):
        return
    if actor.get_node("Absorption").active:
        actor.get_node("Absorption")._cancel("Analysis interrupted.")
    var camp: Node2D = world.camp
    actor.position = camp.SITE + Vector2(0, 26) if camp.state.founded else preload("res://scripts/world/world_layout.gd").SPAWN
    actor.death_left = 0.0
    var health: Node = actor.get_node("Health")
    health.current = health.maximum
    health.immunity_left = 1.0
    health.changed.emit(health.current, health.maximum)
    var pool: Node = actor.get_node("Magicules")
    pool.enabled = true
    pool._current = pool.maximum
    pool.changed.emit(pool.current, pool.maximum)
    actor.get_node("MeleeAttack").cooldown_left = 0.0
    actor.remote_direction = Vector2.ZERO
    actor.queue_redraw()
    notify_character(actor.character_id, "Respawned at %s." % ("the camp" if camp.state.founded else "the clearing"))
    queue_save()

func apply_action(actor: Node2D, action: String, payload: Dictionary = {}) -> bool:
    if actor == null or (active and not multiplayer.is_server()):
        return false
    if action == "menu":
        if payload.size() != 1 or not payload.get("open") is bool:
            rejected_requests += 1
            return false
        actor.input_blocked = payload.open
        actor.remote_direction = Vector2.ZERO
        return true
    if action == "respawn":
        # 24a: respawning is automatic after RESPAWN_DELAY; an early request is refused.
        if not payload.is_empty() or actor.get_node("Health").current > 0 or actor.input_blocked or actor.death_left > 0.0:
            return false
        respawn_character(actor)
        return true
    if actor.get_node("Health").current <= 0:
        return false
    if action == "ally_work":
        if payload.size() != 2 or not payload.get("id") is String or payload.id.length() > 64 or not payload.get("role") is String or payload.role.length() > 16:
            rejected_requests += 1
            return false
        var ally = world.entity_by_id(payload.id)
        return ally.assign_work(actor, payload.role) if ally != null and ally.is_in_group("allies") else false
    if action == "camp":
        if payload.size() != 2 or not payload.get("operation") is String or not payload.get("id") is String or payload.operation.length() > 16 or payload.id.length() > 64:
            rejected_requests += 1
            return false
        return world.camp.transact(actor, payload.operation, payload.id)
    if action == "recruit":
        if payload.size() != 1 or not payload.get("id") is String or payload.id.length() > 64:
            rejected_requests += 1
            return false
        var ally = world.entity_by_id(payload.id)
        return ally.try_recruit(actor) if ally != null and ally.is_in_group("allies") else false
    if action == "name_ally":
        if payload.size() != 2 or not payload.get("id") is String or payload.id.length() > 64 or not payload.get("name") is String or payload.name.length() > 64:
            rejected_requests += 1
            return false
        var ally = world.entity_by_id(payload.id)
        return ally.try_name(actor, payload.name) if ally != null and ally.is_in_group("allies") else false
    if action == "trial":
        # Only the stone interaction is sent; the trial checks skill, range, state and evidence.
        if payload.size() != 1 or payload.get("operation") != "start":
            rejected_requests += 1
            return false
        return false if actor.input_blocked else world.trial.try_start(actor)
    if action == "transform":
        # Clients name the target form only; the host checks knowledge, room, cost and timers.
        if payload.size() != 1 or not payload.get("form") is String or payload.form.length() > 32:
            rejected_requests += 1
            return false
        return false if actor.input_blocked else actor.try_transform(payload.form)
    if action == "tree":
        # Clients name a node to buy or a learned skill to activate; the host checks race, order and points.
        if payload.size() != 2 or not payload.get("operation") in ["buy", "activate"] or not payload.get("id") is String or payload.id.length() > 64:
            rejected_requests += 1
            return false
        return actor.buy_node(payload.id) if payload.operation == "buy" else actor.activate_skill(payload.id)
    if action == "trade":
        # M4.5c: clients name a merchant and an entry or an item; the host checks the rest.
        var operation: Variant = payload.get("operation")
        if operation == "buy" and payload.size() == 3 and payload.get("merchant") is String and payload.merchant.length() <= 32 and payload.get("id") is String and payload.id.length() <= 64:
            return world.trade.buy(actor, payload.merchant, payload.id)
        if operation == "sell" and payload.size() == 4 and payload.get("merchant") is String and payload.merchant.length() <= 32 and payload.get("kind") in ["gear", "bag"] and payload.get("id") is String and payload.id.length() <= 64:
            return world.trade.sell(actor, payload.merchant, payload.kind, payload.id)
        rejected_requests += 1
        return false
    if action == "ferry":
        if payload.size() != 1 or not payload.get("dock") is String or payload.dock.length() > 32:
            rejected_requests += 1
            return false
        return world.trade.sail(actor, payload.dock)
    if action == "use_item":
        if payload.size() != 1 or not payload.get("id") is String or payload.id.length() > 64:
            rejected_requests += 1
            return false
        return actor.use_good(payload.id)
    if action == "chest":
        if payload.size() != 1 or not payload.get("id") is String or payload.id.length() > 16:
            rejected_requests += 1
            return false
        return false if actor.input_blocked else world.open_chest(actor, payload.id)
    if action == "gear":
        # Clients name an owned item and a slot (or a slot to empty); the host checks the rest.
        var operation: Variant = payload.get("operation")
        if operation == "equip" and payload.size() == 3 and payload.get("id") is String and payload.id.length() <= 64 and payload.get("slot") is String and payload.slot.length() <= 16:
            return actor.equip(payload.id, payload.slot)
        if operation == "unequip" and payload.size() == 2 and payload.get("slot") is String and payload.slot.length() <= 16:
            return actor.unequip(payload.slot)
        if operation == "use" and payload.size() == 1:
            return false if actor.input_blocked else actor.use_gear_active()
        rejected_requests += 1
        return false
    if action == "fusion":
        # Clients name the skills to fuse or the fused skill to split; the host checks everything else.
        var fuse: bool = payload.get("operation") == "fuse"
        if fuse:
            if payload.size() != 3 or not payload.get("a") is String or not payload.get("b") is String or payload.a.length() > 64 or payload.b.length() > 64:
                rejected_requests += 1
                return false
            return actor.fuse_skills(payload.a, payload.b)
        if payload.size() != 2 or payload.get("operation") != "split" or not payload.get("id") is String or payload.id.length() > 64:
            rejected_requests += 1
            return false
        return actor.split_skill(payload.id)
    if action == "assign_slot":
        # Loadout is host-owned: clients name a slot and a skill ID; the book checks knowledge.
        var slot: Variant = payload.get("slot")
        if payload.size() != 2 or not (slot is int or (slot is float and slot == floor(slot))) or not payload.get("id") is String or payload.id.length() > 64:
            rejected_requests += 1
            return false
        var assigned: bool = actor.get_node("SkillBook").assign_slot(int(slot), StringName(payload.id))
        if assigned:
            queue_save()
        return assigned
    if action == "discard":
        if payload.size() != 1 or not payload.get("id") is String or payload.id.length() > 64:
            rejected_requests += 1
            return false
        return actor.get_node("Inventory").discard(StringName(payload.id))
    if actor.input_blocked or actor.is_exhausted():
        return false
    if not payload.is_empty():
        rejected_requests += 1
        return false
    match action:
        "attack":
            return actor.get_node("MeleeAttack").attack(actor.facing)
        "absorb":
            return actor.get_node("Absorption").attempt_absorb()
        "skill_1", "skill_2", "skill_3", "skill_4":
            var skill: Resource = actor.get_node("SkillBook").skill_at_slot(int(action.right(1)) - 1)
            return actor.get_node("MeleeAttack").attack_skill(actor.facing, skill.id) if skill else false
    rejected_requests += 1
    return false

func _wire_remote(actor: Node2D) -> void:
    _track_actor(actor)
    actor.get_node("Absorption").status_changed.connect(func(message: String): notify_character(actor.character_id, message, true))
    actor.get_node("Magicules").spend_rejected.connect(func(_cost: float): notify_character(actor.character_id, "Insufficient Magicules. Action unavailable."))
    actor.get_node("Health").defeated.connect(func(): notify_character(actor.character_id, "Vital signs depleted. Respawning in %d s." % int(actor.RESPAWN_DELAY)))

func _track_actor(actor: Node2D) -> void:
    if actor.has_meta("save_wired"):
        return
    actor.set_meta("save_wired", true)
    actor.get_node("Absorption").analyzed.connect(func(_specimen: Resource, _new_skill: bool): queue_save())
    actor.get_node("Inventory").changed.connect(queue_save)
    actor.get_node("Health").defeated.connect(queue_save)

func queue_save() -> void:
    if active and multiplayer.is_server() and not _save_queued:
        _save_queued = true
        _flush_save.call_deferred()

func _flush_save() -> void:
    _save_queued = false
    if active and multiplayer.is_server():
        save_world()

func notify_character(id: String, message: String, analysis: bool = false) -> void:
    if id == local_character_id:
        if analysis:
            world._analysis_changed(message)
        else:
            world._announce(message)
        return
    if active and multiplayer.is_server():
        var peer: int = owners.find_key(id) if owners.values().has(id) else 0
        if peer > 1:
            _notice.rpc_id(peer, message, analysis)

@rpc("authority", "call_remote", "reliable")
func _notice(message: String, analysis: bool = false) -> void:
    if is_instance_valid(world):
        if analysis:
            world._analysis_changed(message)
        else:
            world._announce(message)

func _update_records() -> void:
    for id in owners.values():
        var actor = world.player_by_id(id)
        if actor:
            var hash_value: String = records.get(id, {}).get("token_hash", "")
            records[id] = CODEC.capture_player(actor)
            records[id]["token_hash"] = hash_value

func document() -> Dictionary:
    _update_records()
    var data := CODEC.capture_entities(world)
    data.merge({"version": STORE.VERSION, "world_id": world_id, "players": records.duplicate(true), "progression": world.progression.duplicate(true)})
    if not world_meta.is_empty():
        data["meta"] = world_meta.duplicate(true)
    return data

## Saves exclude a running trial and its creatures: a host restart cancels the trial.
func persistent_document() -> Dictionary:
    var data := document()
    data.erase("trial")
    data.enemies = data.enemies.filter(func(enemy): return not String(enemy.id).begins_with("trial_"))
    return data

func save_world() -> Error:
    if not active or not multiplayer.is_server() or not is_instance_valid(world):
        return ERR_UNAUTHORIZED
    var result := STORE.write_world(save_path, persistent_document())
    if result != OK:
        world._announce("Save failed; the previous valid save is retained.")
    return result

func _broadcast() -> void:
    var data := document()
    var connected: Dictionary = {}
    for id in owners.values():
        if data.players.has(id):
            connected[id] = data.players[id].duplicate(true)
            connected[id].erase("token_hash")
    data.players = connected
    _revision += 1
    # Several clients can disconnect in the same poll. Do not broadcast to ENet
    # peers whose channels have already closed but whose callback is still queued.
    for peer in multiplayer.get_peers():
        if owners.has(peer) and multiplayer.multiplayer_peer.get_peer(peer).get_state() == ENetPacketPeer.STATE_CONNECTED:
            _snapshot.rpc_id(peer, data, _revision)

@rpc("authority", "call_remote", "reliable", 2)
func _snapshot(data: Dictionary, revision: int) -> void:
    if multiplayer.is_server() or local_character_id.is_empty() or revision <= _received_revision:
        return
    _received_revision = revision
    latest_snapshot = data
    world.progression = data.progression.duplicate(true)
    # The host's seed lays out deposits, the trial stone and decorations locally.
    var seed: int = LAYOUT.seed_of(data.get("meta", {}))
    if seed != world.layout.seed:
        world.apply_layout(seed, false)
    var wanted: Dictionary = {}
    for id in data.players:
        wanted[id] = true
        var actor = world.player_by_id(id)
        if actor == null:
            actor = load("res://scenes/player/player.tscn").instantiate()
            actor.name = "Character_" + id
            actor.character_id = id
            actor.local_controlled = id == local_character_id
            world.add_child(actor)
            actor.configure_replica()
    CODEC.apply_entities(world, data, true)
    for id in data.players:
        CODEC.apply_player(world.player_by_id(id), data.players[id], world, true)
    for actor in world.get_children():
        if actor.is_in_group("player") and not wanted.has(actor.character_id):
            world.remove_child(actor)
            actor.queue_free()
    var local = world.player_by_id(local_character_id)
    if local:
        world.bind_local_player(local)

func _peer_disconnected(peer: int) -> void:
    if not active or not multiplayer.is_server() or not owners.has(peer):
        return
    var id: String = owners[peer]
    var actor = world.player_by_id(id)
    if actor:
        if actor.get_node("Absorption").active:
            actor.get_node("Absorption")._cancel("Analysis interrupted by disconnection.")
        records[id] = CODEC.capture_player(actor).merged({"token_hash": records[id].token_hash})
        world.remove_child(actor)
        actor.queue_free()
    owners.erase(peer)
    _action_budgets.erase(peer)
    save_world()
    _broadcast()

func _process(delta: float) -> void:
    if not active:
        return
    if _join_deadline > 0 and Time.get_ticks_msec() > _join_deadline:
        _fail("Connection timed out or the session is full.")
        return
    if not multiplayer.is_server() or not is_instance_valid(world):
        return
    _snapshot_time += delta
    _save_time += delta
    if _snapshot_time >= 0.05:
        _snapshot_time = 0.0
        _broadcast()
    if _save_time >= 15.0:
        _save_time = 0.0
        if save_world() != OK:
            world._announce("Autosave failed. Use F9 to retry; the previous save is retained.")

func stop_session(save: bool = true) -> void:
    if active and save and multiplayer.is_server():
        save_world()
    active = false
    listening = false
    world_meta = {}
    _join_deadline = 0
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    owners.clear()

func _fail(message: String) -> void:
    stop_session(false)
    if replica_world and is_instance_valid(world):
        world.get_local_player().input_blocked = true
        world.get_local_player().local_controlled = false
    session_failed.emit(message)
    if is_instance_valid(world):
        world._announce(message)

func _close_requested() -> void:
    stop_session(true)
    get_tree().quit()
