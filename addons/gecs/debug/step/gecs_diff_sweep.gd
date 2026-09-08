## GECSDiffSweep: catches silent component writes for the step debugger.
##
## Components that assign fields directly (no setter emitting
## [signal Component.property_changed]) leave no trace in the step journal.
## While the world is paused, [GECSStepper] runs [method diff] after every
## step: it compares every script variable of every component against the
## values cached by the previous [method rebase] / [method diff] and reports
## what changed. Writes that did go through an emitting setter are excluded via
## [method note_written] so they are not reported twice.[br]
## Cost is O(entities x component properties) per call, which is why it only
## runs while stepping: the world is paused, so the cost is invisible.
class_name GECSDiffSweep
extends RefCounted

## Script -> PackedStringArray of script variable names, cached per component type.
var _props_by_script: Dictionary = {}
## Component instance id -> {component, entity_id, entity_name, type, values}.
var _cache: Dictionary = {}
## Component instance id -> {property: true} for writes journaled since the last diff.
var _noted: Dictionary = {}


## Rebuild the baseline from the world's current state. Reports nothing.
func rebase(world: World) -> void:
	_cache.clear()
	_noted.clear()
	for entity in world.entities:
		if not is_instance_valid(entity):
			continue
		for comp in entity.components.values():
			if is_instance_valid(comp):
				_cache[comp.get_instance_id()] = _snapshot(entity, comp)


## Drop the baseline (the world resumed; nothing to compare against any more).
func clear() -> void:
	_cache.clear()
	_noted.clear()


## Mark a (component, property) pair as already journaled by an emitting setter
## so the next [method diff] refreshes its cached value without reporting it.
func note_written(component: Resource, property: String) -> void:
	if component == null or not is_instance_valid(component):
		return
	var iid := component.get_instance_id()
	if not _noted.has(iid):
		_noted[iid] = {}
	_noted[iid][property] = true


## Compare the world against the cached baseline and refresh the cache.
## Returns one record per silently changed property:
## [code][entity_instance_id, entity_name, component_type, property, old_value, new_value][/code].
## Components seen for the first time are cached silently (their creation is
## already journaled as a COMP_ADD / ENTITY_ADD op); cached components no longer
## present in the world are dropped.
func diff(world: World) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for entity in world.entities:
		if not is_instance_valid(entity):
			continue
		for comp in entity.components.values():
			if not is_instance_valid(comp):
				continue
			var iid: int = comp.get_instance_id()
			seen[iid] = true
			var entry = _cache.get(iid)
			if entry == null:
				_cache[iid] = _snapshot(entity, comp)
				continue
			var noted: Dictionary = _noted.get(iid, {})
			var values: Dictionary = entry.values
			for prop in _props_for(comp):
				var current = comp.get(prop)
				if noted.has(prop):
					values[prop] = _deep_copy(current)
					continue
				var previous = values.get(prop)
				if _has_changed(previous, current):
					out.append(
						[entity.get_instance_id(), String(entity.name), entry.type, prop, previous, current]
					)
					values[prop] = _deep_copy(current)
	for iid in _cache.keys():
		if not seen.has(iid):
			_cache.erase(iid)
	_noted.clear()
	return out


func _snapshot(entity: Entity, comp: Resource) -> Dictionary:
	var values := {}
	for prop in _props_for(comp):
		values[prop] = _deep_copy(comp.get(prop))
	return {
		"component": comp,
		"entity_id": entity.get_instance_id(),
		"entity_name": String(entity.name),
		"type": GECSStepper.type_name_of(comp),
		"values": values,
	}


## Every script variable of the component's type, exported or not, minus the
## framework's own back-reference. Cached per Script.
func _props_for(comp: Resource) -> PackedStringArray:
	var script = comp.get_script()
	if script == null:
		return PackedStringArray()
	if _props_by_script.has(script):
		return _props_by_script[script]
	var names := PackedStringArray()
	for info in script.get_script_property_list():
		if not (info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if info.name == "parent":
			continue
		names.append(info.name)
	_props_by_script[script] = names
	return names


## Approximate comparison so float drift does not register as a write.
## Ported from CN_NetSync so both diff engines agree on what counts as a change.
static func _has_changed(old_value: Variant, new_value: Variant) -> bool:
	if old_value == null and new_value == null:
		return false
	if old_value == null or new_value == null:
		return true
	if typeof(old_value) != typeof(new_value):
		return true
	match typeof(old_value):
		TYPE_FLOAT:
			return not is_equal_approx(old_value, new_value)
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_QUATERNION, TYPE_COLOR:
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
				and old_value.basis.is_equal_approx(new_value.basis)
			)
	return old_value != new_value


## Containers are copied so later in-place mutation shows up as a change;
## everything else is a value type or an Object reference.
static func _deep_copy(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY, TYPE_DICTIONARY:
			return value.duplicate(true)
	return value
