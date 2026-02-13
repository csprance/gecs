class_name CN_ServerOwned
extends Component

## Marker component indicating this entity is authoritative on the server.
##
## Automatically assigned by NetworkSync when CN_NetworkIdentity.peer_id is 0 or 1.
##
## Added to:
## - Enemies (peer_id = 0 or 1)
## - Projectiles (peer_id = 0 or 1)
## - Pickups (peer_id = 0 or 1)
##
## Query patterns:
##
## 1. Server-only processing (recommended):
##   func query():
##       # Only process on server - use your NetAdapter or check multiplayer.is_server()
##       if not multiplayer.is_server():
##           return q.with_none([Component])  # Empty result
##       return q.with_all([C_EnemyAI, CN_ServerOwned])
##
## 2. Skip server-owned on clients:
##   func query():
##       return q.with_all([C_EnemyAI]).with_none([CN_ServerOwned])
##
## This component has no properties - it's a pure marker for query filtering.
