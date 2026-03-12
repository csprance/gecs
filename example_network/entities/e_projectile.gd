class_name E_Projectile
extends Entity
## Projectile entity for the network example.
## Demonstrates spawn-only sync via CN_NetSync with SPAWN_ONLY properties.
## Server spawns and broadcasts component values once; clients simulate locally.

## Peer ID of the player who fired this projectile
var owner_peer_id: int = 0


func _init(p_owner: int = 0) -> void:
	owner_peer_id = p_owner


func define_components() -> Array:
	return [
		CN_NetworkIdentity.new(0),   # server-owned projectile (peer_id = 0)
		CN_NetSync.new(),            # C_NetPosition + C_NetVelocity use SPAWN_ONLY group
		C_NetPosition.new(),         # Position synced at spawn only
		C_NetVelocity.new(),         # Velocity synced at spawn only (SPAWN_ONLY via export_group)
		C_Projectile.new(),
	]
