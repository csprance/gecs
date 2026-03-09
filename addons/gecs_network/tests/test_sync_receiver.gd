extends GdUnitTestSuite

## Test suite for SyncReceiver (Wave 0 — RED phase stubs)
## Tests define the behavioral contract for SYNC-01, SYNC-02, SYNC-03.
## All tests FAIL RED via assertion — SyncReceiver class does not exist yet.
## Plan 03 creates SyncReceiver and replaces these stubs with real tests.

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
# SYNC-01 / SYNC-02: Server authority checks
# ============================================================================


func test_server_rejects_non_owner():
	# Stub: RED — SyncReceiver does not exist yet.
	# Server receives batch for entity where net_id.peer_id != sender_id.
	# Entity properties must remain unchanged.
	# Plan 03: var receiver = SyncReceiver.new(mock_ns); receiver.handle_apply_sync_data(...)
	assert_bool(false).is_true()


func test_server_strips_cn_network_identity():
	# Stub: RED — SyncReceiver does not exist yet.
	# Server receives batch containing "CN_NetworkIdentity" key.
	# That key must be stripped; other props must be applied.
	# Plan 03: SyncReceiver strips identity key before applying component data.
	assert_bool(false).is_true()


func test_server_relays_to_clients():
	# Stub: RED — SyncReceiver does not exist yet.
	# Valid client update received on server must queue relay in SyncSender
	# so other clients receive the update.
	# Plan 03: SyncReceiver calls sender.queue_relay_data() after valid apply.
	assert_bool(false).is_true()


# ============================================================================
# SYNC-01: Client-side rejection rules
# ============================================================================


func test_client_rejects_non_server():
	# Stub: RED — SyncReceiver does not exist yet.
	# Client receives batch from peer_id=2 (not the server).
	# The batch must be rejected entirely.
	# Plan 03: SyncReceiver checks get_remote_sender_id() == 1 (server).
	assert_bool(false).is_true()


func test_client_skips_own_entity():
	# Stub: RED — SyncReceiver does not exist yet.
	# Client receives batch for a locally-owned entity.
	# The entity update must be skipped (client is authoritative for own entity).
	# Plan 03: SyncReceiver skips entities where net_id.peer_id == my_peer_id.
	assert_bool(false).is_true()


# ============================================================================
# SYNC-03: _applying_network_data guard and SPAWN_ONLY rejection
# ============================================================================


func test_applying_flag_set_during_apply():
	# Stub: RED — SyncReceiver does not exist yet.
	# _applying_network_data on the MockNetworkSync must be true while
	# handle_apply_sync_data() is executing, and false after it returns.
	# Plan 03: SyncReceiver sets _ns._applying_network_data guard around apply.
	assert_bool(false).is_true()


func test_spawn_only_entity_rejected():
	# Stub: RED — SyncReceiver does not exist yet.
	# An entity without CN_NetSync (spawn-only) must be rejected for
	# continuous update; SyncReceiver must not apply the data.
	# Plan 03: SyncReceiver checks entity.get_component(CN_NetSync) != null.
	assert_bool(false).is_true()
