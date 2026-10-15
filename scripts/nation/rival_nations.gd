extends Node2D
## Rival nations (M5d, user decision): seven nations hold the archipelago's towns. For now they
## only exist — neither hostile nor friendly, no diplomacy yet: each flies its banner in its
## capital, shows on the world map, and its leader can be talked to (F). Pure presentation and
## data; nothing is saved.
const MAP := preload("res://scripts/world/world_map.gd")
const NATION := preload("res://scripts/nation/nation_catalogue.gd")
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
const CAMP := preload("res://scripts/settlement/first_camp.gd")

## [id, name, people, capital town, colour, emblem, leader sprite, leader name, words]
const RIVALS := [
    ["verdant_league", "Verdant League", "humans", "brookhaven", Color("3f9b4f"), 4, "merchant_verdant", "Chancellor Bram", "The League trades with everyone and trusts no one. Your little nation has been noticed."],
    ["frost_clans", "Frost Clans", "northfolk", "rimeholm", Color("9cc8e8"), 1, "merchant_frost", "Jarl Sigrun", "The clans endure the cold. We will see whether your people do."],
    ["dune_sultanate", "Dune Sultanate", "desert folk", "dunemarch", Color("e3b341"), 0, "merchant_desert", "Sultan Kadir", "Water and gold flow to the Sultanate. Remember that."],
    ["amber_crown", "Amber Crown", "beastkin", "amberhold", Color("d8752e"), 5, "merchant_amber", "Queen Maren", "The Crown remembers every border. Yours is new."],
    ["mire_tribes", "Mire Tribes", "lizardmen", "bogsend", Color("6d7a3a"), 2, "merchant_marsh", "Elder Ssorath", "The marsh swallows the careless. Tread lightly, newcomer."],
    ["sakura_shogunate", "Sakura Shogunate", "kitsune and monks", "hanamura", Color("e889a8"), 3, "merchant_sakura", "Shogun Akane", "Petals fall on every nation in time. We are patient."],
    ["ember_dominion", "Ember Dominion", "fire-forged", "cinderport", Color("b8352a"), 3, "merchant_ember", "Warlord Pyra", "The Dominion is forged in fire. We are watching your flag."],
]
const REACH := 30.0

var _leaders: Dictionary = {}

static func rival(id: String) -> Array:
    for entry in RIVALS:
        if entry[0] == id:
            return entry
    return []

## Where a rival's leader stands and its banner flies (beside the capital's plaza).
static func leader_position(entry: Array) -> Vector2:
    return MAP.to_world(Vector2(MAP.town(entry[3])[3]) + Vector2(3, 4))

static func banner_position(entry: Array) -> Vector2:
    return MAP.to_world(Vector2(MAP.town(entry[3])[3]) + Vector2(-3, 4))

func _ready() -> void:
    name = "RivalNations"
    y_sort_enabled = true
    for entry in RIVALS:
        var leader := Node2D.new()
        leader.name = "Leader_" + entry[0]
        leader.position = leader_position(entry)
        var body := SPRITES.make(entry[6])
        leader.add_child(body)
        SPRITES.play(body, "idle_down")
        add_child(leader)
        _leaders[entry[0]] = leader
        var pole := Node2D.new()
        pole.name = "Banner_" + entry[0]
        pole.position = banner_position(entry)
        var color: Color = entry[4]
        var emblem: int = entry[5]
        pole.draw.connect(func():
            pole.draw_rect(Rect2(-1, -30, 2, 30), Color("6b4a2b"))
            pole.draw_rect(Rect2(1, -29, 14, 10), color)
            pole.draw_rect(Rect2(1, -29, 14, 10), color.darkened(0.4), false, 1.0)
            CAMP.draw_emblem(pole, emblem, Vector2(8, -24), color.darkened(0.5) if color.get_luminance() > 0.6 else Color(1, 1, 1, 0.9))
        )
        add_child(pole)

## The rival leader a character stands beside ("" if none).
func nearest_leader(actor: Node2D) -> String:
    for id in _leaders:
        if actor.global_position.distance_to(_leaders[id].position) <= REACH:
            return id
    return ""
