extends RefCounted
## Components can be preloaded without relying on autoload compile-time globals.

static func can_mutate(node: Node) -> bool:
    var session := node.get_node_or_null("/root/GameSession")
    if session != null and session.replica_world:
        return false
    return not node.multiplayer.has_multiplayer_peer() or node.multiplayer.is_server()
