extends RefCounted
## Character names (user request: names over heads, a character-first start screen). A name lives
## in progression.name (optional in saves; "" for characters made before names existed — the
## start screen asks for one). Shown above every character's head, in chat and on the character
## screen; a character without a name shows its race.
const MAX_LENGTH := 16
## Options: show your own name above your head too.
static var show_own := true

## The name as it would be stored: trimmed, single spaces, printable characters only, at most
## MAX_LENGTH.
static func clean(text: String) -> String:
    var out := ""
    for character in text.strip_edges():
        var code := character.unicode_at(0)
        if code < 32 or code == 127 or character in ["<", ">", "[", "]", "|", "\\"]:
            continue
        if character == " " and out.ends_with(" "):
            continue
        out += character
    return out.strip_edges().left(MAX_LENGTH).strip_edges()

static func valid(name: Variant) -> bool:
    return name is String and name.length() <= MAX_LENGTH and clean(name) == name

static func of(progression: Dictionary) -> String:
    var name: Variant = progression.get("name", "")
    return String(name) if name is String else ""

## What to show for a character: its name, else its race.
static func display(progression: Dictionary) -> String:
    var name := of(progression)
    return name if not name.is_empty() else String(progression.get("race", "Slime"))
