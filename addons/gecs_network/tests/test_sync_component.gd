extends GdUnitTestSuite

## Test suite for SyncComponent
## Tests property parsing, change detection, priority lookup, cache management,
## and type-aware comparison (_has_changed).

# ============================================================================
# INLINE TEST COMPONENT
# ============================================================================


class TestSyncComp:
	extends SyncComponent

	@export_group("HIGH")
	@export var position: Vector3 = Vector3.ZERO:
		set(value):
			var old_value = position
			position = value
			if old_value != value:
				property_changed.emit(self, "position", old_value, value)

	@export var speed: float = 0.0:
		set(value):
			var old_value = speed
			speed = value
			if old_value != value:
				property_changed.emit(self, "speed", old_value, value)

	@export_group("MEDIUM")
	@export var health: int = 100:
		set(value):
			var old_value = health
			health = value
			if old_value != value:
				property_changed.emit(self, "health", old_value, value)

	@export_group("LOW")
	@export var xp: int = 0:
		set(value):
			var old_value = xp
			xp = value
			if old_value != value:
				property_changed.emit(self, "xp", old_value, value)

	@export_group("LOCAL")
	@export var client_only: bool = false


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

var comp: TestSyncComp


func before_test():
	comp = TestSyncComp.new()


func after_test():
	comp = null


# ============================================================================
# PROPERTY PARSING
# ============================================================================


func test_parse_groups_high_properties():
	comp._ensure_initialized()
	var high_props = comp._props_by_priority.get(SyncConfig.Priority.HIGH, [])
	assert_bool("position" in high_props).is_true()
	assert_bool("speed" in high_props).is_true()


func test_parse_groups_medium_properties():
	comp._ensure_initialized()
	var med_props = comp._props_by_priority.get(SyncConfig.Priority.MEDIUM, [])
	assert_bool("health" in med_props).is_true()


func test_parse_groups_low_properties():
	comp._ensure_initialized()
	var low_props = comp._props_by_priority.get(SyncConfig.Priority.LOW, [])
	assert_bool("xp" in low_props).is_true()


func test_parse_groups_local_properties():
	comp._ensure_initialized()
	var local_props = comp._props_by_priority.get(-1, [])
	assert_bool("client_only" in local_props).is_true()


func test_local_properties_not_in_sync_cache():
	comp._ensure_initialized()
	assert_bool(comp._sync_cache.has("client_only")).is_false()


# ============================================================================
# CHANGE DETECTION
# ============================================================================


func test_check_changes_returns_changed_high_properties():
	comp._ensure_initialized()
	comp.position = Vector3(10, 20, 30)
	var changed = comp.check_changes_for_priority(SyncConfig.Priority.HIGH)
	assert_bool(changed.has("position")).is_true()
	assert_that(changed["position"]).is_equal(Vector3(10, 20, 30))


func test_check_changes_returns_empty_when_no_change():
	comp._ensure_initialized()
	# Nothing has changed since initialization
	var changed = comp.check_changes_for_priority(SyncConfig.Priority.HIGH)
	assert_dict(changed).is_empty()


func test_check_changes_updates_cache():
	comp._ensure_initialized()
	comp.health = 50
	var changed = comp.check_changes_for_priority(SyncConfig.Priority.MEDIUM)
	assert_bool(changed.has("health")).is_true()

	# Second call should return empty (cache updated)
	var changed2 = comp.check_changes_for_priority(SyncConfig.Priority.MEDIUM)
	assert_dict(changed2).is_empty()


func test_local_properties_excluded_from_sync_cache():
	comp._ensure_initialized()
	# LOCAL properties are not added to the sync cache
	# so NetworkSync (which only queries non-LOCAL priorities) never syncs them
	assert_bool(comp._sync_cache.has("client_only")).is_false()
	# But HIGH properties ARE in the cache
	assert_bool(comp._sync_cache.has("position")).is_true()


# ============================================================================
# PRIORITY LOOKUP
# ============================================================================


func test_get_priority_for_property_position_is_high():
	var priority = comp.get_priority_for_property("position")
	assert_int(priority).is_equal(SyncConfig.Priority.HIGH)


func test_get_priority_for_property_health_is_medium():
	var priority = comp.get_priority_for_property("health")
	assert_int(priority).is_equal(SyncConfig.Priority.MEDIUM)


func test_get_priority_for_property_xp_is_low():
	var priority = comp.get_priority_for_property("xp")
	assert_int(priority).is_equal(SyncConfig.Priority.LOW)


func test_get_priority_for_property_unknown_defaults_to_high():
	var priority = comp.get_priority_for_property("nonexistent_prop")
	assert_int(priority).is_equal(SyncConfig.Priority.HIGH)


func test_get_priority_for_property_local():
	var priority = comp.get_priority_for_property("client_only")
	assert_int(priority).is_equal(-1)


# ============================================================================
# CACHE
# ============================================================================


func test_update_cache_silent_updates_without_signal():
	comp._ensure_initialized()
	var signal_emitted = false
	comp.property_changed.connect(func(_c, _p, _o, _n): signal_emitted = true)
	comp.update_cache_silent("position", Vector3(5, 5, 5))
	assert_bool(signal_emitted).is_false()
	# Cache should be updated
	assert_that(comp._sync_cache["position"]).is_equal(Vector3(5, 5, 5))


# ============================================================================
# TYPE-AWARE COMPARISON (_has_changed)
# ============================================================================


func test_has_changed_float_approx_equal():
	# Nearly-equal floats should not count as changed
	assert_bool(comp._has_changed(1.0, 1.0 + 1e-10)).is_false()


func test_has_changed_float_different():
	assert_bool(comp._has_changed(1.0, 2.0)).is_true()


func test_has_changed_vector3_approx_equal():
	var v1 = Vector3(1.0, 2.0, 3.0)
	var v2 = Vector3(1.0 + 1e-10, 2.0, 3.0)
	assert_bool(comp._has_changed(v1, v2)).is_false()


func test_has_changed_vector3_different():
	var v1 = Vector3(1.0, 2.0, 3.0)
	var v2 = Vector3(10.0, 2.0, 3.0)
	assert_bool(comp._has_changed(v1, v2)).is_true()


func test_has_changed_int_same():
	assert_bool(comp._has_changed(42, 42)).is_false()


func test_has_changed_int_different():
	assert_bool(comp._has_changed(42, 43)).is_true()


func test_has_changed_bool_same():
	assert_bool(comp._has_changed(true, true)).is_false()


func test_has_changed_bool_different():
	assert_bool(comp._has_changed(true, false)).is_true()


func test_has_changed_string_same():
	assert_bool(comp._has_changed("hello", "hello")).is_false()


func test_has_changed_string_different():
	assert_bool(comp._has_changed("hello", "world")).is_true()


func test_has_changed_both_null():
	assert_bool(comp._has_changed(null, null)).is_false()


func test_has_changed_one_null():
	assert_bool(comp._has_changed(null, 42)).is_true()
	assert_bool(comp._has_changed(42, null)).is_true()


func test_has_changed_different_types():
	assert_bool(comp._has_changed(42, "42")).is_true()
