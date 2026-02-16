class_name ExampleSyncConfig
extends SyncConfig
## Sync configuration for the network example.
## Defines component sync priorities and filtering.

func _init() -> void:
	component_priorities = {
		"C_NetVelocity": Priority.HIGH,     # 20 Hz - movement updates
		"C_PlayerInput": Priority.HIGH,     # 20 Hz - input syncs frequently
	}
	# No components to skip - we're not using native transform sync via C_Transform
	skip_component_types = []
	# Not using a separate transform component
	transform_component = ""

	# CRITICAL: Trigger native sync (MultiplayerSynchronizer) setup when CN_NetworkIdentity is added
	# This enables continuous position sync for players via Godot's native replication
	model_ready_component = "CN_NetworkIdentity"
