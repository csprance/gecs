extends GdUnitTestSuite

## Test suite for custom sync handler hooks (ADV-03).
## Tests verify that SyncSender._custom_send_handlers and
## SyncReceiver._custom_receive_handlers work correctly.

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


func before_test() -> void:
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world
	mock_ns = MockNetworkSync.new(world)
	mock_ns.net_adapter._is_server = true


func after_test() -> void:
	mock_ns = null
	if is_instance_valid(world):
		for entity in world.entities.duplicate():
			world.remove_entity(entity)
			if is_instance_valid(entity):
				entity.free()
		world.free()
	world = null


# ============================================================================
# HELPER: Resolve wire-format type name for a component (matches CN_NetSync logic)
# ============================================================================


func _comp_type_name(comp: Component) -> String:
	var script = comp.get_script()
	if script == null:
		return comp.get_class()
	var name_str: String = script.get_global_name()
	if name_str == "":
		name_str = script.resource_path.get_file().get_basename()
	return name_str


# ============================================================================
# HELPER: Build a complete entity with CN_NetworkIdentity + MockComponent + CN_NetSync
# ============================================================================


func _build_entity(peer_id: int, health_val: int = 100) -> Entity:
	var entity: Entity = Entity.new()
	entity.name = "TestEntity_%d" % peer_id
	world.add_entity(entity)

	var net_id: CN_NetworkIdentity = CN_NetworkIdentity.new()
	net_id.peer_id = peer_id
	entity.add_component(net_id)

	var mock_comp: MockComponent = MockComponent.new()
	mock_comp.health = health_val
	entity.add_component(mock_comp)

	var net_sync: CN_NetSync = CN_NetSync.new()
	entity.add_component(net_sync)
	net_sync.scan_entity_components(entity)

	return entity


# ============================================================================
# TESTS
# ============================================================================


func test_custom_send_handler_replaces_default() -> void:
	# A callable registered via register_send_handler() should be invoked
	# instead of CN_NetSync.check_changes_for_priority() for the named component type.
	# The pending dict should contain the value returned by the custom handler.
	var sender: SyncSender = SyncSender.new(mock_ns)
	var entity: Entity = _build_entity(1)

	# Mutate health so the default path would also detect a change
	var mock_comp: MockComponent = entity.get_component(MockComponent)
	mock_comp.health = 50

	# Get the actual wire-format type name used by CN_NetSync
	var comp_key: String = _comp_type_name(mock_comp)

	# Register a custom send handler for MockComponent that returns a fixed value
	sender.register_send_handler(comp_key, func(e: Entity, c: Component, priority: int) -> Dictionary:
		return {"health": 42}
	)

	# Poll — the custom handler should fire and put {"health": 42} into pending
	sender._poll_entities_for_priority(CN_NetSync.Priority.HIGH)

	# Verify entity has an entry in _pending for HIGH priority
	assert_bool(sender._pending[CN_NetSync.Priority.HIGH].has(entity.id)).is_true()
	# Verify the value was set by our custom handler (42, not 50)
	assert_int(sender._pending[CN_NetSync.Priority.HIGH][entity.id][comp_key]["health"]).is_equal(42)


func test_custom_send_handler_suppress() -> void:
	# Returning {} from a registered send handler suppresses that component
	# from the outbound batch entirely.
	var sender: SyncSender = SyncSender.new(mock_ns)
	var entity: Entity = _build_entity(1)

	# Mutate health so the default dirty check would detect a change
	var mock_comp: MockComponent = entity.get_component(MockComponent)
	mock_comp.health = 999

	var comp_key: String = _comp_type_name(mock_comp)

	# Register a send handler that returns {} to suppress
	sender.register_send_handler(comp_key, func(_e: Entity, _c: Component, _priority: int) -> Dictionary:
		return {}
	)

	sender._poll_entities_for_priority(CN_NetSync.Priority.HIGH)

	# pending should have no entry for this entity
	assert_bool(sender._pending[CN_NetSync.Priority.HIGH].has(entity.id)).is_false()


func test_custom_receive_handler_replaces_default() -> void:
	# A callable registered via register_receive_handler() is called instead
	# of comp.set() for the named component type when it returns true.
	var receiver: SyncReceiver = SyncReceiver.new(mock_ns)
	var entity: Entity = _build_entity(2, 5)

	var mock_comp: MockComponent = entity.get_component(MockComponent)
	var comp_key: String = _comp_type_name(mock_comp)

	# Use an Array for handler_called so lambda captures the reference, not a copy
	var handler_tracker: Array = [false]
	receiver.register_receive_handler(comp_key, func(_e: Entity, _c: Component, _props: Dictionary) -> bool:
		handler_tracker[0] = true
		return true  # Handled — skip default comp.set()
	)

	# Apply data using the actual wire-format type name
	receiver._apply_component_data(entity, {comp_key: {"health": 99}})

	# Handler was called
	assert_bool(handler_tracker[0]).is_true()
	# comp.set() was NOT called (handler returned true), so health stays 5
	assert_int(mock_comp.health).is_equal(5)


func test_custom_receive_handler_still_updates_cache() -> void:
	# After a custom receive handler returns true, the framework still calls
	# update_cache_silent() so the received value is stored in the dirty cache.
	# This prevents the receiver from immediately re-detecting the network value
	# as a new change to broadcast (echo-loop prevention).
	#
	# In this test the handler DOES apply the value to the component (simulating
	# a custom blend), so cache and component value are both 99 after the call —
	# check_changes_for_priority returns empty because nothing has changed since
	# the last cached snapshot.
	var receiver: SyncReceiver = SyncReceiver.new(mock_ns)
	var entity: Entity = _build_entity(2, 5)

	var net_sync: CN_NetSync = entity.get_component(CN_NetSync)
	var mock_comp: MockComponent = entity.get_component(MockComponent)
	var comp_key: String = _comp_type_name(mock_comp)

	# Register a receive handler that applies the value AND returns true.
	# The framework must still call update_cache_silent() even though handler returned true.
	receiver.register_receive_handler(comp_key, func(_e: Entity, c: Component, props: Dictionary) -> bool:
		# Custom apply — simulates a blend or custom logic that DOES set the property
		if props.has("health"):
			c.health = props["health"]
		return true  # Handled — framework must still call update_cache_silent()
	)

	# Apply data — both the handler sets health=99 AND update_cache_silent sets cache=99
	receiver._apply_component_data(entity, {comp_key: {"health": 99}})

	# comp.health was set by our custom handler
	assert_int(mock_comp.health).is_equal(99)

	# check_changes_for_priority should return empty because cache (99) == comp (99)
	# If update_cache_silent was NOT called, the cache would still be 5 and the
	# framework would immediately detect 5 vs 99 as a "change" to re-broadcast.
	var changes: Dictionary = net_sync.check_changes_for_priority(CN_NetSync.Priority.HIGH)
	assert_bool(changes.is_empty()).is_true()


func test_custom_receive_handler_fallthrough() -> void:
	# Returning false from a registered receive handler causes the default
	# comp.set() path to execute as if no custom handler were present.
	var receiver: SyncReceiver = SyncReceiver.new(mock_ns)
	var entity: Entity = _build_entity(2, 5)

	var mock_comp: MockComponent = entity.get_component(MockComponent)
	var comp_key: String = _comp_type_name(mock_comp)

	# Register a receive handler that returns false (fallthrough)
	receiver.register_receive_handler(comp_key, func(_e: Entity, _c: Component, _props: Dictionary) -> bool:
		return false
	)

	receiver._apply_component_data(entity, {comp_key: {"health": 99}})

	# Default comp.set() ran because handler returned false
	assert_int(mock_comp.health).is_equal(99)
