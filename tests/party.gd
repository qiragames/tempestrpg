extends SceneTree
## M4.6 parties (user decisions): up to four, invited from the party window, the leader removes,
## anyone leaves; bonus XP for members fighting together (the 10% rule stays); Zeni from kills
## split evenly among members nearby (items still by damage rank); revive a fallen member before
## the respawn; members are a ship owner's crew; leveling spots respawn faster with a party there
## (and keep flowing while you fight on them); saves and the v24 -> v25 migration; the window.
const MAP := preload("res://scripts/world/world_map.gd")
const REGION := preload("res://scripts/world/region_content.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const TRAVEL := preload("res://scripts/travel/travel_catalogue.gd")
const STORE := preload("res://scripts/persistence/save_store.gd")
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
var checks := 0
var failures := 0
var world: Node2D
var session: Node
var actor: CharacterBody2D
var serial := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _frames(count: int = 3) -> void:
    for _i in range(count):
        await physics_frame
        await process_frame

func _friend(id: String, at: Vector2) -> CharacterBody2D:
    var other = load("res://scenes/player/player.tscn").instantiate()
    other.character_id = id
    other.local_controlled = false
    other.position = at
    world.add_child(other)
    return other

func _creature(at: Vector2) -> Node2D:
    serial += 1
    var enemy = GNASHER.instantiate()
    enemy.entity_id = "party_gnasher_%d" % serial
    enemy.position = at
    world.add_child(enemy)
    world.wire_enemy(enemy)
    enemy.set_physics_process(false)
    return enemy

func _run() -> void:
    session = root.get_node("GameSession")
    var dir := OS.get_temp_dir().path_join("tempestrpg-party-" + Crypto.new().generate_random_bytes(6).hex_encode())
    DirAccess.make_dir_recursive_absolute(dir)
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    _check(session.start_host(24710, dir.path_join("party.json"), false) == OK, "Solo world hosted")
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    actor = world.get_local_player()
    actor.position = Vector2(140, 560)
    var party = world.party
    var ann := _friend("ann", Vector2(150, 560))
    var bo := _friend("bo", Vector2(160, 560))
    var cy := _friend("cy", Vector2(170, 560))
    var di := _friend("di", Vector2(180, 560))
    await _frames(1)
    # --- Membership
    _check(party.invite(actor, "ann") and party.accept(ann) and party.same_party("host", "ann") and party.leader("ann") == "host", "Invite and accept: a party led by the inviter")
    _check(not party.invite(ann, "bo"), "Only the leader invites")
    _check(party.invite(actor, "bo") and party.decline(bo) and not party.same_party("host", "bo"), "An invitation can be declined")
    party.invite(actor, "bo")
    party.accept(bo)
    party.invite(actor, "cy")
    party.accept(cy)
    _check(party.members("host").size() == 4 and not party.invite(actor, "di"), "A party holds four")
    _check(party.kick(actor, "cy") and not party.same_party("host", "cy") and not party.kick(ann, "bo"), "The leader removes a member; others cannot")
    _check(party.leave(actor) and party.leader("ann") == "ann" and party.same_party("ann", "bo") and party.party_of("host").is_empty(), "When the leader leaves, the next member leads")
    _check(party.leave(bo) and party.party_of("ann").is_empty(), "A party of one dissolves")
    party.invite(actor, "ann")
    world.progression["world_time"] = float(world.progression.get("world_time", 0.0)) + party.INVITE_SECONDS + 1.0
    await _frames(2)
    _check(not party.accept(ann), "Invitations expire after two minutes")
    party.invite(actor, "ann")
    party.accept(ann)
    # --- Rewards: bonus XP together, Zeni split evenly, items by rank
    actor.progression["zeni"] = 0
    ann.progression["zeni"] = 0
    var xp_host: int = int(actor.progression.experience)
    var xp_ann: int = int(ann.progression.experience)
    var gnasher := _creature(Vector2(150, 540))
    var health = gnasher.get_node("Health")
    health.take_damage(int(health.maximum * 0.8), actor)
    health.immunity_left = 0.0
    health.take_damage(health.maximum, ann)
    await _frames(2)
    var base_xp: int = LEVELING.defeat_xp(gnasher.level, gnasher.difficulty)
    _check(int(actor.progression.experience) - xp_host == int(round(base_xp * 1.1)) and int(ann.progression.experience) - xp_ann == int(round(base_xp * 1.1)), "Party members fighting together get +10% XP per other member nearby")
    _check(actor.zeni() == ann.zeni() and actor.zeni() > 0, "A party's Zeni from a kill is split evenly (%d / %d)" % [actor.zeni(), ann.zeni()])
    var outsider_xp: int = int(di.progression.experience)
    var lone := _creature(Vector2(180, 540))
    lone.get_node("Health").take_damage(9999, di)
    await _frames(2)
    _check(int(di.progression.experience) - outsider_xp == LEVELING.defeat_xp(lone.level, lone.difficulty), "Without a party nothing changes")
    # --- Revive before the respawn
    ann.global_position = actor.global_position + Vector2(200, 0)
    ann.get_node("Health").take_damage(9999)
    await _frames(1)
    _check(ann.death_left > 0.0 and party.revivable_near(actor) == "" , "A fallen member out of reach cannot be revived")
    ann.global_position = actor.global_position + Vector2(10, 0)
    _check(party.revivable_near(actor) == "ann" and not party.revive(di, "ann"), "Only party members can revive")
    _check(party.revive(actor, "ann") and ann.get_node("Health").current == int(round(ann.get_node("Health").maximum * party.REVIVE_HP_SHARE)) and ann.death_left == 0.0 and ann.get_node("Magicules").enabled, "Reviving brings a member back with a third of their HP, where they fell")
    # --- Party members are the ship's crew
    actor.progression["ship"] = {"owned": true, "at": "sunfall"}
    actor.global_position = MAP.dock_position("sunfall")
    ann.global_position = actor.global_position + Vector2(8, 0)
    di.global_position = actor.global_position + Vector2(-8, 0)
    _check(world.harbours.sail(actor, "sunfall", "hanamura") and world.harbours.nearest_harbour(ann) == "hanamura" and world.harbours.nearest_harbour(di) == "sunfall", "Party members sail along on the owner's ship without an invitation; others stay")
    # --- Leveling spots
    var spot: Array = REGION.SPOTS[0]
    var spot_creature: Node2D = world.entity_by_id("%s_1" % spot[0])
    actor.global_position = REGION.at(spot[2]) + Vector2(60, 0)
    ann.global_position = REGION.at(spot[2]) + Vector2(0, -90)
    spot_creature.get_node("Health").take_damage(9999, actor)
    await _frames(2)
    var pending: Array = world.respawner.pending.filter(func(entry): return entry.id == spot_creature.entity_id)
    _check(not pending.is_empty() and absf(float(pending[0].remaining) - REGION.respawn_seconds(spot_creature.entity_id, spot[3]) * party.SPOT_PARTY_FACTOR) < 0.2, "A party at a leveling spot halves its respawn time")
    var spot_id: String = spot_creature.entity_id
    pending[0].remaining = 0.0
    await _frames(5)
    _check(get_nodes_in_group("enemies").any(func(enemy): return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.entity_id == spot_id and enemy.get_node("Health").current > 0), "Spot creatures come back while you fight nearby (not right on top of you)")
    # --- Saves
    var document: Dictionary = CODEC.capture_entities(world)
    var players := {}
    for character in [actor, ann, bo, cy, di]:
        players[character.character_id] = CODEC.capture_player(character)
        players[character.character_id]["token_hash"] = "" if character == actor else "0".repeat(64)
    document.merge({"version": STORE.VERSION, "world_id": "party", "players": players, "progression": world.progression.duplicate(true)})
    _check(document.party.parties.size() == 1 and STORE.validate(document.duplicate(true)), "Parties save with the world")
    var forged: Dictionary = document.duplicate(true)
    forged.party.parties.values()[0].members.append("stranger")
    _check(not STORE.validate(forged), "A party with a character who is not in the world is rejected")
    var legacy: Dictionary = document.duplicate(true)
    legacy.version = 24
    legacy.erase("party")
    var migrated: Variant = STORE.migrate(legacy)
    _check(migrated is Dictionary and migrated.version == STORE.VERSION and migrated.party == {"parties": {}, "invites": {}}, "v24 worlds start without parties")
    # --- The window and frames
    var hud = world.get_node("HUD")
    hud.party_panel.open()
    await _frames(2)
    _check(hud.party_panel.is_open() and hud.menu_open(), "P opens the party window")
    hud.party_panel.close()
    _check(not hud.party_panel.is_open(), "and closes it")
    session.stop_session(false)
    world.queue_free()
    await _frames()
    for file in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(dir.path_join(file))
    DirAccess.remove_absolute(dir)
    print("Party checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
