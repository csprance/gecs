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

enum Priority { REALTIME, HIGH, MEDIUM, LOW }  ## Every frame (~60 FPS)  ## 20 FPS  ## 10 FPS  ## 1 FPS

enum Reliability { UNRELIABLE, RELIABLE }  ## Fast, may drop packets (position, velocity)  ## Guaranteed delivery (health, authority changes)

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
## When this component is added to an entity with C_SyncEntity, native
## MultiplayerSynchronizer setup is triggered.
##
## Set to empty string "" to disable component-based triggering.
## In that case, ensure C_SyncEntity.target_node is set before adding
## the entity to the world, or call NetworkSync._auto_setup_native_sync() manually.
##
## Example: "C_Instantiated", "C_ModelReady", "C_Spawned"
@export var model_ready_component: String = ""

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
# CONFIGURATION - RECONCILIATION
# ============================================================================

## Enable periodic full state reconciliation
@export var enable_reconciliation: bool = true

## Seconds between full state reconciliation broadcasts (server only)
@export var reconciliation_interval: float = 30.0

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
	var class_name_str = component.get_script().get_global_name()
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
