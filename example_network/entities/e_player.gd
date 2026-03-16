## Player entity for the network example.
## Demonstrates continuous sync via CN_NativeSync (transform) and
## CN_NetSync with HIGH priority properties.
class_name Player
extends Entity

@onready var visual: CSGBox3D = %Visual


func define_components() -> Array:
	return [
		CN_NetworkIdentity.new(), # Required: marks entity as networked, stores owning peer_id
		CN_NetSync.new(), # Required: enables property sync using @export_group priority tiers
		CN_NativeSync.new(), # Optional: syncs position/rotation via Godot's MultiplayerSynchronizer
		C_NetVelocity.new(),
		C_PlayerInput.new(),
		C_PlayerNumber.new(),
		C_NewPlayer.new(),
	]


# Help function to set visual color based on player number (called from PlayerInitSystem)
func set_visual_color(color: Color) -> void:
	if visual.material_override == null:
		visual.material_override = StandardMaterial3D.new()
	visual.material_override.albedo_color = color
