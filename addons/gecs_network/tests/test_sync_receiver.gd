extends GdUnitTestSuite

## Test suite for SyncReceiver (SYNC-01, SYNC-02, SYNC-03).
## Tests verify: authority validation, CN_NetworkIdentity strip,
## _applying_network_data guard, relay dispatch, and spawn-only rejection.

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


class MockSender:
	extends RefCounted

	var relay_calls: Array = []

	func queue_relay_data(entity_id: String, comp_data: Dictionary) -> void:
		relay_calls.append({"entity_id": entity_id, "comp_data": comp_data})


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
	var _sender: MockSender  # For relay tests

	func _init(w: World) -> void:
		_world = w
		net_adapter = MockNetAdapter.new()
		_sender = MockSender.new()

	func _sync_components_unreliable(batch: Dictionary) -> void:
		unreliable_rpc_calls.append(batch)

	func _sync_components_reliable(batch: Dictionary) -> void:
		reliable_rpc_calls.append(batch)


# Mock component to track property changes
class MockComp:
	extends Component

	@export_group("HIGH")
	@export var value: int = 0


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
# HELPERS
# ============================================================================


## Resolve the wire-format type name for a component, matching _find_component_by_type().
func _comp_type_name(comp: Component) -> String:
	var script = comp.get_script()
	if script == null:
		return comp.get_class()
	var name_str: String = script.get_global_name()
	if name_str == "":
		name_str = script.resource_path.get_file().get_basename()
	return name_str


## Create a fully networked entity (has CN_NetworkIdentity + CN_NetSync + MockComp).
func _make_networked_entity(peer_id: int) -> Entity:
	var entity = Entity.new()
	entity.name = "TestEntity"
	world.add_entity(entity)
	entity.add_component(CN_NetworkIdentity.new(peer_id))
	var net_sync = CN_NetSync.new()
	entity.add_component(net_sync)
	var comp = MockComp.new()
	entity.add_component(comp)
	net_sync.scan_entity_components(entity)
	return entity


## Create a spawn-only entity (has CN_NetworkIdentity but NO CN_NetSync).
func _make_spawn_only_entity(peer_id: int) -> Entity:
	var entity = Entity.new()
	entity.name = "SpawnOnly"
	world.add_entity(entity)
	entity.add_component(CN_NetworkIdentity.new(peer_id))
	# Deliberately NO CN_NetSync
	return entity


# ============================================================================
# SYNC-01 / SYNC-02: Server authority checks
# ============================================================================


func test_server_rejects_non_owner():
	# Server receives batch for entity where net_id.peer_id (2) != sender_id (3).
	# Entity properties must remain unchanged.
	mock_ns.net_adapter._is_server = true
	mock_ns.net_adapter._remote_sender_id = 3

	var entity = _make_networked_entity(2)  # peer_id=2, sender=3 → mismatch
	var comp = entity.get_component(MockComp)
	comp.value = 99  # Set initial value

	var comp_key = _comp_type_name(comp)
	var batch = {entity.id: {comp_key: {"value": 999}}}
	var receiver = SyncReceiver.new(mock_ns)
	receiver.handle_apply_sync_data(batch)

	# Value must remain 99 (not 999)
	assert_int(comp.value).is_equal(99)


func test_server_strips_cn_network_identity():
	# Server receives batch containing "CN_NetworkIdentity" key.
	# That key must be stripped; other comp data must still be applied.
	mock_ns.net_adapter._is_server = true
	mock_ns.net_adapter._remote_sender_id = 2

	var entity = _make_networked_entity(2)  # peer_id matches sender_id
	var comp = entity.get_component(MockComp)
	comp.value = 0

	# Use actual resolved type name so _find_component_by_type() can match it
	var comp_key = _comp_type_name(comp)
	var batch = {
		entity.id: {
			"CN_NetworkIdentity": {"peer_id": 999},  # Spoof attempt — must be stripped
			comp_key: {"value": 42}
		}
	}
	var receiver = SyncReceiver.new(mock_ns)
	receiver.handle_apply_sync_data(batch)

	# CN_NetworkIdentity spoof must not apply (peer_id unchanged = 2)
	var net_id = entity.get_component(CN_NetworkIdentity)
	assert_int(net_id.peer_id).is_equal(2)
	# MockComp update must still apply
	assert_int(comp.value).is_equal(42)


func test_server_relays_to_clients():
	# Valid client update received on server must queue relay in _sender.
	mock_ns.net_adapter._is_server = true
	mock_ns.net_adapter._remote_sender_id = 2

	var entity = _make_networked_entity(2)

	var comp = entity.get_component(MockComp)
	var comp_key = _comp_type_name(comp)
	var batch = {entity.id: {comp_key: {"value": 77}}}
	var receiver = SyncReceiver.new(mock_ns)
	receiver.handle_apply_sync_data(batch)

	# Relay must have been queued
	assert_int(mock_ns._sender.relay_calls.size()).is_greater(0)
	var relay = mock_ns._sender.relay_calls[0]
	assert_str(relay["entity_id"]).is_equal(entity.id)


# ============================================================================
# SYNC-01: Client-side rejection rules
# ============================================================================


func test_client_rejects_non_server():
	# Client receives batch from peer_id=2 (not server).
	# The entire batch must be rejected.
	mock_ns.net_adapter._is_server = false
	mock_ns.net_adapter._my_peer_id = 3
	mock_ns.net_adapter._remote_sender_id = 2  # Not the server (server=1)

	var entity = _make_networked_entity(0)  # server-owned entity
	var comp = entity.get_component(MockComp)
	comp.value = 55

	var comp_key = _comp_type_name(comp)
	var batch = {entity.id: {comp_key: {"value": 999}}}
	var receiver = SyncReceiver.new(mock_ns)
	receiver.handle_apply_sync_data(batch)

	# Must be rejected — value stays 55
	assert_int(comp.value).is_equal(55)


func test_client_skips_own_entity():
	# Client receives batch for a locally-owned entity.
	# The entity update must be skipped.
	mock_ns.net_adapter._is_server = false
	mock_ns.net_adapter._my_peer_id = 2
	mock_ns.net_adapter._remote_sender_id = 1  # From server — accepted

	var entity = _make_networked_entity(2)  # peer_id == my_peer_id → own entity
	var comp = entity.get_component(MockComp)
	comp.value = 33

	var comp_key = _comp_type_name(comp)
	var batch = {entity.id: {comp_key: {"value": 999}}}
	var receiver = SyncReceiver.new(mock_ns)
	receiver.handle_apply_sync_data(batch)

	# Must be skipped — value stays 33
	assert_int(comp.value).is_equal(33)


# ============================================================================
# SYNC-03: _applying_network_data guard and SPAWN_ONLY rejection
# ============================================================================


func test_applying_flag_set_during_apply():
	# _applying_network_data must be false before and after handle_apply_sync_data().
	# Inside the call it is true, but we can only verify the post-condition
	# (false after return) from outside. The post-condition is the key guarantee.
	mock_ns.net_adapter._is_server = true
	mock_ns.net_adapter._remote_sender_id = 2

	var entity = _make_networked_entity(2)
	var comp = entity.get_component(MockComp)
	comp.value = 0

	# Ensure flag starts false
	assert_bool(mock_ns._applying_network_data).is_false()

	var comp_key = _comp_type_name(comp)
	var batch = {entity.id: {comp_key: {"value": 10}}}
	var receiver = SyncReceiver.new(mock_ns)
	receiver.handle_apply_sync_data(batch)

	# Must be false after returning
	assert_bool(mock_ns._applying_network_data).is_false()
	# Data must have been applied (confirms the path ran with guard)
	assert_int(comp.value).is_equal(10)


func test_spawn_only_entity_rejected():
	# Entity without CN_NetSync (spawn-only) must be rejected for continuous updates.
	mock_ns.net_adapter._is_server = true
	mock_ns.net_adapter._remote_sender_id = 0

	# spawn-only entity has NO CN_NetSync
	var entity = _make_spawn_only_entity(0)

	# Add a bare component directly (no CN_NetSync scan — just test rejection)
	var comp = MockComp.new()
	comp.value = 50
	entity.add_component(comp)

	var comp_key = _comp_type_name(comp)
	var batch = {entity.id: {comp_key: {"value": 999}}}
	var receiver = SyncReceiver.new(mock_ns)
	receiver.handle_apply_sync_data(batch)

	# Must be rejected — value stays 50
	assert_int(comp.value).is_equal(50)
