## Projectile entity for the network example.
## Demonstrates spawn-only sync via CN_NetSync with SPAWN_ONLY properties.
## Server spawns and broadcasts component values once; clients simulate locally.
class_name Projectile
extends Entity


func define_components() -> Array:
	return [
		CN_NetworkIdentity.new(0),  # Required: peer_id=0 means server-owned
		CN_NetSync.new(),  # Required: enables SPAWN_ONLY property sync for C_NetPosition/C_NetVelocity
		C_NetPosition.new(),
		C_NetVelocity.new(),
		C_Projectile.new(),
	]
