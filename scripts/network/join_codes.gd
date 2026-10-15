extends RefCounted
## Join codes (user request): two games connect directly through their routers (WebRTC with a
## public STUN server finding each side's Internet address) after the players swap two codes —
## the host's invite and the friend's reply. A code is the WebRTC offer/answer with its network
## candidates, compressed and base64-encoded behind a short prefix.
const PREFIX := "TRPG1-"
const STUN := {"iceServers": [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}]}
## How long to collect network candidates before writing a code.
const GATHER_SECONDS := 4.0
const MAX_CODE := 20000

static func is_code(text: String) -> bool:
    return text.strip_edges().begins_with(PREFIX)

static func encode(data: Dictionary) -> String:
    var raw := JSON.stringify(data).to_utf8_buffer()
    var packed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
    return PREFIX + str(raw.size()) + "-" + Marshalls.raw_to_base64(packed)

## The code's content ({} when it is not a valid code).
static func decode(text: String) -> Dictionary:
    var code := text.strip_edges().replace("\n", "").replace("\r", "").replace(" ", "")
    if not code.begins_with(PREFIX) or code.length() > MAX_CODE:
        return {}
    var body := code.trim_prefix(PREFIX)
    var dash := body.find("-")
    if dash <= 0 or not body.left(dash).is_valid_int():
        return {}
    var size := int(body.left(dash))
    if size <= 0 or size > 200000:
        return {}
    var packed := Marshalls.base64_to_raw(body.substr(dash + 1))
    if packed.is_empty():
        return {}
    var raw := packed.decompress(size, FileAccess.COMPRESSION_DEFLATE)
    var parser := JSON.new()
    if raw.size() != size or parser.parse(raw.get_string_from_utf8()) != OK or not parser.data is Dictionary:
        return {}
    var data: Dictionary = parser.data
    if not data.get("type") in ["offer", "answer"] or not data.get("sdp") is String or not data.get("candidates") is Array or not (data.get("id") is int or data.get("id") is float):
        return {}
    for candidate in data.candidates:
        if not candidate is Array or candidate.size() != 3 or not candidate[0] is String or not (candidate[1] is int or candidate[1] is float) or not candidate[2] is String:
            return {}
    return data

## A connection that records its description and candidates for the code.
static func connection() -> WebRTCPeerConnection:
    var link := WebRTCPeerConnection.new()
    if link.initialize(STUN) != OK:
        return null
    link.set_meta("candidates", [])
    # The callbacks hold the connection weakly: a strong self-reference would keep it (and its
    # network threads) alive forever, so the game could not quit.
    var held: WeakRef = weakref(link)
    link.session_description_created.connect(func(type: String, sdp: String):
        var live: WebRTCPeerConnection = held.get_ref()
        if live != null:
            live.set_local_description(type, sdp)
            live.set_meta("description", [type, sdp])
    )
    link.ice_candidate_created.connect(func(media: String, index: int, name: String):
        var live: WebRTCPeerConnection = held.get_ref()
        if live != null:
            live.get_meta("candidates").append([media, index, name])
    )
    return link

## The code for a connection's local description and candidates (after gathering).
static func code_for(link: WebRTCPeerConnection, peer_id: int) -> String:
    var description: Array = link.get_meta("description", [])
    if description.is_empty():
        return ""
    return encode({"type": description[0], "sdp": description[1], "candidates": link.get_meta("candidates"), "id": peer_id})

## Apply the other side's code to a connection.
static func apply(link: WebRTCPeerConnection, data: Dictionary) -> void:
    link.set_remote_description(data.type, data.sdp)
    for candidate in data.candidates:
        link.add_ice_candidate(candidate[0], int(candidate[1]), candidate[2])
