class_name SyncConfig
extends Resource
## SyncConfig - Configure network synchronization priorities and filtering for components.
##
## Components can be assigned different sync priorities:
## - REALTIME: Every frame (~60 FPS) - For position, rotation
## - HIGH: 20 FPS - For velocity, input state
## - MEDIUM: 10 FPS - For health, AI state
## - LOW: 1 FPS - For XP, inventory, stats
##
## Filtering modes:
## - Blacklist (default): Skip components in skip_component_types
## - Whitelist: Only sync components in sync_only_components
##
## Usage:
##   var config = SyncConfig.new()
##   config.component_priorities["C_Velocity"] = SyncConfig.Priority.HIGH
##   config.skip_component_types = ["C_Transform"]  # Native sync handles it

# ============================================================================
# ENUMS
# ============================================================================

enum Priority {
	REALTIME, ## Every frame (~60 FPS)
	HIGH, ## 20 FPS
	MEDIUM, ## 10 FPS
	LOW, ## 1 FPS
}

enum Reliability {
	UNRELIABLE, ## Fast, may drop packets (position, velocity)
	RELIABLE, ## Guaranteed delivery (health, authority changes)
}

# ============================================================================
# CONSTANTS
# ============================================================================

## Seconds between syncs per priority level
const INTERVALS := {
	Priority.REALTIME: 0.0, Priority.HIGH: 0.05, Priority.MEDIUM: 0.1, Priority.LOW: 1.0  # Every frame  # 20 FPS  # 10 FPS  # 1 FPS
}

## Reliability by priority (higher priority = unreliable for speed)
const RELIABILITY_BY_PRIORITY := {
	Priority.REALTIME: Reliability.UNRELIABLE,
	Priority.HIGH: Reliability.UNRELIABLE,
	Priority.MEDIUM: Reliability.RELIABLE,
	Priority.LOW: Reliability.RELIABLE
}

# ============================================================================
# CONFIGURATION - PRIORITIES
# ============================================================================

## Map component class names to sync priority.
## Key: Component class name (e.g., "C_Velocity")
## Value: Priority enum value
##
## NOTE: This should be configured by the PROJECT, not the addon.
## Create a SyncConfig resource or subclass with your project's component priorities.
## Example:
##   component_priorities = {
##       "C_Velocity": Priority.HIGH,
##       "C_Health": Priority.MEDIUM,
##       "C_PlayerXP": Priority.LOW,
##   }
@export var component_priorities: Dictionary = {}

# ============================================================================
# CONFIGURATION - FILTERING
# ============================================================================

## Component types to skip during RPC sync (blacklist mode).
## These components are NOT synced via RPC - typically because native
## MultiplayerSynchronizer handles them, or they're client-only.
##
## NOTE: This should be configured by the PROJECT, not the addon.
## Example: Skip transform if native sync handles it:
##   skip_component_types = ["C_Transform"]
@export var skip_component_types: Array[String] = []

## If not empty, ONLY sync components in this list (whitelist mode).
## Overrides skip_component_types when set.
@export var sync_only_components: Array[String] = []

# ============================================================================
# CONFIGURATION - MODEL READY DETECTION
# ============================================================================

## Component name that signals when an entity's model/body is ready.
## When this component is added to an entity with CN_SyncEntity, native
## MultiplayerSynchronizer setup is triggered.
##
## Set to empty string "" to disable component-based triggering.
## In that case, ensure CN_SyncEntity.target_node is set before adding
## the entity to the world, or call NetworkSync._auto_setup_native_sync() manually.
##
## Example: "C_Instantiated", "C_ModelReady", "C_Spawned"
@export var model_ready_component: String = ""

## Script reference for model_ready_component (for instantiation).
## Set this to preload the script so NetworkSync can add the marker component
## after sync-instantiating a model.
##
## Example: preload("res://game/components/c_instantiated.gd")
var model_ready_class: GDScript = null

# ============================================================================
# CONFIGURATION - TRANSFORM COMPONENT
# ============================================================================

## Component name for transform/position data.
## Used for:
## - Syncing Node3D position after entity spawn
## - Bundling position+rotation updates together
## - Position snapshot sync on peer reconnect
##
## The component must have `position: Vector3` and `rotation: Vector3` properties.
## Set to empty string "" to disable transform-specific handling.
##
## Example: "C_Transform", "C_Position", "C_Spatial"
@export var transform_component: String = ""

# ============================================================================
# CONFIGURATION - MODEL INSTANTIATION (for native sync timing)
# ============================================================================

## Component name that contains model scene path (e.g., "C_Model").
## When set, NetworkSync will instantiate the model synchronously during
## entity spawn to ensure node structure exists before sync data arrives.
## Set to empty string "" to disable addon-managed model instantiation.
##
## The component must have the properties specified below.
@export var model_component: String = ""

## Property name on model_component that contains the scene path (PackedScene).
## Example: "model_scene_path"
@export var model_scene_path_property: String = "model_scene_path"

## Property name on model_component for storing the instantiated model reference.
## Example: "model_instance"
@export var model_instance_property: String = "model_instance"

## Property name on model_component to check/set if model is already instantiated.
## Example: "is_instantiated"
@export var model_instantiated_property: String = "is_instantiated"

## Component name that holds CharacterBody3D/RigidBody3D reference (e.g., "C_CharacterBody3D").
## Used to set the body reference after model instantiation.
## Set to empty string "" if not using physics bodies.
@export var character_body_component: String = ""

## Property name on character_body_component for the body reference.
## Example: "body"
@export var character_body_property: String = "body"

## Component name that holds animation references (e.g., "C_AnimationRig").
## Used to set animation_player and rig_node references after model instantiation.
## Set to empty string "" if not using animations.
@export var animation_rig_component: String = ""

## Property name for the visual rig node reference (child node named "Rig").
## Example: "rig_node"
@export var animation_rig_property: String = "rig_node"

## Property name for the AnimationPlayer reference.
## Example: "animation_player"
@export var animation_player_property: String = "animation_player"

## Child node name to look for as the visual rig.
## Example: "Rig"
@export var animation_rig_node_name: String = "Rig"

## Child node name to look for as the AnimationPlayer.
## Example: "AnimationPlayer"
@export var animation_player_node_name: String = "AnimationPlayer"

## Property name on animation_rig_component for the AnimationTree reference.
## Set to empty string "" to disable AnimationTree lookup.
## Example: "animation_tree"
@export var animation_tree_property: String = ""

## Child node name to look for as the AnimationTree.
## Example: "AnimationTree"
@export var animation_tree_node_name: String = ""

# ============================================================================
# CONFIGURATION - RECONCILIATION
# ============================================================================

## Enable periodic full state reconciliation
@export var enable_reconciliation: bool = true

## Seconds between full state reconciliation broadcasts (server only)
@export var reconciliation_interval: float = 30.0

## Enable relationship synchronization (creation recipes)
@export var sync_relationships: bool = true

# ============================================================================
# CONFIGURATION - ENTITY CATEGORIZATION
# ============================================================================

## Entity categories for diagnostic logging.
## Maps category name (e.g., "enemy", "player") to an Array of component class names.
## Entities with any of the listed components are classified into that category.
##
## Example:
##   entity_categories = {
##       "enemy": ["C_EnemyAI"],
##       "player": ["C_Player"],
##   }
##
## If empty, entity categorization falls back to peer_id-based heuristic:
## - peer_id > 0: player
## - peer_id <= 0: other
@export var entity_categories: Dictionary = {}

# Legacy alias for backwards compatibility
var priorities: Dictionary:
	get:
		return component_priorities
	set(value):
		component_priorities = value

# ============================================================================
# PRIORITY METHODS
# ============================================================================


## Get the sync priority for a component
## Returns MEDIUM as default if component type not configured
func get_priority(component: Component) -> Priority:
	var script = component.get_script()
	if script == null:
		return Priority.MEDIUM

	var class_name_str = script.get_global_name()
	if class_name_str == "":
		# Fallback to script path for anonymous classes
		class_name_str = script.resource_path.get_file().get_basename()

	return component_priorities.get(class_name_str, Priority.MEDIUM)


## Get the sync priority by class name string
func get_priority_by_name(class_name_str: String) -> Priority:
	return component_priorities.get(class_name_str, Priority.MEDIUM)


## Get the sync interval in seconds for a priority level
static func get_interval(priority: Priority) -> float:
	return INTERVALS.get(priority, 0.1)


## Check if a priority should sync this frame based on accumulated time
static func should_sync(priority: Priority, accumulated_time: float) -> bool:
	var interval = get_interval(priority)
	if interval == 0.0:
		return true  # REALTIME syncs every frame
	return accumulated_time >= interval


## Get the reliability mode for a priority level
static func get_reliability(priority: Priority) -> Reliability:
	return RELIABILITY_BY_PRIORITY.get(priority, Reliability.RELIABLE)


# ============================================================================
# FILTERING METHODS
# ============================================================================


## Check if a component type should be skipped (not synced via RPC).
## @param component_type: Component class name string
## @return: True if component should be skipped
func should_skip(component_type: String) -> bool:
	# Whitelist mode: only sync components in sync_only_components
	if not sync_only_components.is_empty():
		return component_type not in sync_only_components

	# Blacklist mode: skip components in skip_component_types
	return component_type in skip_component_types


## Check if a component instance should be skipped.
## Convenience method that extracts the class name.
## @param component: Component instance to check
## @return: True if component should be skipped
func should_skip_component(component: Component) -> bool:
	if component == null:
		return true

	var script = component.get_script()
	if script == null:
		return true

	var class_name_str = script.get_global_name()
	if class_name_str == "":
		# Fallback to script path for anonymous classes
		class_name_str = script.resource_path.get_file().get_basename()

	return should_skip(class_name_str)


# ============================================================================
# ENTITY CATEGORIZATION METHODS
# ============================================================================


## Get the category for an entity based on its components.
## @param entity: Entity to categorize
## @return: Category name (e.g., "enemy", "player") or "other" if no match
func get_entity_category(entity: Entity) -> String:
	# If no categories configured, fall back to peer_id heuristic
	if entity_categories.is_empty():
		var net_id = entity.get_component(CN_NetworkIdentity)
		if net_id and net_id.peer_id > 0:
			return "player"
		return "other"

	# Check each category's component list
	for category_name in entity_categories.keys():
		var component_names = entity_categories[category_name]
		if not component_names is Array:
			continue

		# Check if entity has any of the category's components
		for comp_name in component_names:
			if _entity_has_component_by_name(entity, comp_name):
				return category_name

	# No match found
	return "other"


## Helper: Check if entity has a component by class name
func _entity_has_component_by_name(entity: Entity, comp_name: String) -> bool:
	for comp_path in entity.components.keys():
		var comp = entity.components[comp_path]
		var script = comp.get_script()
		if script == null:
			continue

		var class_name_str = script.get_global_name()
		if class_name_str == "":
			# Fallback to script path for anonymous classes
			class_name_str = script.resource_path.get_file().get_basename()

		if class_name_str == comp_name:
			return true

	return false
