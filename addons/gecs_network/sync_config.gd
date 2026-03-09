class_name SyncConfig
extends Resource
## Stub — registry removed in v2. Fields kept for handler backward compat until Phase 3/4.
## The Priority enum and component_priorities registry have moved to CN_NetSync.

@export var model_ready_component: String = ""
@export var transform_component: String = ""
@export var sync_relationships: bool = false
@export var enable_reconciliation: bool = false


func should_skip_component(_component: Resource) -> bool:
	return false  # Stub — always allow in Phase 2
