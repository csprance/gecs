extends GdUnitTestSuite

## Test suite for SyncSender (Wave 0 — RED phase stubs)
## Tests define the behavioral contract for SYNC-01.
## All tests FAIL RED via assertion — SyncSender class does not exist yet.
## Plan 03 creates SyncSender and replaces these stubs with real tests.

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
# SYNC-01: Timer accumulator / frequency dispatch
# ============================================================================


func test_realtime_fires_every_tick():
	# Stub: RED — SyncSender does not exist yet.
	# After a single tick(0.016), unreliable_rpc_calls must have an entry
	# (REALTIME priority always fires every tick).
	# Plan 03: var sender = SyncSender.new(mock_ns); sender.tick(0.016)
	assert_bool(false).is_true()


func test_high_fires_at_20hz():
	# Stub: RED — SyncSender does not exist yet.
	# After 1/20 seconds (0.05) accumulated, unreliable_rpc_calls must have an
	# entry. Before that threshold (e.g. after 0.04 s only), it must not.
	# Plan 03: SyncSender timer accumulator test at HIGH priority.
	assert_bool(false).is_true()


func test_medium_fires_at_10hz():
	# Stub: RED — SyncSender does not exist yet.
	# After 1/10 seconds (0.1) accumulated, reliable_rpc_calls must have an entry.
	# Plan 03: SyncSender timer accumulator test at MEDIUM priority.
	assert_bool(false).is_true()


func test_low_fires_at_2hz():
	# Stub: RED — SyncSender does not exist yet.
	# After 0.5 seconds accumulated, reliable_rpc_calls must have an entry.
	# Plan 03: SyncSender timer accumulator test at LOW priority.
	assert_bool(false).is_true()


# ============================================================================
# SYNC-01: Batch format and relay dispatch
# ============================================================================


func test_batch_format():
	# Stub: RED — SyncSender does not exist yet.
	# The outbound batch must match wire format:
	# { entity_id: { comp_type: { prop: value } } }
	# Plan 03: verify SyncSender batch structure before dispatch.
	assert_bool(false).is_true()


func test_relay_goes_to_unreliable():
	# Stub: RED — SyncSender does not exist yet.
	# queue_relay_data() must queue data into the HIGH (unreliable) bucket
	# so it is relayed to other peers via the unreliable channel.
	# Plan 03: SyncSender.queue_relay_data() routes to unreliable RPC.
	assert_bool(false).is_true()
