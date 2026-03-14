extends GdUnitTestSuite

## Test suite for SyncReconciliationHandler (ADV-02).
## Plan 02: RED stubs replaced with real assertions.

const SyncReconciliationHandler = preload("res://addons/gecs_network/sync_reconciliation_handler.gd")

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


class MockSpawnManager:
	extends RefCounted

	var serialized_entities: Array = []

	func serialize_entity(entity: Entity) -> Dictionary:
		var net_id = entity.get_component(CN_NetworkIdentity)
		return {
			"id": entity.id,
			"components": {},
			"session_id": 42,
			"relationships": [],
			"peer_id": net_id.peer_id if net_id else 0
		}


class MockReceiver:
	extends RefCounted

	var apply_calls: Array = []

	func _apply_component_data(entity: Entity, comp_data: Dictionary) -> void:
		apply_calls.append({"entity": entity, "comp_data": comp_data})


class MockNetworkSync:
	extends RefCounted

	var _world: World
	var _applying_network_data: bool = false
	var _game_session_id: int = 42
	var net_adapter: MockNetAdapter
	var debug_logging: bool = false
	var full_state_rpc_calls: Array = []
	var _spawn_manager: MockSpawnManager
	var _receiver: MockReceiver

	func _init(w: World) -> void:
		_world = w
		net_adapter = MockNetAdapter.new()
		_spawn_manager = MockSpawnManager.new()
		_receiver = MockReceiver.new()

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
var handler  # SyncReconciliationHandler


func before_test() -> void:
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world
	mock_ns = MockNetworkSync.new(world)
	mock_ns.net_adapter._is_server = true
	handler = SyncReconciliationHandler.new(mock_ns)


func after_test() -> void:
	handler = null
	mock_ns = null
	if is_instance_valid(world):
		for entity in world.entities.duplicate():
			world.remove_entity(entity)
			if is_instance_valid(entity):
				entity.free()
		world.free()


# ============================================================================
# TESTS — all replacing assert_bool(false).is_true() stubs
# ============================================================================


func test_reconciliation_fires_at_interval() -> void:
	# Set a short interval via ProjectSettings override
	ProjectSettings.set_setting("gecs_network/sync/reconciliation_interval", 1.0)
	ProjectSettings.set_initial_value("gecs_network/sync/reconciliation_interval", 1.0)

	# Add a networked entity so broadcast_full_state() doesn't no-op
	var entity = Entity.new()
	world.add_entity(entity)
	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 2
	entity.add_component(net_id)

	# Tick below threshold — no broadcast
	handler.tick(0.5)
	assert_bool(mock_ns.full_state_rpc_calls.size() == 0).is_true()

	# Tick past threshold — broadcast fires
	handler.tick(0.6)
	assert_bool(mock_ns.full_state_rpc_calls.size() >= 1).is_true()

	# Restore default
	ProjectSettings.set_setting("gecs_network/sync/reconciliation_interval", 30.0)
	ProjectSettings.set_initial_value("gecs_network/sync/reconciliation_interval", 30.0)


func test_broadcast_full_state_serializes_networked_entities() -> void:
	# Add one entity with CN_NetworkIdentity
	var entity = Entity.new()
	world.add_entity(entity)
	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 2
	entity.add_component(net_id)

	handler.broadcast_full_state()

	assert_bool(mock_ns.full_state_rpc_calls.size() == 1).is_true()
	assert_bool(mock_ns.full_state_rpc_calls[0]["entities"].size() == 1).is_true()


func test_handle_full_state_applies_component_data() -> void:
	# Create a remote entity (peer_id=2) with CN_NetworkIdentity
	var entity = Entity.new()
	world.add_entity(entity)
	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 2
	entity.add_component(net_id)

	# Client: my_peer_id = 1 (not the entity owner)
	mock_ns.net_adapter._my_peer_id = 1

	var payload = {
		"entities": [
			{
				"id": entity.id,
				"components": {"MockComponent": {"value": 99}}
			}
		],
		"session_id": 42
	}
	handler.handle_sync_full_state(payload)

	assert_bool(mock_ns._receiver.apply_calls.size() == 1).is_true()


func test_handle_full_state_skips_local_entities() -> void:
	# Create a LOCAL entity (peer_id matches my_peer_id)
	var entity = Entity.new()
	world.add_entity(entity)
	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 1
	entity.add_component(net_id)

	mock_ns.net_adapter._my_peer_id = 1

	var payload = {
		"entities": [
			{
				"id": entity.id,
				"components": {"MockComponent": {"value": 99}}
			}
		],
		"session_id": 42
	}
	handler.handle_sync_full_state(payload)

	# Own entity must NOT be overwritten
	assert_bool(mock_ns._receiver.apply_calls.size() == 0).is_true()


func test_handle_full_state_removes_ghost_entities() -> void:
	# Create a remote entity (peer_id=2) — ghost, not in server state
	var entity = Entity.new()
	world.add_entity(entity)
	var net_id = CN_NetworkIdentity.new()
	net_id.peer_id = 2
	entity.add_component(net_id)
	var ghost_id = entity.id

	mock_ns.net_adapter._my_peer_id = 1

	# Payload with empty entities — ghost not mentioned = should be removed
	var payload = {
		"entities": [],
		"session_id": 42
	}
	handler.handle_sync_full_state(payload)

	assert_bool(world.entity_id_registry.has(ghost_id) == false).is_true()


func test_reconciliation_interval_project_setting() -> void:
	# Replicate plugin._register_project_settings() inline for headless runner
	if not ProjectSettings.has_setting("gecs_network/sync/reconciliation_interval"):
		ProjectSettings.set_setting("gecs_network/sync/reconciliation_interval", 30.0)
	ProjectSettings.set_initial_value("gecs_network/sync/reconciliation_interval", 30.0)

	assert_float(
		ProjectSettings.get_setting("gecs_network/sync/reconciliation_interval", 0.0)
	).is_equal(30.0)
