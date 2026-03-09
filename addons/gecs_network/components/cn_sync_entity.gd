class_name CN_SyncEntity
extends Component
## DEPRECATED stub — kept for Phase 2/3 parser compatibility.
## The v0.1.1 handlers (sync_native_handler, sync_property_handler, sync_state_handler)
## reference this class. It will be removed when those handlers are replaced in Phase 3.
## DO NOT use CN_SyncEntity in new code — use CN_NetSync instead.

var target_node: Node = null
var visibility_mode: int = 0       # MultiplayerSynchronizer.VisibilityUpdateMode
var delta_interval: float = 0.0
var replication_interval: float = 0.0
var public_visibility: bool = true


func get_sync_target(_entity: Node) -> Node:
	return target_node


func has_sync_properties() -> bool:
	return false


func get_property_paths(_target: Node) -> Array:
	return []
