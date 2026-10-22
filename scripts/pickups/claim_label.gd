extends RefCounted
## The small timer above loot and death bags (user request): once something has lain LABEL_AFTER
## seconds it shows whose it is and for how long ("Aster · 4:32"), then — if it can disappear —
## how long until it does ("gone in 7:58"). Drawn on every peer from the replicated world time.
const CLAIM := preload("res://scripts/pickups/claim.gd")
const NAMES := preload("res://scripts/progression/character_names.gd")
const LABEL_AFTER := 10.0

static func clock(seconds: float) -> String:
    var whole := maxi(0, int(ceil(seconds)))
    return "%d:%02d" % [whole / 60, whole % 60]

## `gone_at` < 0: it never disappears.
static func text(node: Node2D, owner_id: String, claim_until: float, since: float, gone_at: float) -> String:
    var world: Node = node.get_parent()
    var now := CLAIM.world_time(world)
    if now - since < LABEL_AFTER:
        return ""
    if not owner_id.is_empty() and now < claim_until:
        var owner: Node = world.player_by_id(owner_id) if world != null and world.has_method("player_by_id") else null
        var who: String = NAMES.display(owner.progression) if owner != null else "Claimed"
        return "%s · %s" % [who, clock(claim_until - now)]
    if gone_at >= 0.0:
        return "gone in %s" % clock(gone_at - now)
    return ""

static func draw_timer(node: Node2D, owner_id: String, claim_until: float, since: float, gone_at: float, offset: Vector2) -> void:
    var label := text(node, owner_id, claim_until, since, gone_at)
    if label.is_empty():
        return
    var font := ThemeDB.fallback_font
    var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
    var at := offset + Vector2(-width / 2.0, 0)
    node.draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.05, 0.04, 0.02))
    node.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("ffe08a"))
