class_name CN_NetSync
extends Component
## CN_NetSync — per-entity property scanner and dirty-tracker for network sync.[br]
## [br]
## Add one CN_NetSync to any entity you want to sync. Call scan_entity_components() [br]
## once after adding/removing sibling components to build the scan tables. [br]
## Then call check_changes_for_priority(priority) each tick to get changed props. [br]
##[br]
## Property grouping via @export_group in sibling components:[br]
##   @export_group(CN_NetSync.REALTIME)  # ~60 Hz [br]
##   @export_group(CN_NetSync.HIGH)      # 20 Hz (default if no group)[br]
##   @export_group(CN_NetSync.MEDIUM)    # 10 Hz[br]
##   @export_group(CN_NetSync.LOW)       # 2 Hz (default, configurable via gecs/network/sync/low_hz)[br]
##   @export_group(CN_NetSync.SPAWN_ONLY)# sent at spawn only (SpawnManager handles it)[br]
##   @export_group(CN_NetSync.LOCAL)     # never synced[br]

# ============================================================================
# SYNC TIER CONSTANTS — use with @export_group() for autocomplete & typo safety
# ============================================================================

const REALTIME = "REALTIME" ## ~60 Hz, unreliable — critical real-time data
const HIGH = "HIGH" ## 20 Hz, unreliable — velocity, input, animation
const MEDIUM = "MEDIUM" ## 10 Hz, reliable — health, AI state
const LOW = "LOW" ## 2 Hz, reliable — inventory, stats
const SPAWN_ONLY = "SPAWN_ONLY" ## Once at spawn, reliable — initial position/velocity
const LOCAL = "LOCAL" ## Never synced — client-only state

# ============================================================================
# PRIORITY ENUM & CONSTANTS
# ============================================================================

enum Priority {
	REALTIME = 0, ## Every frame (~60 FPS)
	HIGH = 1, ## 20 FPS
	MEDIUM = 2, ## 10 FPS
	LOW = 3, ## 1 FPS
}

## Maps @export_group name strings to Priority int values.
## SPAWN_ONLY and LOCAL are sentinel values — properties in these groups
## are excluded from the dirty cache entirely.
const PRIORITY_MAP: Dictionary = {
	"REALTIME": Priority.REALTIME,
	"HIGH": Priority.HIGH,
	"MEDIUM": Priority.MEDIUM,
	"LOW": Priority.LOW,
	"SPAWN_ONLY": -2,  # Sentinel — excluded from dirty cache; SpawnManager handles
	"LOCAL": -1,       # Sentinel — never synced
}

# ============================================================================
# INTERNAL STATE — keyed by component instance ID (int)
# ============================================================================

## Cache of last-known values per component: { inst_id: { prop_name: value } }
var _cache_by_comp: Dictionary = {}

## Properties grouped by priority per component: { inst_id: { priority_int: [prop_names] } }
var _props_by_comp: Dictionary = {}

## Direct component references (for live reads): { inst_id: Component }
var _comp_refs: Dictionary = {}

## Component type names for wire format: { inst_id: String }
var _comp_type_names: Dictionary = {}

## Sync interval seconds by priority (populated from ProjectSettings in _init)
var _intervals: Dictionary = {}


# ============================================================================
# INITIALIZATION
# ============================================================================


func _init() -> void:
	_intervals = {
		Priority.REALTIME: 0.0,
		Priority.HIGH: 1.0 / ProjectSettings.get_setting("gecs/network/sync/high_hz", 20),
		Priority.MEDIUM: 1.0 / ProjectSettings.get_setting("gecs/network/sync/medium_hz", 10),
		Priority.LOW: 1.0 / ProjectSettings.get_setting("gecs/network/sync/low_hz", 2),
	}


# ============================================================================
# SCANNING
# ============================================================================


## Scan all sibling components on entity and build internal priority tables.
## Call once after adding/removing components; rebuilds all caches from scratch.
## Skips: self (CN_NetSync), CN_NetworkIdentity, and components without a script.
func scan_entity_components(entity: Entity) -> void:
	_cache_by_comp.clear()
	_props_by_comp.clear()
	_comp_refs.clear()
	_comp_type_names.clear()

	for comp_key in entity.components.keys():
		var comp = entity.components[comp_key]
		if not is_instance_valid(comp):
			continue
		if comp is CN_NetSync:
			continue # Never scan ourselves
		if comp is CN_NetworkIdentity:
			continue # Ownership spoofing prevention — CRITICAL
		if comp is CN_NativeSync:
			continue # Native sync handles its own target node — don't batch-RPC its config
		var script = comp.get_script()
		if script == null:
			continue # Built-in resource, no exported script properties

		var inst_id: int = comp.get_instance_id()
		_comp_refs[inst_id] = comp

		var global_name: String = script.get_global_name()
		if global_name == "":
			global_name = script.resource_path.get_file().get_basename()
		_comp_type_names[inst_id] = global_name

		_props_by_comp[inst_id] = _scan_component(comp)

		# Initialize cache with current values for all synced priorities
		_cache_by_comp[inst_id] = {}
		for priority in _props_by_comp[inst_id].keys():
			for prop_name in _props_by_comp[inst_id][priority]:
				_cache_by_comp[inst_id][prop_name] = _deep_copy(comp.get(prop_name))


## Scan a single component's exported properties and group by priority.
## Returns: { priority_int: [prop_name, ...] }
func _scan_component(comp: Component) -> Dictionary:
	var result: Dictionary = {}
	var current_priority: int = Priority.HIGH # Default when no @export_group set

	for prop_info in comp.get_script().get_script_property_list():
		var usage: int = prop_info.usage

		# @export_group annotation — update current priority tracking
		if usage & PROPERTY_USAGE_GROUP:
			var group_name: String = prop_info.name
			if group_name in PRIORITY_MAP:
				current_priority = PRIORITY_MAP[group_name]
			else:
				push_warning(
					(
						"[CN_NetSync] Unrecognized @export_group '%s' — defaulting to HIGH priority"
						% group_name
					)
				)
				current_priority = Priority.HIGH
			continue

		# Skip category markers
		if usage & PROPERTY_USAGE_CATEGORY:
			continue

		# Only collect editor-exported properties
		if not (usage & PROPERTY_USAGE_EDITOR):
			continue

		# Skip SPAWN_ONLY (-2) and LOCAL (-1) — these are handled elsewhere
		if current_priority < 0:
			continue

		var prop_name: String = prop_info.name
		if current_priority not in result:
			result[current_priority] = []
		result[current_priority].append(prop_name)

	return result


# ============================================================================
# CHANGE DETECTION
# ============================================================================


## Check all tracked components for property changes at the given priority level.
## Returns wire-format dict: { "CompTypeName": { "prop_name": new_value, ... } }
## Only components with at least one changed property are included.
func check_changes_for_priority(priority: int) -> Dictionary:
	var result: Dictionary = {}

	for inst_id in _comp_refs.keys():
		if not is_instance_valid(_comp_refs[inst_id]):
			continue
		var comp: Component = _comp_refs[inst_id]

		var props_at_priority: Array = _props_by_comp[inst_id].get(priority, [])
		if props_at_priority.is_empty():
			continue

		var comp_cache: Dictionary = _cache_by_comp[inst_id]
		var changed: Dictionary = {}

		for prop_name in props_at_priority:
			var current_value: Variant = comp.get(prop_name)
			var cached_value: Variant = comp_cache.get(prop_name)

			if _has_changed(cached_value, current_value):
				changed[prop_name] = current_value
				comp_cache[prop_name] = _deep_copy(current_value)

		if not changed.is_empty():
			result[_comp_type_names[inst_id]] = changed

	return result


## Update cache without triggering change detection.
## Called by SyncReceiver after applying remote data to avoid echo sync loops.
func update_cache_silent(comp: Component, prop: String, value: Variant) -> void:
	var inst_id: int = comp.get_instance_id()
	if inst_id in _cache_by_comp:
		_cache_by_comp[inst_id][prop] = _deep_copy(value)


# ============================================================================
# INTERNAL HELPERS — ported verbatim from sync_component.gd
# ============================================================================


## Type-aware approximate comparison for floating-point types.
## Returns true if old_value and new_value should be considered different.
# gdlint: disable=max-returns
func _has_changed(old_value: Variant, new_value: Variant) -> bool:
	# Null checks
	if old_value == null and new_value == null:
		return false
	if old_value == null or new_value == null:
		return true

	var old_type: int = typeof(old_value)
	var new_type: int = typeof(new_value)

	if old_type != new_type:
		return true

	match old_type:
		TYPE_FLOAT:
			return not is_equal_approx(old_value, new_value)
		TYPE_VECTOR2:
			return not old_value.is_equal_approx(new_value)
		TYPE_VECTOR3:
			return not old_value.is_equal_approx(new_value)
		TYPE_VECTOR4:
			return not old_value.is_equal_approx(new_value)
		TYPE_TRANSFORM2D:
			return not (
				old_value.origin.is_equal_approx(new_value.origin)
				and old_value.x.is_equal_approx(new_value.x)
				and old_value.y.is_equal_approx(new_value.y)
			)
		TYPE_TRANSFORM3D:
			return not (
				old_value.origin.is_equal_approx(new_value.origin)
				and old_value.basis.x.is_equal_approx(new_value.basis.x)
				and old_value.basis.y.is_equal_approx(new_value.basis.y)
				and old_value.basis.z.is_equal_approx(new_value.basis.z)
			)
		TYPE_QUATERNION:
			return not old_value.is_equal_approx(new_value)
		TYPE_COLOR:
			return not old_value.is_equal_approx(new_value)

	return old_value != new_value


## Value-type-aware deep copy to avoid reference aliasing in the dirty cache.
func _deep_copy(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4:
			return value # Value types in Godot — no copy needed
		TYPE_TRANSFORM2D, TYPE_TRANSFORM3D, TYPE_QUATERNION:
			return value # Value types
		TYPE_ARRAY:
			return value.duplicate(true)
		TYPE_DICTIONARY:
			return value.duplicate(true)
		_:
			return value # Primitives (int, float, bool, String) are value types
