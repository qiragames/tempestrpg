extends SceneTree
## Short invite codes (user request): the format, the encryption (only the code opens a message),
## reading ntfy.sh's replies (also long messages sent as attachments), waiting with a time-out, and
## one live round trip through ntfy.sh (skipped, not failed, when the computer is offline).
const RELAY := preload("res://scripts/network/code_relay.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _run() -> void:
    var code := RELAY.new_code()
    _check(code.begins_with("TRPG-") and code.length() == 16 and RELAY.is_short(code), "Codes look like TRPG-XXXXX-XXXXX (%s)" % code)
    _check(RELAY.is_short(code.to_lower().replace("-", " ").replace("trpg ", "TRPG-")) or RELAY.is_short(" " + code + " "), "Spaces and case do not matter")
    _check(not RELAY.is_short("TRPG1-123-abc") and not RELAY.is_short("TRPG-ABC") and not RELAY.is_short("TRPG-00000-00000"), "Long codes and junk are not short codes")
    var other := RELAY.new_code()
    _check(other != code and RELAY.topic(code) != RELAY.topic(other) and RELAY.topic(code) == RELAY.topic(code.to_lower().replace("trpg-", "TRPG-")), "Each code has its own topic")
    var sealed := RELAY.seal(code, "offer", "TRPG1-secret-offer")
    _check(not sealed.contains("secret") and RELAY.open_message(code, sealed) == ["offer", "TRPG1-secret-offer"], "Messages are encrypted; the code opens them")
    _check(RELAY.open_message(other, sealed).is_empty() or RELAY.open_message(other, sealed)[1] != "TRPG1-secret-offer", "Another code cannot read them")
    _check(RELAY.open_message(code, "not base64 !!").is_empty() and RELAY.open_message(code, "").is_empty(), "Junk is ignored")
    # A fake ntfy.sh: posts are kept per topic; polls answer in ntfy's JSON-lines format.
    var relay: Node = RELAY.new()
    root.add_child(relay)
    var store := {}
    relay.transport = func(method: int, url: String, body: String) -> Array:
        var topic := url.trim_prefix(RELAY.SERVER).get_slice("/", 0)
        if method == HTTPClient.METHOD_POST:
            store[topic] = store.get(topic, []) + [body]
            return [true, "{}"]
        if url.contains("/attachment/"):
            return [true, store.get("attachment", "")]
        var lines: Array = ['{"event":"open"}']
        for message in store.get(topic, []):
            if message.length() > 3000:
                store["attachment"] = message
                lines.append(JSON.stringify({"event": "message", "message": "attachment", "attachment": {"url": RELAY.SERVER + "file/attachment/1"}}))
            else:
                lines.append(JSON.stringify({"event": "message", "message": message}))
        return [true, "\n".join(lines)]
    _check(await relay.post(code, "offer", "long offer"), "Posting works")
    await relay.post(code, "answer", "the answer")
    await relay.post(other, "answer", "someone else's")
    _check(await relay.fetch(code, "answer") == ["the answer"] and await relay.fetch(code, "offer") == ["long offer"], "Fetching finds the code's messages by kind")
    var big := "x".repeat(5000)
    await relay.post(code, "offer", big)
    var offers: Array = await relay.fetch(code, "offer")
    _check(offers.size() == 2 and offers[1] == big, "Long messages (attachments) are read too")
    var started := Time.get_ticks_msec()
    _check(await relay.wait_for(RELAY.new_code(), "offer", 1.0, 0.2) == "" and Time.get_ticks_msec() - started < 3000, "Waiting gives up after its time")
    # Live: one round trip through ntfy.sh.
    relay.transport = Callable()
    var live := RELAY.new_code()
    if await relay.post(live, "offer", "hello from the test"):
        var got: String = await relay.wait_for(live, "offer", 10.0, 1.0)
        _check(got == "hello from the test", "Live round trip through ntfy.sh")
    else:
        print("ntfy.sh not reachable: live round trip skipped")
    relay.queue_free()
    print("Code relay checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
