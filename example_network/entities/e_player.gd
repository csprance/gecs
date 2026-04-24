## Player entity for the network example.
## Demonstrates smooth network sync via CN_NetSync with velocity dead-reckoning
## and position correction for remote entities (see S_NetworkMovement).
class_name Player
extends Entity

@onready var visual: CSGBox3D = %Visual


func define_components() -> Array:
	return [
		CN_NetworkIdentity.new(),  # Required: marks entity as networked, stores owning peer_id
		CN_NetSync.new(),  # Required: enables property sync using @export_group priority tiers
		C_NetPosition.new(),  # Position synced at HIGH (~20 Hz); remote clients interpolate
		C_NetVelocity.new(),
		C_PlayerInput.new(),
		C_PlayerNumber.new(),
	]


# Help function to set visual color based on player number (called from PlayerInitObserver)
func set_visual_color(color: Color) -> void:
	if visual.material_override == null:
		visual.material_override = StandardMaterial3D.new()
	visual.material_override.albedo_color = color
