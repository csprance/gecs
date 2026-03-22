class_name CN_LocalAuthority
extends Component

## Marker component indicating this entity is controlled by the local peer.
##
## Automatically assigned by NetworkSync when CN_NetworkIdentity.peer_id matches local peer.
##
## Added to:
## - Local player on all peers (each peer's own player)
## - Entities the local peer has authority over
##
## Query patterns:
##
## 1. Process only locally controlled entities (recommended for input):
##   func query():
##       return q.with_all([C_Velocity, C_Player, CN_LocalAuthority])
##
## 2. Apply input only to local entities:
##   func process(entity, delta):
##       if entity.has_component(CN_LocalAuthority):
##           # Read input and apply movement
##
## This component has no properties - it's a pure marker for query filtering.
