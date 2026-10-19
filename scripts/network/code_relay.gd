extends Node
## Short invite codes (user request: one code, no reply, no router settings). The two games still
## connect directly (WebRTC, see JoinCodes); only the connection details are swapped automatically
## through a free public message service (ntfy.sh, no account), on a topic derived from the code
## and encrypted with a key derived from the code, so the service only sees random bytes. Messages
## there expire on their own (hours). If the service cannot be reached, the old two-step long
## codes still work.
const SERVER := "https://ntfy.sh/"
const PREFIX := "TRPG-"
## Unambiguous characters (no 0/O, 1/I/L).
const ALPHABET := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
const CODE_LENGTH := 10
const TIMEOUT := 12.0
const BASE64 := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="

## Overridable for tests: Callable(method: int, url: String, body: String) -> [ok: bool, text: String].
var transport: Callable

static func new_code() -> String:
    var crypto := Crypto.new()
    var bytes := crypto.generate_random_bytes(CODE_LENGTH)
    var text := ""
    for index in range(CODE_LENGTH):
        text += ALPHABET[bytes[index] % ALPHABET.length()]
    return PREFIX + text.left(5) + "-" + text.substr(5)

## The code's letters, upper case, without dashes or spaces ("" when it is not a short code).
static func normalize(text: String) -> String:
    var clean := text.strip_edges().to_upper().replace(" ", "")
    if not clean.begins_with(PREFIX):
        return ""
    clean = clean.trim_prefix(PREFIX).replace("-", "")
    if clean.length() != CODE_LENGTH:
        return ""
    for character in clean:
        if not character in ALPHABET:
            return ""
    return clean

static func is_short(text: String) -> bool:
    return not normalize(text).is_empty()

static func topic(code: String) -> String:
    return "trpg-" + ("topic:" + normalize(code)).sha256_text().left(24)

static func _key(code: String) -> PackedByteArray:
    return ("key:" + normalize(code)).sha256_buffer()

## kind + text, AES-CBC with a random IV, as base64.
static func seal(code: String, kind: String, text: String) -> String:
    var plain := (kind + "|" + text).to_utf8_buffer()
    var pad := 16 - plain.size() % 16
    for _i in range(pad):
        plain.append(pad)
    var iv := Crypto.new().generate_random_bytes(16)
    var aes := AESContext.new()
    aes.start(AESContext.MODE_CBC_ENCRYPT, _key(code), iv)
    var sealed := aes.update(plain)
    aes.finish()
    return Marshalls.raw_to_base64(iv + sealed)

## [kind, text] of a sealed message ([] when it is not ours or damaged).
static func open_message(code: String, message: String) -> Array:
    var text_in := message.strip_edges()
    if text_in.is_empty() or text_in.length() % 4 != 0:
        return []
    for character in text_in:
        if not (character in BASE64):
            return []
    var raw := Marshalls.base64_to_raw(text_in)
    if raw.size() < 32 or (raw.size() - 16) % 16 != 0:
        return []
    var aes := AESContext.new()
    aes.start(AESContext.MODE_CBC_DECRYPT, _key(code), raw.slice(0, 16))
    var plain := aes.update(raw.slice(16))
    aes.finish()
    var pad: int = plain[plain.size() - 1]
    if pad < 1 or pad > 16 or pad > plain.size():
        return []
    var text := plain.slice(0, plain.size() - pad).get_string_from_utf8()
    var bar := text.find("|")
    if bar <= 0:
        return []
    return [text.left(bar), text.substr(bar + 1)]

## Post a sealed message for the code; true when the service took it.
func post(code: String, kind: String, text: String) -> bool:
    var answer: Array = await _call(HTTPClient.METHOD_POST, SERVER + topic(code), seal(code, kind, text))
    return answer[0]

## Every message of `kind` on the code's topic (oldest first).
func fetch(code: String, kind: String) -> Array:
    var answer: Array = await _call(HTTPClient.METHOD_GET, SERVER + topic(code) + "/json?poll=1&since=all", "")
    var found: Array = []
    if not answer[0]:
        return found
    for line in String(answer[1]).split("\n", false):
        var parsed: Variant = JSON.parse_string(line)
        if not parsed is Dictionary or parsed.get("event") != "message":
            continue
        var body := String(parsed.get("message", ""))
        # Long messages arrive as an attachment.
        if parsed.get("attachment") is Dictionary and String(parsed.attachment.get("url", "")).begins_with(SERVER):
            var attached: Array = await _call(HTTPClient.METHOD_GET, String(parsed.attachment.url), "")
            body = String(attached[1]) if attached[0] else ""
        var opened := open_message(code, body)
        if not opened.is_empty() and opened[0] == kind:
            found.append(opened[1])
    return found

## Wait up to `seconds` for the first message of `kind` ("" on time-out).
func wait_for(code: String, kind: String, seconds: float, interval: float = 2.0) -> String:
    var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
    while Time.get_ticks_msec() < deadline and is_inside_tree():
        var found: Array = await fetch(code, kind)
        if not found.is_empty():
            return found[found.size() - 1]
        await get_tree().create_timer(interval, true, false, true).timeout
    return ""

func _call(method: int, url: String, body: String) -> Array:
    if transport.is_valid():
        return await transport.call(method, url, body)
    var request := HTTPRequest.new()
    request.timeout = TIMEOUT
    add_child(request)
    var error := request.request(url, ["Content-Type: text/plain"], method, body)
    if error != OK:
        request.queue_free()
        return [false, ""]
    var result: Array = await request.request_completed
    request.queue_free()
    var ok: bool = result[0] == HTTPRequest.RESULT_SUCCESS and int(result[1]) >= 200 and int(result[1]) < 300
    return [ok, (result[3] as PackedByteArray).get_string_from_utf8()]
