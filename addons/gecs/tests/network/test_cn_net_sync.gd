extends GdUnitTestSuite
## Test suite for CN_NetSync (SYNC-02 and SYNC-03).

# ============================================================================
# MOCK COMPONENTS
# ============================================================================


class MockCompHigh:
	extends Component

	@export_group("HIGH")
	@export var speed: float = 1.0
	@export var direction: Vector3 = Vector3.ZERO


class MockCompMedium:
	extends Component

	@export_group("MEDIUM")
	@export var health: int = 100


class MockCompMixed:
	extends Component

	@export_group("HIGH")
	@export var position: Vector3 = Vector3.ZERO

	@export_group("MEDIUM")
	@export var stamina: float = 100.0

	@export_group("SPAWN_ONLY")
	@export var scene_path: String = ""

	@export_group("LOCAL")
	@export var client_only: bool = false


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
# HELPER
# ============================================================================


func _make_entity_with(comps: Array) -> Entity:
	var entity = Entity.new()
	entity.name = "TestEntity"
	world.add_child(entity)
	for comp in comps:
		entity.add_component(comp)
	return entity


# ============================================================================
# SYNC-02 / SYNC-03: scan_entity_components scanner tests
# ============================================================================


func test_scanner_maps_export_group_to_priority():
	var net_sync := CN_NetSync.new()
	var comp := MockCompMixed.new()
	var entity := _make_entity_with([net_sync, comp])

	net_sync.scan_entity_components(entity)

	# position must be in the HIGH (1) bucket, not MEDIUM (2)
	var inst_id := comp.get_instance_id()
	var props_by_prio: Dictionary = net_sync._props_by_comp[inst_id]
	assert_bool(props_by_prio.has(CN_NetSync.Priority.HIGH)).is_true()
	assert_bool("position" in props_by_prio[CN_NetSync.Priority.HIGH]).is_true()
	# stamina must be in the MEDIUM (2) bucket
	assert_bool(props_by_prio.has(CN_NetSync.Priority.MEDIUM)).is_true()
	assert_bool("stamina" in props_by_prio[CN_NetSync.Priority.MEDIUM]).is_true()


func test_scanner_skips_spawn_only_props():
	var net_sync := CN_NetSync.new()
	var comp := MockCompMixed.new()
	var entity := _make_entity_with([net_sync, comp])

	net_sync.scan_entity_components(entity)

	var inst_id := comp.get_instance_id()
	var props_by_prio: Dictionary = net_sync._props_by_comp[inst_id]

	# SPAWN_ONLY sentinel is -2; it must not appear in any priority bucket
	for priority in props_by_prio.keys():
		var prop_list: Array = props_by_prio[priority]
		assert_bool("scene_path" in prop_list).is_false()


func test_scanner_skips_local_props():
	var net_sync := CN_NetSync.new()
	var comp := MockCompMixed.new()
	var entity := _make_entity_with([net_sync, comp])

	net_sync.scan_entity_components(entity)

	var inst_id := comp.get_instance_id()
	var props_by_prio: Dictionary = net_sync._props_by_comp[inst_id]

	# LOCAL sentinel is -1; it must not appear in any priority bucket
	for priority in props_by_prio.keys():
		var prop_list: Array = props_by_prio[priority]
		assert_bool("client_only" in prop_list).is_false()


func test_scanner_skips_cn_net_sync_itself():
	var net_sync := CN_NetSync.new()
	var comp := MockCompHigh.new()
	var entity := _make_entity_with([net_sync, comp])

	net_sync.scan_entity_components(entity)

	# CN_NetSync's own instance ID must NOT appear in _comp_refs
	var net_sync_inst_id := net_sync.get_instance_id()
	assert_bool(net_sync_inst_id in net_sync._comp_refs).is_false()


func test_scanner_skips_cn_network_identity():
	var net_sync := CN_NetSync.new()
	var net_id := CN_NetworkIdentity.new()
	var comp := MockCompHigh.new()
	var entity := _make_entity_with([net_sync, net_id, comp])

	net_sync.scan_entity_components(entity)

	# CN_NetworkIdentity's instance ID must NOT appear in _comp_refs
	var net_id_inst_id := net_id.get_instance_id()
	assert_bool(net_id_inst_id in net_sync._comp_refs).is_false()


# ============================================================================
# SYNC-02: check_changes_for_priority dirty tracking
# ============================================================================


func test_check_changes_returns_changed_props():
	var net_sync := CN_NetSync.new()
	var comp := MockCompHigh.new()
	comp.speed = 1.0
	var entity := _make_entity_with([net_sync, comp])
	net_sync.scan_entity_components(entity)

	# Mutate a HIGH property
	comp.speed = 5.0
	var result: Dictionary = net_sync.check_changes_for_priority(CN_NetSync.Priority.HIGH)

	# Result should contain the component type name with changed prop
	assert_bool(result.is_empty()).is_false()
	var type_key: String = net_sync._comp_type_names[comp.get_instance_id()]
	assert_bool(result.has(type_key)).is_true()
	assert_float(result[type_key]["speed"]).is_equal(5.0)


func test_check_changes_excludes_unchanged_props():
	var net_sync := CN_NetSync.new()
	var comp := MockCompHigh.new()
	comp.speed = 1.0
	var entity := _make_entity_with([net_sync, comp])
	net_sync.scan_entity_components(entity)

	# First poll — no mutations since scan
	var first: Dictionary = net_sync.check_changes_for_priority(CN_NetSync.Priority.HIGH)
	assert_bool(first.is_empty()).is_true()

	# Mutate then poll — should get a change
	comp.speed = 3.0
	var second: Dictionary = net_sync.check_changes_for_priority(CN_NetSync.Priority.HIGH)
	assert_bool(second.is_empty()).is_false()

	# Third poll with no new mutations — should be empty again (cache updated)
	var third: Dictionary = net_sync.check_changes_for_priority(CN_NetSync.Priority.HIGH)
	assert_bool(third.is_empty()).is_true()


func test_has_changed_float_approx():
	var net_sync := CN_NetSync.new()

	# Values within float epsilon must NOT be flagged as changed
	var tiny_diff := 1e-8
	assert_bool(net_sync._has_changed(1.0, 1.0 + tiny_diff)).is_false()

	# Values beyond epsilon MUST be flagged as changed
	assert_bool(net_sync._has_changed(1.0, 1.1)).is_true()

	# Identical values must not be changed
	assert_bool(net_sync._has_changed(0.0, 0.0)).is_false()


# ============================================================================
# SYNC-03: update_cache_silent suppresses re-sync
# ============================================================================


func test_scan_skips_cn_native_sync():
	## CN_NativeSync properties must not appear in batched RPC sync (SYNC-04)
	var net_sync := CN_NetSync.new()
	var native_sync := CN_NativeSync.new()
	var entity := _make_entity_with([net_sync, native_sync])

	net_sync.scan_entity_components(entity)

	# CN_NativeSync instance must NOT appear in _comp_refs
	var native_sync_inst_id := native_sync.get_instance_id()
	assert_bool(native_sync_inst_id in net_sync._comp_refs).is_false()


func test_update_cache_silent_suppresses_resync():
	var net_sync := CN_NetSync.new()
	var comp := MockCompMedium.new()
	comp.health = 100
	var entity := _make_entity_with([net_sync, comp])
	net_sync.scan_entity_components(entity)

	# Mutate the property to 50 (simulating received network data)
	comp.health = 50

	# update_cache_silent should bring cache in sync WITHOUT triggering detection
	net_sync.update_cache_silent(comp, "health", 50)

	# Poll should now show NO changes — the silent update prevents echo loop
	var result: Dictionary = net_sync.check_changes_for_priority(CN_NetSync.Priority.MEDIUM)
	assert_bool(result.is_empty()).is_true()
