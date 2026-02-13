class_name CN_RemoteEntity
extends Component

## Marker component indicating this entity is controlled by a remote peer or server.
##
## Automatically assigned by NetworkSync when CN_NetworkIdentity.peer_id does NOT match local peer.
##
## Added to:
## - Remote players (other players' entities on our client)
## - Enemies (on clients - server owns them)
## - Projectiles (on clients - server owns them)
##
## Query patterns:
##
## 1. Skip remote entities (process only local):
##   func query():
##       return q.with_all([C_Velocity]).with_none([CN_RemoteEntity])
##
## 2. Process only remote entities (e.g., for interpolation):
##   func query():
##       return q.with_all([C_Transform, CN_RemoteEntity])
##
## This component has no properties - it's a pure marker for query filtering.
