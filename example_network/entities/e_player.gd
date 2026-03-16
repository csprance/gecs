class_name E_Player
extends Entity
## Player entity for the network example.
## Demonstrates continuous sync via CN_NativeSync (transform) and
## CN_NetSync with HIGH priority properties.


func define_components() -> Array:
	return [
		CN_NetworkIdentity.new(), # Required: marks entity as networked, stores owning peer_id
		CN_NetSync.new(), # Required: enables property sync using @export_group priority tiers
		CN_NativeSync.new(), # Optional: syncs position/rotation via Godot's MultiplayerSynchronizer
		C_NetVelocity.new(),
		C_PlayerInput.new(),
		C_PlayerNumber.new(),
	]
