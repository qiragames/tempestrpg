extends SceneTree
const CATALOGUE := preload("res://scripts/skills/skill_catalogue.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("_run")
func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func _evidence(analyzed: Array = [], trials: Array = [], mastery: Array = [], ascensions: Array = []) -> Dictionary:
    return {"analyzed": analyzed, "trials": trials, "mastery": mastery, "ascensions": ascensions}
## 17c: learned skills must be activated in the skill tree (earning levels for points if needed).
func _activate_learned(actor: Node) -> void:
    for id in actor.get_node("SkillBook").evidence_ids():
        if id in actor.progression.tree.active:
            continue
        while int(actor.progression.skill_points) < 1:
            actor.gain_experience(25 * (actor.progression.level + 1) * actor.progression.level - int(actor.progression.experience), "test")
        actor.activate_skill(id)
func _run() -> void:
    # Real catalogue.
    _check(CATALOGUE.resource_errors().is_empty(), "Shipped catalogue and skill resources are consistent: %s" % [CATALOGUE.resource_errors()])
    _check(CATALOGUE.TIERS == ["Common", "Extra", "Unique", "Ultimate"], "Four tier labels in order")
    _check(CATALOGUE.TRIALS.keys() == ["proving_trial"] and CATALOGUE.ASCENSIONS.is_empty(), "One trial exists; no ascension can be earned yet, so Ultimate stays locked")
    # A synthetic chain through every tier validates the rule engine without shipping fake skills.
    var specimens := {"forest_gnasher": "", "wolf": ""}
    var trials := {"trial_a": true}
    var ascensions := {"ascend_a": true}
    var rules := {
        "bite": {"tier": "Common", "analysis": "forest_gnasher"},
        "claw": {"tier": "Common", "analysis": "wolf"},
        "pierce": {"tier": "Extra", "requires": ["bite", "claw"], "analysis": "wolf"},
        "focus": {"tier": "Unique", "requires": ["pierce"], "trial": "trial_a"},
        "storm": {"tier": "Ultimate", "requires": ["focus"], "ascension": "ascend_a"},
    }
    _check(CATALOGUE.catalogue_errors(rules, specimens, trials, ascensions).is_empty(), "Four-tier synthetic chain is valid")
    var broken := {
        "unknown tier": {"x": {"tier": "Legendary", "analysis": "wolf"}},
        "extra key": {"x": {"tier": "Common", "analysis": "wolf", "requires": []}},
        "unknown specimen": {"x": {"tier": "Common", "analysis": "dragon"}},
        "missing prerequisite": {"x": {"tier": "Extra", "requires": ["ghost"], "analysis": "wolf"}},
        "wrong prerequisite tier": {"a": {"tier": "Common", "analysis": "wolf"}, "x": {"tier": "Unique", "requires": ["a"], "trial": "trial_a"}},
        "two Unique prerequisites": {"a": {"tier": "Common", "analysis": "wolf"}, "e": {"tier": "Extra", "requires": ["a"], "analysis": "wolf"}, "f": {"tier": "Extra", "requires": ["a"], "analysis": "wolf"}, "x": {"tier": "Unique", "requires": ["e", "f"], "trial": "trial_a"}},
        "unknown trial": {"a": {"tier": "Common", "analysis": "wolf"}, "e": {"tier": "Extra", "requires": ["a"], "analysis": "wolf"}, "x": {"tier": "Unique", "requires": ["e"], "trial": "nope"}},
        "Ultimate without ascension": {"x": {"tier": "Ultimate", "requires": ["focus"]}},
    }
    for label in broken:
        _check(not CATALOGUE.catalogue_errors(broken[label], specimens, trials, ascensions).is_empty(), "Catalogue rejects %s" % label)
    _check(CATALOGUE.unlockable([], _evidence(["forest_gnasher"]), rules) == ["bite"], "Common unlocks from its analysis only")
    _check(CATALOGUE.unlockable([], _evidence(["forest_gnasher", "wolf"]), rules) == ["bite", "claw", "pierce"], "Extra unlocks once its Commons are known, in tier order")
    _check(not "pierce" in CATALOGUE.unlockable([], _evidence(["wolf"]), rules), "Extra needs every required Common")
    _check(not "focus" in CATALOGUE.unlockable(["bite", "claw", "pierce"], _evidence(["forest_gnasher", "wolf"]), rules), "Unique needs its personal trial")
    _check("focus" in CATALOGUE.unlockable(["bite", "claw", "pierce"], _evidence(["forest_gnasher", "wolf"], ["trial_a"]), rules), "Unique unlocks with Extra + trial")
    var almost := _evidence(["forest_gnasher", "wolf"], ["trial_a"], [], ["ascend_a"])
    _check(not "storm" in CATALOGUE.unlockable(["bite", "claw", "pierce", "focus"], almost, rules), "Ultimate needs mastery of its Unique, not only ascension")
    almost.mastery = ["focus"]
    _check("storm" in CATALOGUE.unlockable(["bite", "claw", "pierce", "focus"], almost, rules), "Ultimate unlocks with mastery + ascension")
    _check(not CATALOGUE.justified(["pierce"], _evidence(["wolf"]), rules) and CATALOGUE.justified(["bite", "claw", "pierce"], _evidence(["forest_gnasher", "wolf"]), rules), "Known skills must be derivable from evidence")
    _check(not CATALOGUE.justified(["pierce"], _evidence(["forest_gnasher", "wolf"]), rules), "Extra save must retain required Common skills even with complete analysis evidence")
    _check(not CATALOGUE.justified(["focus"], _evidence(["forest_gnasher", "wolf"], ["trial_a"]), rules), "Unique save must retain its required Extra skill")
    _check(not CATALOGUE.justified(["storm"], almost, rules), "Ultimate save must retain its required Unique skill")
    # Skill book on the real player.
    var world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var session = root.get_node("GameSession")
    var actor = world.get_local_player()
    var book = actor.get_node("SkillBook")
    var melee = actor.get_node("MeleeAttack")
    var pool = actor.get_node("Magicules")
    await process_frame
    _check(book.record_analysis(&"dragon").is_empty() and book.evidence.analyzed.is_empty(), "Unknown specimens record nothing")
    session.replica_world = true
    _check(book.record_analysis(&"forest_gnasher").is_empty() and book.known_ids().is_empty(), "Client replicas cannot record evidence or unlock")
    session.replica_world = false
    var gained: Array = book.record_analysis(&"forest_gnasher")
    _check(gained.size() == 1 and gained[0].id == &"rending_bite" and book.skill_at_slot(0) == null, "Analysis evidence unlocks Rending Bite (inactive until activated)")
    _activate_learned(actor)
    _check(book.skill_at_slot(0).id == &"rending_bite", "Activating Rending Bite places it in slot 1")
    _check(book.record_analysis(&"forest_gnasher").is_empty() and book.evidence.analyzed == ["forest_gnasher"] and book.known_ids().size() == 1, "Repeated analysis is idempotent")
    var overview: Array = book.describe()
    _check(overview.size() == CATALOGUE.RULES.size() and overview[0].known and overview[0].requirements[0].met, "Read-only overview reports known skills and met requirements")
    _check(not book.assign_slot(5, &"rending_bite") and not book.assign_slot(-1, &"rending_bite"), "Out-of-range slots rejected")
    _check(not book.assign_slot(1, &"storm"), "Unknown skills cannot be equipped")
    _check(book.assign_slot(2, &"rending_bite") and book.skill_at_slot(0) == null and book.skill_at_slot(2).id == &"rending_bite", "Equipping moves a skill instead of duplicating it")
    _check(not book.assign_slot(2, &"rending_bite"), "Re-equipping the same slot is a no-op")
    _check(not session.apply_action(actor, "assign_slot", {"slot": 0, "id": "rending_bite", "unlock": true}), "Forged loadout payload rejected")
    _check(not session.apply_action(actor, "assign_slot", {"slot": "0", "id": "rending_bite"}), "Non-numeric slot rejected")
    _check(session.apply_action(actor, "assign_slot", {"slot": 0, "id": "rending_bite"}) and book.skill_at_slot(0).id == &"rending_bite", "Host intent equips a known skill")
    _check(session.apply_action(actor, "assign_slot", {"slot": 0, "id": ""}) and book.skill_at_slot(0) == null, "Host intent clears a slot")
    book.assign_slot(0, &"rending_bite")
    var warp: Resource = load(CATALOGUE.SKILLS.rending_bite).duplicate()
    warp.id = &"warp"
    warp.effect = &"teleport"
    book._known[&"warp"] = warp
    var before: float = pool.current
    _check(not melee.attack_skill(Vector2.RIGHT, &"warp") and pool.current == before, "Unknown effects never execute or spend")
    book._known.erase(&"warp")
    _check(melee.attack_skill(Vector2.RIGHT, &"rending_bite") and pool.current == before - 12.0, "Strike effect still activates Rending Bite with its cost")
    # Eight characters keep separate ledgers.
    var guests: Array = []
    for index in range(7):
        var guest = load("res://scenes/player/player.tscn").instantiate()
        guest.character_id = "guest_%d" % index
        guest.local_controlled = false
        guest.position = Vector2(100 + index * 20, 500)
        world.add_child(guest)
        guests.append(guest)
    await process_frame
    var untouched := true
    for guest in guests:
        untouched = untouched and guest.get_node("SkillBook").known_ids().is_empty() and guest.get_node("SkillBook").evidence.analyzed.is_empty()
    _check(untouched, "Seven other characters gain nothing from the host's analysis")
    guests[3].get_node("SkillBook").record_analysis(&"forest_gnasher")
    _check(guests[3].get_node("SkillBook").knows(&"rending_bite") and not guests[4].get_node("SkillBook").knows(&"rending_bite"), "Each character unlocks from its own evidence")
    # Persistence and validation.
    var data: Dictionary = CODEC.capture_entities(world)
    var players := {"host": CODEC.capture_player(actor)}
    for guest in guests:
        players[guest.character_id] = CODEC.capture_player(guest)
        players[guest.character_id]["token_hash"] = "a".repeat(64)
    data.merge({"version": STORE.VERSION, "world_id": "skill_world", "players": players, "progression": world.progression.duplicate(true)})
    _check(STORE.VERSION >= 7 and STORE.validate(data), "Eight-character snapshot with evidence validates")
    _check(data.players.host.skill_evidence.analyzed == ["forest_gnasher"] and data.players.guest_0.skill_evidence.analyzed.is_empty(), "Evidence saved per character")
    var bad := data.duplicate(true)
    bad.players.guest_0.skill_ids = ["rending_bite"]
    _check(not STORE.validate(bad), "Forged skill without evidence rejected")
    bad = data.duplicate(true)
    bad.players.host.skill_evidence.trials = ["trial_a"]
    _check(not STORE.validate(bad), "Forged trial evidence rejected")
    bad = data.duplicate(true)
    bad.players.host.skill_evidence.mastery = ["rending_bite"]
    _check(not STORE.validate(bad), "Mastery only for known Unique skills")
    bad = data.duplicate(true)
    bad.players.host.skill_evidence.analyzed = ["forest_gnasher", "forest_gnasher"]
    _check(not STORE.validate(bad), "Duplicate evidence rejected")
    bad = data.duplicate(true)
    bad.players.host.slots = ["rending_bite", "rending_bite", ""]
    _check(not STORE.validate(bad), "Duplicate equipped slots rejected")
    bad = data.duplicate(true)
    bad.players.host.erase("skill_evidence")
    _check(not STORE.validate(bad), "v7 requires the evidence ledger")
    var restored = load("res://scenes/player/player.tscn").instantiate()
    restored.local_controlled = false
    world.add_child(restored)
    await process_frame
    CODEC.apply_player(restored, JSON.parse_string(JSON.stringify(data.players.host)), world, false)
    _check(restored.get_node("SkillBook").evidence.analyzed == ["forest_gnasher"] and restored.get_node("SkillBook").record_analysis(&"forest_gnasher").is_empty(), "Reload restores evidence; re-analysis after reload stays idempotent")
    var legacy := data.duplicate(true)
    legacy.version = 6
    for id in legacy.players:
        legacy.players[id].erase("skill_evidence")
    var migrated: Dictionary = STORE.migrate(legacy)
    _check(STORE.validate(migrated) and migrated.players.host.skill_evidence.analyzed == ["forest_gnasher"] and migrated.players.guest_0.skill_evidence == CATALOGUE.empty_evidence(), "v6 saves rebuild evidence only from actual knowledge")
    _check(migrated.players.host.skill_evidence.trials.is_empty() and migrated.players.host.skill_evidence.mastery.is_empty(), "Migration never fabricates trials or mastery")
    print("Skill catalogue checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
