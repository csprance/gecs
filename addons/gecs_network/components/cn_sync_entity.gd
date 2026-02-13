class_name CN_SyncEntity
extends Component
## CN_SyncEntity - Configuration component for native MultiplayerSynchronizer setup.
##
## Add this component to entities that should use Godot's native MultiplayerSynchronizer
## for transform/property replication. NetworkSync will automatically create and configure
## the synchronizer based on these settings.
##
## Features:
## - Automatic MultiplayerSynchronizer creation
## - Configurable sync properties (position, rotation, velocity, custom)
## - Advanced synchronizer options (intervals, visibility)
##
## Usage:
##   # Basic usage - sync position and rotation
##   entity.add_component(CN_SyncEntity.new())
##
##   # Custom configuration
##   var sync = CN_SyncEntity.new()
##   sync.sync_velocity = true
##   sync.custom_properties = ["health", "score"]
##   entity.add_component(sync)
##
## Note: Requires CN_NetworkIdentity to be present on the entity.

# ============================================================================
# SYNC PROPERTIES
# ============================================================================

## Whether to sync global_position (Vector3)
@export var sync_position: bool = true

## Whether to sync global_rotation (Vector3)
@export var sync_rotation: bool = true

## Whether to sync velocity property (if target has one)
## Only works with CharacterBody3D/RigidBody3D which have velocity property.
@export var sync_velocity: bool = false

## Additional properties to sync (property paths relative to target node)
## Example: ["health", "score", "custom_data:value"]
@export var custom_properties: Array[String] = []

# ============================================================================
# ADVANCED OPTIONS
# ============================================================================

## Mirrors MultiplayerSynchronizer.VisibilityUpdateMode.
## Component extends Resource (not Node), so we define a local enum.
enum VisibilityMode { IDLE, PHYSICS, NONE }

## Visibility mode for the MultiplayerSynchronizer.
@export var visibility_mode: VisibilityMode = VisibilityMode.IDLE

## Minimum time between sync updates (0 = every network tick).
## Higher values reduce bandwidth but increase latency.
@export var delta_interval: float = 0.0

## Override for replication interval (0 = use delta_interval).
## Allows separate control over replication timing.
@export var replication_interval: float = 0.0

## Whether the entity is visible to all peers by default.
## Set false to use visibility filters for interest management.
@export var public_visibility: bool = true

## Optional target node for synchronization.
## If null, the entity itself is used as the sync target.
## Useful when the entity contains a CharacterBody3D or RigidBody3D child.
## Note: Cannot use @export here - Component is not a Node. Set programmatically.
var target_node: Node = null

# ============================================================================
# METHODS
# ============================================================================


func _init(
	p_sync_position := sync_position,
	p_sync_rotation := sync_rotation,
	p_sync_velocity := sync_velocity,
) -> void:
	sync_position = p_sync_position
	sync_rotation = p_sync_rotation
	sync_velocity = p_sync_velocity


## Get the node to synchronize for this entity.
## Returns target_node if set, otherwise falls back to the entity itself.
## IMPORTANT: For entities with physics bodies (CharacterBody3D, RigidBody3D),
## target_node MUST be set explicitly after model instantiation, or sync will
## target the stationary Entity node instead of the moving body.
## @param entity: The entity this component belongs to
## @return: The node to attach MultiplayerSynchronizer to
func get_sync_target(entity: Entity) -> Node:
	if target_node != null and is_instance_valid(target_node):
		return target_node

	# Fallback to entity itself (only valid for entities without physics bodies)
	if entity != null and is_instance_valid(entity):
		return entity

	return null


## Check if this component has any properties configured for sync.
## Useful for validation before creating synchronizer.
func has_sync_properties() -> bool:
	return sync_position or sync_rotation or sync_velocity or not custom_properties.is_empty()


## Get list of property paths to sync based on configuration.
## @param target: The target node (for checking property existence)
## @return: Array of property path strings
func get_property_paths(target: Node) -> Array[String]:
	var paths: Array[String] = []

	if sync_position:
		paths.append("global_position")

	if sync_rotation:
		paths.append("global_rotation")

	if sync_velocity and target != null:
		# Check if target has velocity property (CharacterBody3D, RigidBody3D)
		if "velocity" in target:
			paths.append("velocity")

	# Add custom properties
	for prop in custom_properties:
		if prop not in paths:
			paths.append(prop)

	return paths
