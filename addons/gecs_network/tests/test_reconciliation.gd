extends GdUnitTestSuite

## Test suite for SyncReconciliationHandler (ADV-02).
## RED stubs — SyncReconciliationHandler does not yet exist.
## All tests fail with assertion errors (not parse/load errors).
## Per Phase 2 decision: use assert_bool(false).is_true() stubs when the
## implementation class does not yet exist.

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

	var _world: World
	var _applying_network_data: bool = false
	var _game_session_id: int = 42
	var net_adapter: MockNetAdapter
	var debug_logging: bool = false
	var full_state_rpc_calls: Array = []
	var _spawn_manager = null

	func _init(w: World) -> void:
		_world = w
		net_adapter = MockNetAdapter.new()

	func _sync_full_state(payload: Dictionary) -> void:
		full_state_rpc_calls.append(payload)


class MockComponent:
	extends Component

	@export_group("HIGH")
	@export var value: int = 0


# ============================================================================
# TEST FIXTURES
# ============================================================================

var mock_ns: MockNetworkSync
var world: World
var handler  # SyncReconciliationHandler (does not exist yet)


func before_each() -> void:
	world = World.new()
	mock_ns = MockNetworkSync.new(world)
	mock_ns.net_adapter._is_server = true


func after_each() -> void:
	world.free()


# ============================================================================
# RED STUBS — all fail until Plan 02 implements SyncReconciliationHandler
# ============================================================================


func test_reconciliation_fires_at_interval() -> void:
	# Stub: SyncReconciliationHandler does not exist yet
	# Expected: timer accumulates delta and calls broadcast_full_state() once
	# the configured interval is reached.
	assert_bool(false).is_true()


func test_broadcast_full_state_serializes_networked_entities() -> void:
	# Stub: SyncReconciliationHandler does not exist yet
	# Expected: all entities with CN_NetworkIdentity are serialized into the
	# full-state RPC payload sent to all peers.
	assert_bool(false).is_true()


func test_handle_full_state_applies_component_data() -> void:
	# Stub: SyncReconciliationHandler does not exist yet
	# Expected: received full-state payload applies component values to remote
	# entities via _apply_component_data on SyncReceiver.
	assert_bool(false).is_true()


func test_handle_full_state_skips_local_entities() -> void:
	# Stub: SyncReconciliationHandler does not exist yet
	# Expected: entities where net_id.peer_id matches the local peer id are NOT
	# overwritten by the incoming full-state snapshot.
	assert_bool(false).is_true()


func test_handle_full_state_removes_ghost_entities() -> void:
	# Stub: SyncReconciliationHandler does not exist yet
	# Expected: entities present locally but absent from the server's full-state
	# snapshot are removed from the world (ghost cleanup).
	assert_bool(false).is_true()


func test_reconciliation_interval_project_setting() -> void:
	# Stub: ProjectSetting "gecs_network/sync/reconciliation_interval" not
	# registered yet (added by plugin in Plan 02).
	# Expected: ProjectSettings.get_setting("gecs_network/sync/reconciliation_interval")
	# returns the default value 30.0.
	assert_bool(false).is_true()
