extends GdUnitTestSuite

## Test suite for CN_NetSync (Wave 0 — RED phase stubs)
## Tests define the behavioral contract for SYNC-02 and SYNC-03.
## All tests FAIL RED via assertion — CN_NetSync class does not exist yet.
## Plan 02 creates CN_NetSync and replaces these stubs with real tests.

# ============================================================================
# MOCK OBJECTS
# ============================================================================


class MockNetAdapter:
	extends NetAdapter

	var _is_server: bool = true
	var _my_peer_id: int = 1
	var _remote_sender_id: int = 0

	func is_server() -> bool:
		return _is_server

	func get_my_peer_id() -> int:
		return _my_peer_id

	func get_remote_sender_id() -> int:
		return _remote_sender_id

	func _has_multiplayer() -> bool:
		return true

	func is_in_game() -> bool:
		return true


class MockNetworkSync:
	extends RefCounted

	# NOTE: NO sync_config field — removed in v2
	var _world: World
	var _applying_network_data: bool = false
	var _game_session_id: int = 42
	var net_adapter: MockNetAdapter
	var debug_logging: bool = false
	var unreliable_rpc_calls: Array = []
	var reliable_rpc_calls: Array = []

	func _init(w: World) -> void:
		_world = w
		net_adapter = MockNetAdapter.new()

	func _sync_components_unreliable(batch: Dictionary) -> void:
		unreliable_rpc_calls.append(batch)

	func _sync_components_reliable(batch: Dictionary) -> void:
		reliable_rpc_calls.append(batch)


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================


var world: World
var mock_ns: MockNetworkSync


func before_test():
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world
	mock_ns = MockNetworkSync.new(world)


func after_test():
	if is_instance_valid(world):
		for entity in world.entities.duplicate():
			world.remove_entity(entity)
			if is_instance_valid(entity):
				entity.free()
		world.free()
	world = null
	mock_ns = null


# ============================================================================
# SYNC-02 / SYNC-03: scan_entity_components scanner tests
# ============================================================================


func test_scanner_maps_export_group_to_priority():
	# Stub: RED — CN_NetSync does not exist yet.
	# Plan 02 creates CN_NetSync.scan_entity_components() which populates an
	# internal map; a component with @export_group("MEDIUM") has its property
	# in Priority.MEDIUM bucket.
	assert_bool(false).is_true()


func test_scanner_skips_spawn_only_props():
	# Stub: RED — CN_NetSync does not exist yet.
	# Properties under @export_group("SPAWN_ONLY") must NOT appear in any
	# priority bucket.
	assert_bool(false).is_true()


func test_scanner_skips_local_props():
	# Stub: RED — CN_NetSync does not exist yet.
	# Properties under @export_group("LOCAL") must NOT appear in any
	# priority bucket.
	assert_bool(false).is_true()


func test_scanner_skips_cn_net_sync_itself():
	# Stub: RED — CN_NetSync does not exist yet.
	# scan_entity_components() must not include CN_NetSync's own properties.
	assert_bool(false).is_true()


func test_scanner_skips_cn_network_identity():
	# Stub: RED — CN_NetSync does not exist yet.
	# scan_entity_components() must not include CN_NetworkIdentity properties.
	assert_bool(false).is_true()


# ============================================================================
# SYNC-02: check_changes_for_priority dirty tracking
# ============================================================================


func test_check_changes_returns_changed_props():
	# Stub: RED — CN_NetSync does not exist yet.
	# After mutating a component property, check_changes_for_priority(Priority.HIGH)
	# must include it in the returned Dictionary.
	assert_bool(false).is_true()


func test_check_changes_excludes_unchanged_props():
	# Stub: RED — CN_NetSync does not exist yet.
	# Second poll with no mutations must return an empty Dictionary.
	assert_bool(false).is_true()


func test_has_changed_float_approx():
	# Stub: RED — CN_NetSync does not exist yet.
	# Float values within epsilon must NOT be flagged as changed.
	# Values beyond epsilon MUST be flagged as changed.
	assert_bool(false).is_true()


# ============================================================================
# SYNC-03: update_cache_silent suppresses re-sync
# ============================================================================


func test_update_cache_silent_suppresses_resync():
	# Stub: RED — CN_NetSync does not exist yet.
	# After update_cache_silent(), the same value must not appear as changed
	# in the next poll (prevents sync echo loop).
	assert_bool(false).is_true()
