extends GdUnitTestSuite

## Test suite for SyncSender (SYNC-01).
## Tests verify the behavioral contract: timer accumulator, priority dispatch,
## RPC routing (unreliable vs reliable), and relay queue.

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

	func _send_sync_unreliable(batch: Dictionary) -> void:
		unreliable_rpc_calls.append(batch)

	func _send_sync_reliable(batch: Dictionary) -> void:
		reliable_rpc_calls.append(batch)


# Mock component with REALTIME exported property
class MockCompRealtime:
	extends Component

	@export_group("REALTIME")
	@export var x: float = 0.0


# Mock component with HIGH exported property
class MockCompHigh:
	extends Component

	@export_group("HIGH")
	@export var speed: float = 0.0


# Mock component with MEDIUM exported property
class MockCompMedium:
	extends Component

	@export_group("MEDIUM")
	@export var health: int = 100


# Mock component with LOW exported property
class MockCompLow:
	extends Component

	@export_group("LOW")
	@export var score: int = 0


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


## Create a networked entity with CN_NetworkIdentity + CN_NetSync + given comp.
## The comp property is mutated to a new value AFTER scan so CN_NetSync detects a change.
func _make_entity_with_sync(peer_id: int, comp: Component, prop: String, value) -> Entity:
	var entity = Entity.new()
	entity.name = "TestEntity"
	world.add_entity(entity)

	var net_id = CN_NetworkIdentity.new(peer_id)
	entity.add_component(net_id)

	var net_sync = CN_NetSync.new()
	entity.add_component(net_sync)
	entity.add_component(comp)

	# Scan BEFORE mutating so cache starts at initial value
	net_sync.scan_entity_components(entity)

	# Mutate to create a detectable change
	comp.set(prop, value)
	return entity


# ============================================================================
# SYNC-01: Timer accumulator / frequency dispatch
# ============================================================================


func test_realtime_fires_every_tick():
	# REALTIME always fires on every tick regardless of accumulated time.
	var comp = MockCompRealtime.new()
	_make_entity_with_sync(0, comp, "x", 1.0)

	var sender = SyncSender.new(mock_ns)
	sender.tick(0.016)

	assert_int(mock_ns.unreliable_rpc_calls.size()).is_greater(0)


func test_high_fires_at_20hz():
	# HIGH fires when _timers[HIGH] >= 1/20 = 0.05 s.
	var comp = MockCompHigh.new()
	_make_entity_with_sync(0, comp, "speed", 5.0)

	var sender = SyncSender.new(mock_ns)

	# Below threshold — should NOT fire (also REALTIME fires but no REALTIME prop)
	sender.tick(0.04)
	var before = mock_ns.unreliable_rpc_calls.size()

	# Mutate again so change is detectable at next poll
	comp.speed = 10.0

	# Cross threshold — should fire
	sender.tick(0.02)  # 0.04 + 0.02 = 0.06 >= 0.05
	assert_int(mock_ns.unreliable_rpc_calls.size()).is_greater(before)


func test_medium_fires_at_10hz():
	# MEDIUM fires when _timers[MEDIUM] >= 1/10 = 0.1 s.
	var comp = MockCompMedium.new()
	_make_entity_with_sync(0, comp, "health", 80)

	var sender = SyncSender.new(mock_ns)

	# Below threshold
	sender.tick(0.08)
	var before = mock_ns.reliable_rpc_calls.size()

	# Mutate to ensure change detected at next poll
	comp.health = 60

	# Cross threshold: 0.08 + 0.04 = 0.12 >= 0.1
	sender.tick(0.04)
	assert_int(mock_ns.reliable_rpc_calls.size()).is_greater(before)


func test_low_fires_at_2hz():
	# LOW fires when _timers[LOW] >= 1/2 = 0.5 s.
	var comp = MockCompLow.new()
	_make_entity_with_sync(0, comp, "score", 100)

	var sender = SyncSender.new(mock_ns)

	# Below threshold
	sender.tick(0.4)
	var before = mock_ns.reliable_rpc_calls.size()

	# Mutate to ensure change detected at next poll
	comp.score = 200

	# Cross threshold: 0.4 + 0.15 = 0.55 >= 0.5
	sender.tick(0.15)
	assert_int(mock_ns.reliable_rpc_calls.size()).is_greater(before)


# ============================================================================
# SYNC-01: Batch format and relay dispatch
# ============================================================================


func test_batch_format():
	# The outbound batch must match wire format:
	# { entity_id: { comp_type: { prop: value } } }
	var comp = MockCompRealtime.new()
	var entity = _make_entity_with_sync(0, comp, "x", 7.0)

	var sender = SyncSender.new(mock_ns)
	sender.tick(0.016)

	assert_int(mock_ns.unreliable_rpc_calls.size()).is_greater(0)
	var batch: Dictionary = mock_ns.unreliable_rpc_calls[0]
	# Batch is keyed by entity_id
	assert_bool(batch.has(entity.id)).is_true()
	var entity_data = batch[entity.id]
	# Inner level is comp_type -> { prop: value }
	assert_bool(entity_data is Dictionary).is_true()
	assert_bool(entity_data.size() > 0).is_true()


func test_relay_goes_to_unreliable():
	# queue_relay_data() queues data into the HIGH (unreliable) bucket.
	# After a tick past the HIGH threshold, it appears in unreliable_rpc_calls.
	var sender = SyncSender.new(mock_ns)
	var relay_data = {"MockCompHigh": {"speed": 99.0}}
	sender.queue_relay_data("test_entity_1", relay_data)

	# Advance past HIGH interval (0.05 s) to trigger dispatch
	sender.tick(0.06)

	assert_int(mock_ns.unreliable_rpc_calls.size()).is_greater(0)
	var found = false
	for batch in mock_ns.unreliable_rpc_calls:
		if batch.has("test_entity_1"):
			found = true
			break
	assert_bool(found).is_true()


func test_no_dispatch_when_applying_network_data():
	# tick() must return immediately when _applying_network_data is true.
	var comp = MockCompRealtime.new()
	_make_entity_with_sync(0, comp, "x", 3.0)

	var sender = SyncSender.new(mock_ns)
	mock_ns._applying_network_data = true
	sender.tick(0.016)

	# No RPC calls should have been made
	assert_int(mock_ns.unreliable_rpc_calls.size()).is_equal(0)
	assert_int(mock_ns.reliable_rpc_calls.size()).is_equal(0)
