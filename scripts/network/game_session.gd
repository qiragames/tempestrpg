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
## A new character's name (character-first start screen), sent with the join request.
var join_name: String = ""
## The name for a new world's own character (set by the title menu before start_host).
var host_name: String = ""
const NAMES := preload("res://scripts/progression/character_names.gd")
var joining_address := ""
var world_meta: Dictionary = {}
## A world chosen in the title menu, started once the game scene is ready.
var pending_launch: Dictionary = {}
const TITLE_SCENE := "res://scenes/menu/title_menu.tscn"
## --- Server mode (user request): a console server hosts a world without a character of its
## own; the world's owner joins from the same computer (127.0.0.1) and plays the host character,
## recognised by a key kept on this computer. Friends join as usual. UPnP asks the router to open
## the port and finds the public address.
var server_mode := false
const OWNER_KEY_PATH := "user://server/owner.key"
var _owner_key := ""
var _upnp: UPNP
var _upnp_thread: Thread
## The address friends use over the Internet ("" until UPnP found it).
var public_address := ""
var upnp_status := ""
## --- Join codes (user request): hosting and joining through routers without opening ports.
const CODES := preload("res://scripts/network/join_codes.gd")
## M10 (user decision): invite codes are the only way to play together; a guest may bring their own
## character when the world's owner allows it (world meta "imports"), see character_import.gd.
const IMPORT := preload("res://scripts/network/character_import.gd")
## Guest: the own world whose character was brought along ("" for a character of this world).
var import_path := ""
## Guest: waiting for the host's last copy of the character before leaving.
var _leaving := false
signal character_synced
signal reply_code_ready(code: String)
## A short invite code's answer went out by itself: the friend only waits (no reply code).
signal relay_joining
const RELAY_SCRIPT := preload("res://scripts/network/code_relay.gd")
## How long a short invite listens for its friend's answer.
const RELAY_LISTEN_SECONDS := 900.0
var relay: Node

func _relay() -> Node:
    if relay == null:
        relay = RELAY_SCRIPT.new()
        relay.name = "CodeRelay"
        add_child(relay)
    return relay
var code_mode := false
var _rtc: WebRTCMultiplayerPeer
var _invites: Dictionary = {}
var _next_invite := 2
## A joining friend's reply code (to send back to the host).
var reply_code := ""
## Minutes a friend waits for the host to paste their reply.
const CODE_WAIT_MS := 600000
## The extra channels the RPCs use (1: movement, unreliable ordered; 2: snapshots, reliable).
const CODE_CHANNELS := [MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, MultiplayerPeer.TRANSFER_MODE_RELIABLE]
const WORLD_SCENE := "res://scenes/world/forest.tscn"

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    # Saves live in the game's own folder (%APPDATA%\TempestRPG); earlier versions' saves are
    # copied over once on the first start.
    var copied: int = preload("res://scripts/persistence/save_folder.gd").adopt_previous()
    if copied > 0:
        print("Copied %d save files from the previous save folder." % copied)
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
    # M10: joining by address and the console server are gone from the game; developer builds
    # (the editor, the network tests) keep them as a test harness.
    if not OS.is_debug_build() and (options.has("server") or options.has("host") or options.has("join")):
        return
    if options.has("server"):
        var path: String = options.get("save", "")
        if path.is_empty():
            var worlds: Array = preload("res://scripts/menu/world_registry.gd").list().filter(func(entry): return entry.ok)
            path = worlds[0].path if not worlds.is_empty() else save_path
        pending_launch = {"mode": "server", "port": int(options.get("port", DEFAULT_PORT)), "path": path, "upnp": not options.has("no-upnp")}
        server_mode = true
        get_tree().change_scene_to_file(WORLD_SCENE)
        return
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
    join_name = NAMES.clean(String(launch.get("name", "")))
    host_name = join_name
    if launch.mode == "join_code":
        import_path = String(launch.get("import", ""))
        join_with_code(launch.code, identity_path, launch.get("race", RACES.DEFAULT))
        return
    if launch.mode == "server":
        start_server(launch.get("port", DEFAULT_PORT), launch.path, launch.get("upnp", true))
        return
    if launch.mode == "host":
        start_host(launch.get("port", DEFAULT_PORT), launch.path, launch.get("listen", false), launch.get("meta", {}), launch.get("race", RACES.DEFAULT))
    else:
        join_host(launch.address, launch.get("port", DEFAULT_PORT), launch.get("identity", identity_path), launch.get("race", RACES.DEFAULT))

## Leave the current world (saving when hosting) and return to the title menu.
func quit_to_title() -> Error:
    # A guest with their own character takes its latest state home first (briefly).
    if active and replica_world and not import_path.is_empty() and not local_character_id.is_empty() and not _leaving:
        _leaving = true
        _request_sync.rpc_id(1)
        var waited := 0.0
        while waited < 2.0 and _leaving:
            await get_tree().create_timer(0.1, true, false, true).timeout
            waited += 0.1
        _leaving = false
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
        if not host_name.is_empty():
            host_actor.progression["name"] = host_name
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
    world._announce("Hosting for up to 8 players on UDP %d. F9 saves." % port if listening else "World \"%s\" loaded. Esc: pause menu — switch on Multiplayer to invite friends." % world_meta.name)
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

## Host a world as a console server: listen, park the host character until its owner joins,
## open the router's port (UPnP) and say how to join.
func start_server(port: int, path: String, upnp: bool = true) -> Error:
    server_mode = true
    _owner_key = owner_key(true)
    var error := start_host(port, path, false)
    if error != OK:
        _log("Could not load the world %s." % path)
        return error
    # A server takes up no player place: eight characters can join.
    var peer := ENetMultiplayerPeer.new()
    error = peer.create_server(port, MAX_PLAYERS)
    if error != OK:
        _log("Could not open UDP port %d. Is another game or server using it?" % port)
        return error
    multiplayer.multiplayer_peer = peer
    listening = true
    listen_port = port
    owners.erase(1)
    local_character_id = ""
    _park_host(true)
    _log("TempestRPG server · world \"%s\" (%s) · UDP %d" % [world_meta.get("name", "?"), path, port])
    _log("You (on this PC): start the game, Join a Friend, address 127.0.0.1 — you play your own character.")
    _log("Friends on your network: %s" % (", ".join(lan_addresses()) if not lan_addresses().is_empty() else "your LAN address"))
    if upnp:
        open_router_port(port)
    save_world()
    return OK

## This computer's server owner key (created once by the server).
static func owner_key(create: bool = false) -> String:
    if FileAccess.file_exists(OWNER_KEY_PATH):
        var text := FileAccess.get_file_as_string(OWNER_KEY_PATH).strip_edges()
        if text.length() == 64:
            return text
    if not create:
        return ""
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OWNER_KEY_PATH).get_base_dir())
    var key := Crypto.new().generate_random_bytes(32).hex_encode()
    var file := FileAccess.open(OWNER_KEY_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(key)
        file.close()
    return key

## The host character waits (hidden, untouchable, not in the world's player list) while its owner
## is away; it comes back when the owner joins.
func _park_host(parked: bool) -> void:
    var actor = world.get_local_player()
    if parked:
        actor.remove_from_group("player")
        actor.visible = false
        actor.process_mode = Node.PROCESS_MODE_DISABLED
        actor.set_deferred("collision_layer", 0)
    else:
        actor.add_to_group("player")
        actor.visible = true
        actor.process_mode = Node.PROCESS_MODE_INHERIT
        actor.set_deferred("collision_layer", 2)

func _log(message: String) -> void:
    print("[%s] %s" % [Time.get_time_string_from_system(), message])

## Ask the router to forward the UDP port (UPnP) and find the public address, in the background.
func open_router_port(port: int) -> void:
    # Automated test runs (headless, not a server) never touch the router.
    if _upnp_thread != null or (DisplayServer.get_name() == "headless" and not server_mode):
        return
    upnp_status = "Asking your router to open UDP %d…" % port
    _upnp_thread = Thread.new()
    _upnp_thread.start(func():
        var upnp := UPNP.new()
        var found := upnp.discover(2000, 2, "InternetGatewayDevice")
        var result := ""
        var address := ""
        if found != UPNP.UPNP_RESULT_SUCCESS or upnp.get_gateway() == null or not upnp.get_gateway().is_valid_gateway():
            result = "Your router did not answer (UPnP off?). Forward UDP %d to this PC by hand for friends outside your network." % port
        elif upnp.add_port_mapping(port, port, "TempestRPG", "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS:
            result = "Your router refused to open UDP %d. Forward it to this PC by hand." % port
        else:
            address = upnp.query_external_address()
            if address.is_empty():
                result = "Port opened, but the router did not tell the public address. Look it up (e.g. \"what is my IP\")."
            elif _shared_address(address):
                result = "Port opened, but your router's address %s is shared by your provider (CGNAT): friends outside cannot reach you without a VPN-style tool." % address
                address = ""
            else:
                result = "Port opened. Friends on the Internet join with: %s" % address
        _upnp_done.call_deferred(upnp, address, result)
    )

func _upnp_done(upnp: UPNP, address: String, result: String) -> void:
    if _upnp_thread != null:
        _upnp_thread.wait_to_finish()
    _upnp_thread = null
    _upnp = upnp if not address.is_empty() or result.begins_with("Port opened") else null
    public_address = address
    upnp_status = result
    _log(result)
    if is_instance_valid(world) and not server_mode:
        world._announce(result)

static func _shared_address(address: String) -> bool:
    var parts := address.split(".")
    if parts.size() != 4:
        return false
    var a := int(parts[0])
    var b := int(parts[1])
    return a == 10 or (a == 100 and b >= 64 and b <= 127) or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168)

func _close_router_port() -> void:
    if _upnp != null:
        _upnp.delete_port_mapping(listen_port, "UDP")
        _upnp = null

## Host: accept friends through join codes instead of a port (WebRTC; no router settings).
func open_with_codes() -> Error:
    if not active or replica_world or listening or not multiplayer.is_server():
        return ERR_UNAVAILABLE
    if CODES.connection() == null:
        world._announce("Join codes need the WebRTC plugin (addons/webrtc_native).")
        return ERR_UNAVAILABLE
    _rtc = WebRTCMultiplayerPeer.new()
    var error := _rtc.create_server(CODE_CHANNELS)
    if error != OK:
        return error
    multiplayer.multiplayer_peer = _rtc
    listening = true
    code_mode = true
    _invites.clear()
    save_world()
    world._announce("Multiplayer is on: Invite a Friend makes one code per friend.")
    return OK

## Host: stop playing together — friends leave (their characters are saved here, and those who
## brought their own get it back first), the world goes on single player.
func close_multiplayer() -> Error:
    if not active or replica_world or not code_mode or not multiplayer.is_server():
        return ERR_UNAVAILABLE
    _sync_characters()
    for peer in owners.keys():
        if peer != 1:
            _peer_disconnected(peer)
    if _rtc != null:
        _rtc.close()
        _rtc = null
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    listening = false
    code_mode = false
    _invites.clear()
    save_world()
    world._announce("Multiplayer is off: your world is single player again.")
    return OK

## Host: whether guests may bring their own characters (saved with the world).
func set_imports(allowed: bool) -> void:
    if not active or replica_world or not multiplayer.is_server():
        return
    world_meta["imports"] = allowed
    save_world()

## Host: every guest gets the current state of their character (kept by those who brought their own).
func _sync_characters() -> void:
    for peer in owners:
        var id: String = owners[peer]
        if id == "host" or peer == 1 or not _peer_ready(peer):
            continue
        var actor = world.player_by_id(id)
        if actor != null:
            _character_sync.rpc_id(peer, IMPORT.carried(CODEC.capture_player(actor)))

@rpc("any_peer", "call_remote", "reliable")
func _request_sync() -> void:
    var peer := multiplayer.get_remote_sender_id()
    if active and multiplayer.is_server() and owners.has(peer) and owners[peer] != "host":
        var actor = world.player_by_id(owners[peer])
        if actor != null:
            _character_sync.rpc_id(peer, IMPORT.carried(CODEC.capture_player(actor)))

## Guest: the host's copy of this character; one brought from an own world is written back there.
@rpc("authority", "call_remote", "reliable")
func _character_sync(travelling: Dictionary) -> void:
    _leaving = false
    if import_path.is_empty() or not replica_world:
        return
    if IMPORT.write_back(import_path, travelling) != OK:
        world._announce("Could not update your character in your own world; it is kept safe in your friend's world.")
    character_synced.emit()

## Host: a new invite code for one friend ("" if full or unavailable). Takes a few seconds.
func create_invite() -> String:
    if not code_mode or owners.size() + _invites.size() >= MAX_PLAYERS:
        return ""
    var id := _next_invite
    _next_invite += 1
    var link := CODES.connection()
    if link == null or _rtc.add_peer(link, id) != OK:
        return ""
    _invites[id] = link
    link.create_offer()
    await _gather(link)
    var long_code := CODES.code_for(link, id)
    if long_code.is_empty():
        return ""
    # User request: one short code, no reply. The offer waits on the relay under the short code
    # and the friend's answer comes back the same way (else the long two-step code still works).
    var short := RELAY_SCRIPT.new_code()
    if await _relay().post(short, "offer", long_code):
        _listen_for_answer(short, id)
        return short
    return long_code

## Host: apply a short invite's answer as soon as the friend's game sends it.
func _listen_for_answer(short: String, id: int) -> void:
    var answer: String = await _relay().wait_for(short, "answer", RELAY_LISTEN_SECONDS, 3.0)
    if answer.is_empty() or not code_mode or not _invites.has(id):
        return
    if accept_reply(answer) and is_instance_valid(world):
        world._announce("A friend is joining with your invite code…")

## Host: a friend's reply code completes their invite.
func accept_reply(code: String) -> bool:
    var data := CODES.decode(code)
    if data.is_empty() or data.type != "answer" or not _invites.has(int(data.id)):
        return false
    CODES.apply(_invites[int(data.id)], data)
    _invites.erase(int(data.id))
    return true

## Friend: join with the host's invite code; the reply code to send back comes after a moment
## (also through `reply_code_ready`).
func join_with_code(code: String, profile: String = "user://profiles/characters.json", race: String = RACES.DEFAULT) -> String:
    # A short code: fetch the host's offer from the relay first.
    var short := ""
    if RELAY_SCRIPT.is_short(code):
        short = code
        if is_instance_valid(world):
            world._announce("Looking up the invite code…")
        code = await _relay().wait_for(short, "offer", 20.0)
        if code.is_empty():
            _fail("Could not find that invite code (it may be old, mistyped, or the internet relay is unreachable). Ask your friend for a new code.")
            return ""
    var data := CODES.decode(code)
    if active or not is_instance_valid(world) or data.is_empty() or data.type != "offer":
        _fail("That is not a valid invite code.")
        return ""
    _rtc = WebRTCMultiplayerPeer.new()
    if _rtc.create_client(int(data.id), CODE_CHANNELS) != OK:
        _fail("Could not start a code connection.")
        return ""
    var link := CODES.connection()
    if link == null or _rtc.add_peer(link, 1) != OK:
        _fail("Join codes need the WebRTC plugin (addons/webrtc_native).")
        return ""
    identity_path = profile
    join_race = race
    joining_address = "code"
    replica_world = true
    multiplayer.multiplayer_peer = _rtc
    active = true
    code_mode = true
    Engine.max_fps = 60
    local_character_id = ""
    _join_deadline = Time.get_ticks_msec() + CODE_WAIT_MS
    world.get_local_player().local_controlled = false
    for actor in world.get_children():
        if actor.is_in_group("player"):
            actor.configure_replica()
        elif actor.is_in_group("enemies") or actor.is_in_group("magicule_pickups"):
            actor.set_physics_process(false)
            if actor.has_node("Health"):
                actor.get_node("Health").set_process(false)
    CODES.apply(link, data)
    await _gather(link)
    reply_code = CODES.code_for(link, int(data.id))
    if not short.is_empty() and not reply_code.is_empty() and await _relay().post(short, "answer", reply_code):
        world._announce("Connecting to your friend…")
        relay_joining.emit()
        return reply_code
    reply_code_ready.emit(reply_code)
    return reply_code

func _gather(link: WebRTCPeerConnection) -> void:
    var waited := 0.0
    while waited < CODES.GATHER_SECONDS and (link.get_gathering_state() != WebRTCPeerConnection.GATHERING_STATE_COMPLETE or link.get_meta("description", []).is_empty()):
        # The connection reports its description and candidates only when polled.
        link.poll()
        await get_tree().create_timer(0.1, true, false, true).timeout
        waited += 0.1

## Whether a connected peer can take a snapshot right now (ENet or WebRTC).
func _peer_ready(peer: int) -> bool:
    var transport := multiplayer.multiplayer_peer
    if transport is ENetMultiplayerPeer:
        return transport.get_peer(peer).get_state() == ENetPacketPeer.STATE_CONNECTED
    if transport is WebRTCMultiplayerPeer:
        return transport.has_peer(peer) and transport.get_peer(peer).get("connected", false)
    return true

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
    open_router_port(port)
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
    joining_address = address
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
    # Server mode: joining your own server on this computer plays the world's host character.
    var key := owner_key()
    if profile.is_empty() and not key.is_empty() and joining_address in ["127.0.0.1", "localhost", "::1"]:
        profile = {"character": "host", "credential": key}
    if not profile.get("character", "") is String or not profile.get("credential", "") is String:
        _fail("Character profile fields are invalid.")
        return
    # M10: a character brought from one of this computer's own worlds.
    var bring: Dictionary = IMPORT.load_carried(import_path) if not import_path.is_empty() else {}
    if not import_path.is_empty() and bring.is_empty():
        _fail("Your character's world could not be read.")
        return
    _join_world.rpc_id(1, profile.get("character", ""), profile.get("credential", ""), join_race, bring, join_name)

@rpc("any_peer", "call_remote", "reliable")
func _join_world(character: String, credential: String, race: String, bring: Dictionary = {}, name: String = "") -> void:
    if not active or not multiplayer.is_server():
        return
    var peer := multiplayer.get_remote_sender_id()
    if owners.has(peer):
        return
    if not bring.is_empty() and not bool(world_meta.get("imports", false)):
        _deny(peer, "This world's owner allows only new characters. Join again with a new character.")
        return
    if owners.size() >= MAX_PLAYERS:
        _deny(peer, "The eight-player session is full.")
        return
    # Server mode: the owner's key (this computer) plays the host character; anyone else asking
    # for it (or a second game on this computer while the owner plays) gets a new character.
    if character == "host" and (not server_mode or _owner_key.is_empty() or credential != _owner_key or owners.values().has("host")):
        character = ""
        credential = ""
    if character == "host":
        var owner_actor = world.get_local_player()
        _park_host(false)
        owner_actor.local_controlled = false
        owner_actor.network_controlled = true
        owners[peer] = "host"
        _wire_remote(owner_actor)
        player_joined.emit(owner_actor)
        _accepted.rpc_id(peer, "host", credential)
        _log("The owner joined (host character).")
        save_world()
        _broadcast()
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
    if not records.has(character):
        actor.choose_race(String(bring.get("progression", {}).get("race", race)) if not bring.is_empty() else race)
        # A new character's name (a brought character keeps its own).
        if bring.is_empty() and NAMES.valid(name):
            actor.progression["name"] = name
        records[character] = CODEC.capture_player(actor)
        records[character]["token_hash"] = (world_id + credential).sha256_text()
    if not bring.is_empty():
        # Their own character: what travels replaces this world's copy; the world's parts stay.
        var brought: Dictionary = IMPORT.merged(records[character], bring)
        brought["id"] = character
        brought.erase("token_hash")
        if not STORE.validate_player(brought, character):
            world.remove_child(actor)
            actor.queue_free()
            _deny(peer, "Your character could not be brought into this world.")
            return
        brought["token_hash"] = records[character].token_hash
        records[character] = brought
    CODEC.apply_player(actor, records[character], world, false)
    owners[peer] = character
    _wire_remote(actor)
    player_joined.emit(actor)
    _accepted.rpc_id(peer, character, credential)
    if server_mode:
        _log("%s joined (%d online)." % [character.left(16), owners.size()])
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

func send_move(direction: Vector2, sprint: bool = false, aim: Vector2 = Vector2.ZERO) -> void:
    if active and not multiplayer.is_server() and not local_character_id.is_empty():
        _move_input.rpc_id(1, direction, sprint, aim)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _move_input(direction: Vector2, sprint: bool = false, aim: Vector2 = Vector2.ZERO) -> void:
    if not multiplayer.is_server():
        return
    var peer := multiplayer.get_remote_sender_id()
    if not owners.has(peer) or not is_finite(direction.x) or not is_finite(direction.y) or absf(direction.x) > 1 or absf(direction.y) > 1:
        rejected_requests += 1
        return
    var actor = world.player_by_id(owners[peer])
    if actor:
        actor.remote_direction = direction.limit_length(1.0)
        actor.remote_sprint = sprint == true
        # User request: the character faces the guest's mouse.
        actor.remote_aim = aim.normalized() if is_finite(aim.x) and is_finite(aim.y) and aim.length() > 0.1 and aim.length() <= 1.5 else Vector2.ZERO
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
    if action == "title":
        # M9e: wear an unlocked achievement's title ("" for none).
        if payload.size() != 1 or not payload.get("id") is String or payload.id.length() > 48:
            rejected_requests += 1
            return false
        return world.quests.wear_title(actor, payload.id)
    if action == "quest":
        # M9c: clients name a quest to take or someone to talk to; the host checks the rest.
        if payload.size() != 2 or not payload.get("operation") in ["accept", "talk", "choose"] or not payload.get("id") is String or payload.id.length() > 48:
            rejected_requests += 1
            return false
        if payload.operation == "choose":
            return world.quests.choose(actor, payload.id)
        return world.quests.accept(actor, payload.id) if payload.operation == "accept" else world.quests.talk(actor, payload.id)
    if action == "dungeon":
        # M7c: clients name the cave; the host checks the distance.
        # M11b: levers, the vault and the mode (Heroic) chosen at the cave mouth.
        if payload.size() < 2 or payload.size() > 3 or not payload.get("operation") in ["enter", "leave", "lever", "vault"] or not payload.get("id") is String or payload.id.length() > 32:
            rejected_requests += 1
            return false
        match payload.operation:
            "enter":
                if payload.size() == 3 and not payload.get("heroic") is bool:
                    rejected_requests += 1
                    return false
                return world.dungeon_gates.enter(actor, payload.id, bool(payload.get("heroic", false)))
            "leave":
                return world.dungeon_gates.leave(actor, payload.id)
            "lever":
                if payload.size() != 3 or not (payload.get("index") is int or payload.get("index") is float):
                    rejected_requests += 1
                    return false
                return world.dungeon_features.pull(actor, payload.id, int(payload.index))
        return world.dungeon_features.open_vault(actor, payload.id)
    if action == "craft":
        # M6c: clients name a recipe; the host checks the station, ingredients and bag.
        if payload.size() != 1 or not payload.get("id") is String or payload.id.length() > 64:
            rejected_requests += 1
            return false
        # Crafting happens from the professions window (menus block movement, not crafting).
        return actor.craft(payload.id)
    if action == "node":
        # M6a: clients name a tree or ore rock (its prop plan index); the host checks reach and stock.
        if payload.size() != 1 or not (payload.get("index") is int or payload.get("index") is float) or float(payload.index) != floor(float(payload.index)):
            rejected_requests += 1
            return false
        return false if actor.input_blocked else actor.start_node(int(payload.index))
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
        if operation == "sell" and payload.size() == 4 and payload.get("merchant") is String and payload.merchant.length() <= 32 and payload.get("kind") in ["gear", "bag", "bag_all"] and payload.get("id") is String and payload.id.length() <= 64:
            return world.trade.sell(actor, payload.merchant, payload.kind, payload.id)
        rejected_requests += 1
        return false
    if action == "harbour":
        # M4.5d: tickets, passes, ships, invitations and voyages; the host checks the rest.
        var operation: Variant = payload.get("operation")
        var here: Variant = payload.get("harbour", "")
        var target: Variant = payload.get("to", payload.get("guest", ""))
        if not operation in ["ticket", "pass", "ship", "summon", "invite", "accept", "sail"] or not here is String or here.length() > 32 or not target is String or target.length() > 64 or payload.size() > 3:
            rejected_requests += 1
            return false
        match operation:
            "ticket":
                return world.harbours.buy_ticket(actor, here, target)
            "pass":
                return world.harbours.buy_pass(actor, here)
            "ship":
                return world.harbours.buy_ship(actor, here)
            "summon":
                return world.harbours.summon(actor, here)
            "invite":
                return world.harbours.invite(actor, here, target)
            "accept":
                return world.harbours.accept(actor)
            "sail":
                return world.harbours.sail(actor, here, target)
        return false
    if action == "class":
        # M12b: choose or change a class or subclass, or reset attributes, at the old master.
        if payload.size() != 3 or not payload.get("operation") in ["choose", "reset"] or not payload.get("slot") is String or not payload.get("id") is String or payload.id.length() > 32:
            rejected_requests += 1
            return false
        if payload.operation == "reset":
            return world.class_master.reset_attributes(actor)
        return world.class_master.choose(actor, payload.slot, payload.id)
    if action == "attribute":
        # M12a: spend one point (the host checks the points left).
        if payload.size() != 1 or not payload.get("key") is String:
            rejected_requests += 1
            return false
        return actor.spend_attribute(payload.key)
    if action == "storage":
        # Storage: rent a city box, put in, take out (the host checks where you stand and room).
        if payload.size() != 4 or not payload.get("operation") in ["buy", "put", "take"] or not payload.get("where") is String or payload.where.length() > 32 or not payload.get("item") is String or payload.item.length() > 64 or not (payload.get("count") is int or payload.get("count") is float):
            rejected_requests += 1
            return false
        match payload.operation:
            "buy":
                return world.storage.buy(actor, payload.where)
            "put":
                return world.storage.put(actor, payload.where, payload.item, clampi(int(payload.count), 1, 10000))
        return world.storage.take(actor, payload.where, payload.item, clampi(int(payload.count), 1, 10000))
    if action == "army":
        # M11h: recruit, command or send home your soldiers.
        match payload.get("operation"):
            "recruit", "dismiss":
                if payload.size() != 1:
                    rejected_requests += 1
                    return false
                return world.army.recruit(actor) if payload.operation == "recruit" else world.army.dismiss(actor)
            "command":
                if payload.size() != 2 or not payload.get("order") is String:
                    rejected_requests += 1
                    return false
                return world.army.command(actor, payload.order)
        rejected_requests += 1
        return false
    if action == "pet":
        # M11f: hatch an egg or choose the pet that follows you.
        match payload.get("operation"):
            "hatch":
                if payload.size() != 1:
                    rejected_requests += 1
                    return false
                return world.pets.use_egg(actor)
            "choose":
                if payload.size() != 2 or not payload.get("id") is String or payload.id.length() > 32:
                    rejected_requests += 1
                    return false
                return world.pets.choose(actor, payload.id)
        rejected_requests += 1
        return false
    if action == "event":
        # M11d: collecting a meteorite (the host checks the distance).
        if payload.size() != 2 or payload.get("operation") != "collect" or not (payload.get("index") is int or payload.get("index") is float):
            rejected_requests += 1
            return false
        return world.events.collect(actor, int(payload.index))
    if action == "exchange":
        # M11c: trading between players; the host checks distance, ownership and room.
        var operation: Variant = payload.get("operation")
        match operation:
            "request":
                if payload.size() != 2 or not payload.get("who") is String or payload.who.length() > 64:
                    rejected_requests += 1
                    return false
                return world.exchange.request(actor, payload.who)
            "accept", "decline", "cancel":
                if payload.size() != 1:
                    rejected_requests += 1
                    return false
                return world.exchange.accept(actor) if operation == "accept" else (world.exchange.decline(actor) if operation == "decline" else world.exchange.cancel(actor))
            "offer":
                if payload.size() != 2 or not payload.get("offer") is Dictionary:
                    rejected_requests += 1
                    return false
                return world.exchange.offer(actor, payload.offer)
            "ready":
                if payload.size() != 2 or not payload.get("value") is bool:
                    rejected_requests += 1
                    return false
                return world.exchange.mark_ready(actor, payload.value)
        rejected_requests += 1
        return false
    if action == "housing":
        # M16: doors, furniture, resting and inn rooms; the host checks the rest.
        var housing_operation: Variant = payload.get("operation")
        var what: Variant = payload.get("id", "")
        if not housing_operation in ["enter", "leave", "place", "remove", "rest", "rent", "enter_room"] or not what is String or what.length() > 64 or payload.size() > 2:
            rejected_requests += 1
            return false
        match housing_operation:
            "enter":
                return world.housing.enter_house(actor, what)
            "leave":
                return world.housing.leave(actor)
            "place":
                return world.housing.place(actor, what)
            "remove":
                return what.is_valid_int() and world.housing.remove(actor, int(what))
            "rest":
                return world.housing.rest(actor)
            "rent":
                return world.housing.rent_room(actor, what)
            "enter_room":
                return world.housing.enter_room(actor)
        return false
    if action == "duel":
        # M15: challenge, answer or give up; the host checks the rest.
        var duel_operation: Variant = payload.get("operation")
        var rival: Variant = payload.get("id", "")
        if not duel_operation in ["challenge", "accept", "decline", "forfeit"] or not rival is String or rival.length() > 64 or payload.size() > 2:
            rejected_requests += 1
            return false
        match duel_operation:
            "challenge":
                return world.duels.challenge(actor, rival)
            "accept":
                return world.duels.accept(actor)
            "decline":
                return world.duels.decline(actor)
            "forfeit":
                return world.duels.forfeit(actor)
        return false
    if action == "chat":
        # M14a: a line for the world, your guild or your party.
        if payload.size() != 2 or not payload.get("channel") is String or not payload.get("text") is String or payload.text.length() > 200:
            rejected_requests += 1
            return false
        return world.chat.say(actor, payload.channel, payload.text)
    if action == "guild":
        # M14a: founding, invitations, ranks and leaving; the host checks the rest.
        var guild_operation: Variant = payload.get("operation")
        var member: Variant = payload.get("id", "")
        if not guild_operation in ["found", "invite", "accept", "decline", "leave", "kick", "promote", "demote", "transfer", "disband", "put", "take", "zeni", "withdraw"] or not member is String or member.length() > 64:
            rejected_requests += 1
            return false
        if guild_operation in ["put", "take", "zeni"]:
            # M14b: the bank at a guild hall: an item id and a count (zeni: + deposit, - withdraw).
            if payload.size() != 3 or not (payload.get("count") is int or payload.get("count") is float) or absi(int(payload.count)) > 10000000:
                rejected_requests += 1
                return false
            if guild_operation == "put":
                return world.guilds.bank_put(actor, member, int(payload.count))
            if guild_operation == "take":
                return world.guilds.bank_take(actor, member, int(payload.count))
            return world.guilds.bank_zeni(actor, int(payload.count))
        if guild_operation == "withdraw":
            return payload.size() == 2 and world.guilds.set_withdraw(actor, member)
        if guild_operation == "found":
            if payload.size() != 5 or not payload.get("name") is String or not payload.get("tag") is String or not (payload.get("emblem") is int or payload.get("emblem") is float) or payload.name.length() > 40 or payload.tag.length() > 8:
                rejected_requests += 1
                return false
            return world.guilds.found(actor, payload.name, payload.tag, int(payload.emblem))
        if payload.size() > 2:
            rejected_requests += 1
            return false
        match guild_operation:
            "invite":
                return world.guilds.invite(actor, member)
            "accept":
                return world.guilds.accept(actor)
            "decline":
                return world.guilds.decline(actor)
            "leave":
                return world.guilds.leave(actor)
            "kick":
                return world.guilds.kick(actor, member)
            "promote":
                return world.guilds.set_rank(actor, member, true)
            "demote":
                return world.guilds.set_rank(actor, member, false)
            "transfer":
                return world.guilds.transfer(actor, member)
            "disband":
                return world.guilds.disband(actor)
        return false
    if action == "party":
        # M4.6: invitations, membership and revives; the host checks the rest.
        var party_operation: Variant = payload.get("operation")
        var who: Variant = payload.get("id", "")
        if not party_operation in ["invite", "accept", "decline", "leave", "kick", "revive"] or not who is String or who.length() > 64 or payload.size() > 2:
            rejected_requests += 1
            return false
        match party_operation:
            "invite":
                return world.party.invite(actor, who)
            "accept":
                return world.party.accept(actor)
            "decline":
                return world.party.decline(actor)
            "leave":
                return world.party.leave(actor)
            "kick":
                return world.party.kick(actor, who)
            "revive":
                return world.party.revive(actor, who)
        return false
    if action == "realm":
        # M4.7: clients name a hermit answer, a mentor, an orb or a wish; the host checks the rest.
        var realm_operation: Variant = payload.get("operation")
        var what: Variant = payload.get("id", "")
        if not realm_operation in ["answer", "leave", "learn", "orb", "wish", "enter"] or not what is String or what.length() > 32 or payload.size() > 2:
            rejected_requests += 1
            return false
        if actor.input_blocked:
            return false
        match realm_operation:
            "answer":
                return what.is_valid_int() and world.realm.answer_hermit(actor, int(what))
            "leave":
                return world.realm.leave_realm(actor)
            "learn":
                return world.realm.learn(actor, what)
            "orb":
                return what.is_valid_int() and world.realm.take_orb(actor, int(what))
            "wish":
                return world.realm.wish(actor, what)
            "enter":
                return world.realm.enter_tournament(actor)
        return false
    if action == "aura":
        if payload.size() != 1 or payload.get("operation") != "toggle":
            rejected_requests += 1
            return false
        return actor.toggle_aura()
    if action == "fish":
        if payload.size() != 1 or not payload.get("operation") in ["cast", "reel"]:
            rejected_requests += 1
            return false
        return actor.cast_line() if payload.operation == "cast" else actor.reel_in()
    if action == "mount":
        var mount_operation: Variant = payload.get("operation")
        if mount_operation == "toggle" and payload.size() <= 2 and payload.get("id", "") is String and String(payload.get("id", "")).length() <= 32:
            return actor.toggle_mount(String(payload.get("id", "")))
        if mount_operation == "tame" and payload.size() == 2 and payload.get("id") is String and payload.id.length() <= 32:
            return actor.tame(payload.id)
        rejected_requests += 1
        return false
    if action == "use_item":
        if payload.size() != 1 or not payload.get("id") is String or payload.id.length() > 64:
            rejected_requests += 1
            return false
        return actor.use_good(payload.id)
    if action == "teleport":
        # User request: a city's teleport scroll (the host checks the scroll and runs the cast).
        if payload.size() != 1 or not payload.get("to") is String or payload.to.length() > 32:
            rejected_requests += 1
            return false
        return actor.start_teleport(payload.to)
    if action == "drop_item":
        # User request: drop bag things at your feet.
        if payload.size() != 2 or not payload.get("id") is String or payload.id.length() > 64 or not (payload.get("count") is int or (payload.get("count") is float and payload.count == floor(payload.count))) or int(payload.count) < 1 or int(payload.count) > 1000:
            rejected_requests += 1
            return false
        return world.drop_from_bag(actor, payload.id, int(payload.count))
    if action == "loot":
        # SVE feedback: F picks up nearby loot; the host checks reach, claim and room.
        if payload.size() != 1 or not payload.get("id") is String or payload.id.length() > 64:
            rejected_requests += 1
            return false
        return false if actor.input_blocked else world.take_loot(actor, payload.id)
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
        # User request: salvage gear into materials.
        if operation == "salvage" and payload.size() == 2 and payload.get("id") is String and payload.id.length() <= 64:
            return actor.salvage(payload.id)
        if operation == "salvage_common" and payload.size() == 1:
            return actor.salvage_common() > 0
        # User request: drop a loose piece at your feet.
        if operation == "drop" and payload.size() == 2 and payload.get("id") is String and payload.id.length() <= 64:
            return world.drop_gear_item(actor, payload.id)
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
        # Wish orbs cannot be thrown away (they only return to the realm through a wish).
        if preload("res://scripts/realm/realm_catalogue.gd").is_orb(payload.id):
            return false
        return actor.get_node("Inventory").discard(StringName(payload.id))
    if actor.input_blocked or actor.is_exhausted():
        return false
    # User request: strikes, skills and dashes go where the mouse points ({"aim": [x, y]}).
    var aim := Vector2.ZERO
    if payload.size() == 1 and payload.get("aim") is Array and payload.aim.size() == 2 and (payload.aim[0] is float or payload.aim[0] is int) and (payload.aim[1] is float or payload.aim[1] is int):
        aim = Vector2(float(payload.aim[0]), float(payload.aim[1]))
        if not is_finite(aim.x) or not is_finite(aim.y) or aim.length() < 0.1 or aim.length() > 1.5:
            rejected_requests += 1
            return false
        aim = aim.normalized()
        actor.facing = aim
    elif not payload.is_empty():
        rejected_requests += 1
        return false
    match action:
        "dash":
            return actor.dash(aim if aim != Vector2.ZERO else actor.facing)
        "attack":
            return actor.get_node("MeleeAttack").attack(actor.facing)
        "absorb":
            return actor.get_node("Absorption").attempt_absorb()
        "skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6", "skill_7", "skill_8":
            var skill: Resource = actor.get_node("SkillBook").skill_at_slot(int(action.right(1)) - 1)
            return actor.get_node("MeleeAttack").attack_skill(actor.facing, skill.id) if skill else false
    rejected_requests += 1
    return false

func _wire_remote(actor: Node2D) -> void:
    _track_actor(actor)
    # Server mode: the owner's host character is wired once, however often they rejoin.
    if actor.has_meta("remote_wired"):
        return
    actor.set_meta("remote_wired", true)
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
    # M11c: open trades end with the session (M11d: and so do world events and their creatures).
    data.erase("exchange")
    data.erase("events")
    # M14a: chat lines are never saved (M15: nor are running duels).
    data.erase("chat")
    data.erase("duels")
    data.enemies = data.enemies.filter(func(enemy): return not String(enemy.id).begins_with("trial_") and not String(enemy.id).begins_with("event_"))
    return data

func save_world() -> Error:
    if not active or not multiplayer.is_server() or not is_instance_valid(world):
        return ERR_UNAUTHORIZED
    var result := STORE.write_world(save_path, persistent_document())
    if result != OK:
        world._announce("Save failed; the previous valid save is retained.")
    return result

## Delta snapshots (found during M6b: full snapshots were ~77 KB 20 times a second per guest —
## every creature of the world and every merchant's stock). Each guest gets a part only when it
## changed since it was last sent to that guest, and creatures only when their own entry changed;
## the guest keeps the last copy of everything. A guest missing a base asks for a full resync.
## What the host last sent each guest: {peer: {part or "enemy:<id>": hash}}.
var _peer_parts: Dictionary = {}
## Guest side: the last copy of every part and creature.
var _snapshot_parts: Dictionary = {}
var _snapshot_enemies: Dictionary = {}
## Always sent whole (small, or changing every tick).
const ALWAYS_SENT := ["players", "version", "world_id", "progression", "gathering", "reeling", "elixirs", "boss_fx"]

func _delta_for(peer: int, data: Dictionary, hashes: Dictionary, enemy_hashes: Array) -> Dictionary:
    var sent: Dictionary = _peer_parts.get(peer, {})
    var out := {"delta": not sent.is_empty()}
    var omitted: Array = []
    for key in data:
        if key == "enemies":
            continue
        if key in ALWAYS_SENT:
            out[key] = data[key]
        elif sent.get(key) == hashes[key]:
            omitted.append(key)
        else:
            out[key] = data[key]
            sent[key] = hashes[key]
    var ids: Array = []
    var changed: Array = []
    for index in range(data.enemies.size()):
        var entry: Dictionary = data.enemies[index]
        var key := "enemy:%s" % entry.id
        ids.append(entry.id)
        if sent.get(key) != enemy_hashes[index]:
            changed.append(entry)
            sent[key] = enemy_hashes[index]
    out["enemy_ids"] = ids
    out["enemies_changed"] = changed
    out["omitted"] = omitted
    _peer_parts[peer] = sent
    return out

## Guest: rebuild the whole snapshot from a delta and the kept parts ({} when a base is missing).
func _expand_snapshot(data: Dictionary) -> Dictionary:
    if not data.has("enemy_ids"):
        return data
    if not data.get("delta", false):
        _snapshot_parts = {}
        _snapshot_enemies = {}
    var full := {}
    for key in data:
        if not key in ["delta", "omitted", "enemy_ids", "enemies_changed"]:
            full[key] = data[key]
            if not key in ALWAYS_SENT:
                _snapshot_parts[key] = data[key]
    for key in data.get("omitted", []):
        if not _snapshot_parts.has(key):
            return {}
        full[key] = _snapshot_parts[key]
    for entry in data.enemies_changed:
        _snapshot_enemies[entry.id] = entry
    var enemies: Array = []
    for id in data.enemy_ids:
        if not _snapshot_enemies.has(id):
            return {}
        enemies.append(_snapshot_enemies[id])
    # Forget creatures the host no longer lists.
    if _snapshot_enemies.size() > enemies.size():
        var listed := {}
        for id in data.enemy_ids:
            listed[id] = true
        for id in _snapshot_enemies.keys():
            if not listed.has(id):
                _snapshot_enemies.erase(id)
    full["enemies"] = enemies
    return full

@rpc("any_peer", "call_remote", "reliable")
func _request_resync() -> void:
    if multiplayer.is_server():
        _peer_parts.erase(multiplayer.get_remote_sender_id())

func _broadcast() -> void:
    var data := document()
    var connected: Dictionary = {}
    for id in owners.values():
        if data.players.has(id):
            connected[id] = data.players[id].duplicate(true)
            connected[id].erase("token_hash")
    data.players = connected
    # Chopping and mining are shown on every peer (not saved).
    var gathering := {}
    for id in owners.values():
        var actor = world.player_by_id(id)
        if actor != null and not String(actor.gather_id).is_empty():
            gathering[id] = [actor.gather_id, actor.gather_resource, [actor.gather_at.x, actor.gather_at.y], actor.gather_clock, actor.gather_period]
    data["gathering"] = gathering
    # M6b: hooked fish and their reel-in minigame (not saved).
    var reeling := {}
    for id in owners.values():
        var angler = world.player_by_id(id)
        if angler != null and not angler.reel.is_empty():
            reeling[id] = angler.reel.duplicate()
    data["reeling"] = reeling
    # M6c: active elixirs (not saved).
    var drinking := {}
    for id in owners.values():
        var drinker = world.player_by_id(id)
        if drinker != null and not drinker.elixirs.is_empty():
            drinking[id] = drinker.elixirs.duplicate(true)
    data["elixirs"] = drinking
    # M7a: raid boss telegraphs (not saved).
    if world.get("boss_fx") != null:
        data["boss_fx"] = world.boss_fx.state()
    # M6a: used-up trees and rocks (not saved).
    if world.get("nodes") != null:
        data["nodes"] = world.nodes.state()
    _revision += 1
    var hashes := {}
    for key in data:
        if key != "enemies" and not key in ALWAYS_SENT:
            hashes[key] = hash(data[key])
    var enemy_hashes: Array = data.enemies.map(func(entry): return hash(entry))
    # Several clients can disconnect in the same poll. Do not broadcast to ENet
    # peers whose channels have already closed but whose callback is still queued.
    for peer in multiplayer.get_peers():
        if owners.has(peer) and _peer_ready(peer):
            _snapshot.rpc_id(peer, _delta_for(peer, data, hashes, enemy_hashes), _revision)
    for peer in _peer_parts.keys():
        if not owners.has(peer):
            _peer_parts.erase(peer)

@rpc("authority", "call_remote", "reliable", 2)
func _snapshot(packet: Dictionary, revision: int) -> void:
    if multiplayer.is_server() or local_character_id.is_empty() or revision <= _received_revision:
        return
    var data := _expand_snapshot(packet)
    if data.is_empty():
        # A delta without its base (it arrived before we were accepted): ask for everything.
        _snapshot_parts = {}
        _snapshot_enemies = {}
        _request_resync.rpc_id(1)
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
    # Only the creatures this delta changed (the guest keeps the rest as they are).
    var changed_enemies: Variant = null
    if packet.get("delta", false) and packet.has("enemies_changed"):
        changed_enemies = {}
        for entry in packet.enemies_changed:
            changed_enemies[entry.id] = true
    CODEC.apply_entities(world, data, true, changed_enemies)
    for id in data.players:
        CODEC.apply_player(world.player_by_id(id), data.players[id], world, true)
        var actor = world.player_by_id(id)
        var job: Variant = data.get("gathering", {}).get(id)
        if job is Array and job.size() in [4, 5]:
            actor.gather_id = String(job[0])
            actor.gather_resource = String(job[1])
            actor.gather_at = Vector2(float(job[2][0]), float(job[2][1]))
            actor.gather_clock = float(job[3])
            actor.gather_period = float(job[4]) if job.size() == 5 else 0.55
        else:
            actor.gather_id = ""
        var hooked: Variant = data.get("reeling", {}).get(id)
        actor.reel = hooked.duplicate() if hooked is Dictionary else {}
        var drinking: Variant = data.get("elixirs", {}).get(id)
        actor.elixirs = drinking.duplicate(true) if drinking is Dictionary else {}
    for actor in world.get_children():
        if actor.is_in_group("player") and not wanted.has(actor.character_id):
            world.remove_child(actor)
            actor.queue_free()
    if world.get("nodes") != null:
        world.nodes.apply(data.get("nodes", {}))
    if world.get("boss_fx") != null:
        world.boss_fx.apply(data.get("boss_fx", []))
    var local = world.player_by_id(local_character_id)
    if local:
        world.bind_local_player(local)

func _peer_disconnected(peer: int) -> void:
    if not active or not multiplayer.is_server() or not owners.has(peer):
        return
    var id: String = owners[peer]
    var actor = world.player_by_id(id)
    if server_mode and id == "host" and actor:
        if actor.get_node("Absorption").active:
            actor.get_node("Absorption")._cancel("Analysis interrupted by disconnection.")
        records["host"] = CODEC.capture_player(actor)
        _park_host(true)
        owners.erase(peer)
        _action_budgets.erase(peer)
        _log("The owner left; the world keeps running.")
        save_world()
        _broadcast()
        return
    if server_mode:
        _log("%s left." % id.left(16))
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
        _sync_characters()
        if save_world() != OK:
            world._announce("Autosave failed. Use F9 to retry; the previous save is retained.")

func stop_session(save: bool = true) -> void:
    if active and save and multiplayer.is_server():
        save_world()
    if _upnp_thread != null:
        _upnp_thread.wait_to_finish()
        _upnp_thread = null
    _close_router_port()
    if _rtc != null:
        _rtc.close()
        _rtc = null
    code_mode = false
    _invites.clear()
    reply_code = ""
    import_path = ""
    _leaving = false
    active = false
    listening = false
    world_meta = {}
    _join_deadline = 0
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    owners.clear()
    _peer_parts.clear()
    _snapshot_parts = {}
    _snapshot_enemies = {}
    _received_revision = -1

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
