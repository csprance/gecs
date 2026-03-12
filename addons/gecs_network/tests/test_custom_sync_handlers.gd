extends GdUnitTestSuite

## Test suite for custom sync handler hooks (ADV-03).
## RED stubs — SyncSender._custom_send_handlers and
## SyncReceiver._custom_receive_handlers do not yet exist.
## All tests fail with assertion errors (not parse/load errors).
## Per Phase 2 decision: use assert_bool(false).is_true() stubs when the
## implementation API does not yet exist.

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


class MockComponent:
	extends Component

	@export_group("HIGH")
	@export var health: int = 100


# ============================================================================
# TEST FIXTURES
# ============================================================================

var mock_ns: MockNetworkSync
var world: World


func before_each() -> void:
	world = World.new()
	mock_ns = MockNetworkSync.new(world)
	mock_ns.net_adapter._is_server = true


func after_each() -> void:
	world.free()


# ============================================================================
# RED STUBS — all fail until Plan 03 adds custom handler API to SyncSender /
# SyncReceiver / NetworkSync
# ============================================================================


func test_custom_send_handler_replaces_default() -> void:
	# Stub: SyncSender has no _custom_send_handlers dict yet
	# Expected: a callable registered via register_send_handler() is invoked
	# instead of CN_NetSync.check_changes_for_priority() for the named
	# component type.
	assert_bool(false).is_true()


func test_custom_send_handler_suppress() -> void:
	# Stub: SyncSender has no _custom_send_handlers dict yet
	# Expected: returning {} from a registered send handler causes that
	# component to be excluded from the outbound batch entirely.
	assert_bool(false).is_true()


func test_custom_receive_handler_replaces_default() -> void:
	# Stub: SyncReceiver has no _custom_receive_handlers dict yet
	# Expected: a callable registered via register_receive_handler() is called
	# instead of comp.set() for the named component type, and returns true to
	# indicate it handled the update.
	assert_bool(false).is_true()


func test_custom_receive_handler_still_updates_cache() -> void:
	# Stub: SyncReceiver has no _custom_receive_handlers dict yet
	# Expected: after a custom receive handler returns true, the network sync
	# still calls update_cache_silent() for each applied property so the change
	# detector does not echo the update back to the network.
	assert_bool(false).is_true()


func test_custom_receive_handler_fallthrough() -> void:
	# Stub: SyncReceiver has no _custom_receive_handlers dict yet
	# Expected: returning false from a registered receive handler causes the
	# default comp.set() path to execute as if no custom handler were present.
	assert_bool(false).is_true()
