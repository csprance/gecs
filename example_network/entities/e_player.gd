class_name E_Player
extends Entity
## Player entity for the network example.
## Demonstrates continuous sync via CN_NativeSync (transform) and
## CN_NetSync with HIGH priority properties.

## Peer ID that owns this player (set at construction time)
var peer_id: int = 0


func _init(p_peer_id: int = 0) -> void:
	peer_id = p_peer_id


func _enter_tree() -> void:
	# Extract peer_id from node name when spawned from scene (set by main.gd as str(peer_id))
	var authority_id = str(name).to_int()
	if authority_id > 0:
		peer_id = authority_id
		set_multiplayer_authority(authority_id)


func define_components() -> Array:
	return [
		CN_NetworkIdentity.new(peer_id),
		CN_NetSync.new(),
		CN_NativeSync.new(), # Syncs position/rotation via MultiplayerSynchronizer
		C_NetVelocity.new(),
		C_PlayerInput.new(),
		C_PlayerNumber.new(), # Join order number (1-4) for color assignment
	]
