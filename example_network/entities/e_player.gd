class_name E_NetworkPlayer
extends Entity
## Player entity for the network example.
## Demonstrates continuous sync via CN_SyncEntity.

## Peer ID that owns this player (set by main.gd when spawning)
@export var owner_peer_id: int = 0


func _enter_tree() -> void:
	# Extract peer_id from node name (set by main.gd as str(peer_id))
	var authority_id = str(name).to_int()
	if authority_id > 0:
		owner_peer_id = authority_id
		set_multiplayer_authority(authority_id)


func on_ready() -> void:
	# Add network identity based on owner_peer_id
	add_component(CN_NetworkIdentity.new(owner_peer_id))


func define_components() -> Array:
	return [
		C_NetVelocity.new(),
		C_PlayerInput.new(),
		C_PlayerNumber.new(),  # Join order number (1-4) for color assignment
		# CN_SyncEntity enables native MultiplayerSynchronizer for position/rotation
		CN_SyncEntity.new(true, true, false),  # sync_position=true, sync_rotation=true
	]
