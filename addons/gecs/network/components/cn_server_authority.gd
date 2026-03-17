class_name CN_ServerAuthority
extends Component

## Marker component indicating this entity should only be processed by the server.
##
## Automatically assigned by NetworkSync to server-owned entities (peer_id=0).
##
## Use this in queries to filter entities that only the server should process:
##
## Query pattern:
##   func query():
##       return q.with_all([CN_ServerAuthority, CN_LocalAuthority])
##
## Result:
## - Server: server-owned entities have BOTH markers -> query matches -> processed
## - Client: server-owned entities have CN_ServerAuthority but NOT CN_LocalAuthority -> query fails -> skipped
##
## This enables systems to use component-based filtering instead of runtime Net.is_server() checks.
##
## This component has no properties - it's a pure marker for query filtering.
