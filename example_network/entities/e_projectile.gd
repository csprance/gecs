class_name E_NetworkProjectile
extends Entity
## Projectile entity for the network example.
## Demonstrates spawn-only sync - NO CN_SyncEntity means server broadcasts
## spawn data once, then all clients simulate locally.


func define_components() -> Array:
	return [
		# Server-owned (peer_id = 0)
		CN_NetworkIdentity.new(0),
		C_Projectile.new(),
		C_NetVelocity.new(),
		C_NetPosition.new(),  # Position synced at spawn
		# NOTE: No CN_SyncEntity! This enables spawn-only sync pattern.
		# Server spawns and broadcasts component values at spawn time.
		# Clients receive spawn RPC and simulate locally from there.
	]
