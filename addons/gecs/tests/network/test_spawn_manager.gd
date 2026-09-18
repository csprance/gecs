extends GdUnitTestSuite
## Test suite for SpawnManager (Wave 1 — GREEN phase)
## Tests verify the behavioral contract for LIFE-01, LIFE-02, LIFE-03, LIFE-04.
##
## MockNetworkSync has NO sync_config field (removed in v2).

const SyncRelationshipHandler = preload("res://addons/gecs/network/sync_relationship_handler.gd")


# Mock component with a HIGH-priority exported property (for scan tests)
class MockSyncComp:
	extends Component

	@export_group("HIGH")
	@export var value: int = 0


# ============================================================================
# MOCK OBJECTS
# ============================================================================


class MockNetAdapter:
	extends NetAdapter

	var _is_server: bool = true
	var _my_peer_id: int = 1

	func is_server() -> bool:
		return _is_server

	func get_my_peer_id() -> int:
		return _my_peer_id

	func get_remote_sender_id() -> int:
		return 0

	func _has_multiplayer() -> bool:
		return true


class MockNetworkSync:
	extends RefCounted

	# Mirrors NetworkSync's public spawn signals (emitted by SpawnManager)
	signal entity_spawned(entity: Entity)
	signal local_player_spawned(entity: Entity)

	# NOTE: NO sync_config field — removed in v2
	var _world: World
	var _applying_network_data: bool = false
	var _game_session_id: int = 42
	var _spawn_counter: int = 0
	var _broadcast_pending: Dictionary = {}
	var net_adapter: MockNetAdapter
	var debug_logging: bool = false

	# RPC call tracking — tests assert what was "sent"
	var spawn_rpc_calls: Array = []
	var despawn_rpc_calls: Array = []

	# Landing spot for SpawnManager's call_deferred("_deferred_broadcast", ...);
	# without it the message-queue flush errors with "Method not found" at end
	# of frame. Records only; leaves _broadcast_pending untouched so tests can
	# still assert the pre-flush queued state.
	var deferred_broadcast_calls: Array = []

	# Relationship handler reference (null by default; set in tests that need it)
	var _relationship_handler = null

	func _init(w: World) -> void:
		_world = w
		net_adapter = MockNetAdapter.new()

	func _deferred_broadcast(_entity, entity_id) -> void:
		deferred_broadcast_calls.append(entity_id)

	# Called by SpawnManager to broadcast a spawn to all peers
	func rpc_broadcast_spawn(data: Dictionary) -> void:
		spawn_rpc_calls.append(data)

	# Called by SpawnManager to broadcast a despawn to all peers
	func rpc_broadcast_despawn(entity_id: int, session_id: int) -> void:
		despawn_rpc_calls.append({"entity_id": entity_id, "session_id": session_id})


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

var world: World
var mock_ns: MockNetworkSync
var manager: SpawnManager  # Will fail to resolve until Wave 1 creates SpawnManager


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
	manager = null


# ============================================================================
# LIFE-01: Deferred broadcast on entity added
# ============================================================================


func test_deferred_broadcast_on_entity_added():
	# When the server calls on_entity_added for an entity with CN_NetworkIdentity,
	# the entity's ID must appear in _broadcast_pending (queued for deferred send).
	manager = SpawnManager.new(mock_ns)

	var entity = Entity.new()
	entity.id = 101
	entity.name = "NetworkedEntity"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	manager.on_entity_added(entity)

	assert_bool(mock_ns._broadcast_pending.has(entity.id)).is_true()


# ============================================================================
# LIFE-02: Broadcast pending cancellation
# ============================================================================


func test_broadcast_pending_cancellation():
	# When on_entity_removed is called for an entity that is in _broadcast_pending,
	# the entry must be erased and NO despawn RPC must fire.
	manager = SpawnManager.new(mock_ns)

	var entity = Entity.new()
	entity.id = 102
	entity.name = "CancelledEntity"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	# Simulate entity being queued for deferred broadcast
	mock_ns._broadcast_pending[entity.id] = entity

	manager.on_entity_removed(entity)

	assert_bool(mock_ns._broadcast_pending.has(entity.id)).is_false()
	assert_int(mock_ns.despawn_rpc_calls.size()).is_equal(0)


# ============================================================================
# LIFE-03: World state serialization
# ============================================================================


func test_serialize_world_state():
	# serialize_world_state() must return a Dictionary with:
	# - "entities": Array of entity Dictionaries
	# - "session_id": int matching _game_session_id
	# Only entities with CN_NetworkIdentity are included.
	manager = SpawnManager.new(mock_ns)

	var networked = Entity.new()
	networked.id = 201
	networked.name = "NetworkedEntity"
	networked.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(networked)

	var local_entity = Entity.new()
	local_entity.id = 202
	local_entity.name = "LocalEntity"
	world.add_entity(local_entity)

	var state = manager.serialize_world_state()

	assert_bool(state.has("entities")).is_true()
	assert_bool(state.has("session_id")).is_true()
	assert_int(state["session_id"]).is_equal(42)
	assert_int(state["entities"].size()).is_equal(1)


# ============================================================================
# FOUND-01: Stale session ID rejection
# ============================================================================


func test_rejects_stale_session_id():
	# handle_spawn_entity with session_id != _game_session_id must NOT add entity to world.
	manager = SpawnManager.new(mock_ns)

	var stale_data = {
		"id": 301,
		"name": "StaleEntity",
		"session_id": 999,  # Wrong session ID
		"components": {},
		"script_paths": {},
	}

	var entity_count_before = world.entities.size()
	manager.handle_spawn_entity(stale_data)

	assert_int(world.entities.size()).is_equal(entity_count_before)


# ============================================================================
# LIFE-04: Peer disconnect cleanup
# ============================================================================


func test_peer_disconnect_cleanup():
	# on_peer_disconnected(peer_id=2) must remove ALL entities owned by peer 2.
	manager = SpawnManager.new(mock_ns)

	var peer2_entity_a = Entity.new()
	peer2_entity_a.id = 401
	peer2_entity_a.name = "Peer2EntityA"
	peer2_entity_a.add_component(CN_NetworkIdentity.new(2))
	world.add_entity(peer2_entity_a)

	var peer2_entity_b = Entity.new()
	peer2_entity_b.id = 402
	peer2_entity_b.name = "Peer2EntityB"
	peer2_entity_b.add_component(CN_NetworkIdentity.new(2))
	world.add_entity(peer2_entity_b)

	var peer3_entity = Entity.new()
	peer3_entity.id = 403
	peer3_entity.name = "Peer3Entity"
	peer3_entity.add_component(CN_NetworkIdentity.new(3))
	world.add_entity(peer3_entity)

	manager.on_peer_disconnected(2)

	assert_bool(world.entity_id_registry.has(401)).is_false()
	assert_bool(world.entity_id_registry.has(402)).is_false()
	assert_bool(world.entity_id_registry.has(403)).is_true()


# ============================================================================
# LIFE-01 + LIFE-02: Deferred broadcast not sent if entity removed same frame
# ============================================================================


func test_deferred_broadcast_not_sent_if_entity_removed_same_frame():
	# Entity added then removed before deferred broadcast fires.
	# No spawn broadcast should be sent.
	manager = SpawnManager.new(mock_ns)

	var entity = Entity.new()
	entity.id = 501
	entity.name = "TransientEntity"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	# Add entity — queues deferred broadcast
	manager.on_entity_added(entity)

	# Remove entity before broadcast fires — must cancel the pending broadcast
	manager.on_entity_removed(entity)

	# No spawn RPC should have been sent
	assert_int(mock_ns.spawn_rpc_calls.size()).is_equal(0)


# ============================================================================
# SYNC: CN_NetSync scan on spawn
# ============================================================================


func test_apply_component_data_scans_cn_net_sync():
	## After handle_spawn_entity(), CN_NetSync._comp_refs must be populated
	## so SyncSender can detect property changes. This was the root cause of
	## clients being unable to send C_PlayerInput to the server — without this
	## scan, check_changes_for_priority() always returns {} and nothing syncs.
	manager = SpawnManager.new(mock_ns)

	# Create entity with CN_NetSync + a syncable component
	var entity = Entity.new()
	entity.id = 601
	entity.name = "ScanEntity"
	world.add_entity(entity)

	var net_id = CN_NetworkIdentity.new(2)
	entity.add_component(net_id)
	var net_sync = CN_NetSync.new()
	entity.add_component(net_sync)
	var sync_comp = MockSyncComp.new()
	entity.add_component(sync_comp)

	# Before: _comp_refs is empty (scan never called)
	assert_int(net_sync._comp_refs.size()).is_equal(0)

	# Trigger the update path in handle_spawn_entity (entity already in registry)
	(
		manager
		.handle_spawn_entity(
			{
				"id": 601,
				"name": "ScanEntity",
				"scene_path": "",
				"components": {},
				"script_paths": {},
				"session_id": 42,
				"relationships": [],
			},
		)
	)

	# After: scan_entity_components() was called — MockSyncComp is not excluded
	# (not CN_NetSync, not CN_NetworkIdentity, not CN_NativeSync), so it appears
	# in _comp_refs and SyncSender can detect its property changes.
	assert_int(net_sync._comp_refs.size()).is_equal(1)


# ============================================================================
# ADV-01: Late-join relationship coverage (RED stubs — Plan 04-01)
# ============================================================================


func test_serialize_entity_includes_relationships_key():
	# serialize_entity() must include a "relationships" key for late-join snapshots.
	# FAILS RED: serialize_entity() does not yet return a "relationships" key.
	manager = SpawnManager.new(mock_ns)

	var entity = Entity.new()
	entity.id = 701
	entity.name = "RelEntity"
	entity.add_component(CN_NetworkIdentity.new(0))
	world.add_entity(entity)

	var data = manager.serialize_entity(entity)

	assert_bool(data.has("relationships")).is_true()


func test_handle_spawn_entity_applies_relationships():
	# handle_spawn_entity() must call apply_entity_relationships() when spawn data
	# includes a "relationships" key. With an empty array the entity still spawns.
	# FAILS RED: handle_spawn_entity() does not yet call apply_entity_relationships().
	mock_ns._relationship_handler = SyncRelationshipHandler.new(mock_ns)
	manager = SpawnManager.new(mock_ns)

	var spawn_data = {
		"id": 801,
		"name": "RelEntity",
		"scene_path": "",
		"components": {},
		"script_paths": {},
		"session_id": 42,
		"relationships": [],
	}

	manager.handle_spawn_entity(spawn_data)

	# Entity must have been added to the world
	assert_bool(mock_ns._world.entity_id_registry.has(801)).is_true()


# ============================================================================
# SPAWN SIGNALS: entity_spawned / local_player_spawned
# ============================================================================


## Build a spawn payload for a fresh entity owned by [param peer_id].
func _make_spawn_payload(entity_id: int, peer_id: int) -> Dictionary:
	var source = Entity.new()
	source.name = "SignalEntity%d" % entity_id
	source.add_component(CN_NetworkIdentity.new(peer_id))
	var data = manager.serialize_entity(source)
	source.free()
	data["id"] = entity_id
	return data


func test_handle_spawn_entity_emits_entity_spawned():
	# A fresh spawn must emit entity_spawned exactly once, with the component
	# data already applied. A remote peer's entity must NOT emit local_player_spawned.
	manager = SpawnManager.new(mock_ns)
	mock_ns.net_adapter._is_server = false
	mock_ns.net_adapter._my_peer_id = 2

	var spawned: Array = []
	var local_spawned: Array = []
	mock_ns.entity_spawned.connect(func(e): spawned.append(e))
	mock_ns.local_player_spawned.connect(func(e): local_spawned.append(e))

	manager.handle_spawn_entity(_make_spawn_payload(901, 3))

	assert_int(spawned.size()).is_equal(1)
	assert_int(spawned[0].id).is_equal(901)
	assert_bool(spawned[0].has_component(CN_NetworkIdentity)).is_true()
	assert_int(local_spawned.size()).is_equal(0)


func test_handle_spawn_entity_emits_local_player_spawned():
	# An entity owned by the local peer emits both signals, with
	# CN_LocalAuthority already injected.
	manager = SpawnManager.new(mock_ns)
	mock_ns.net_adapter._is_server = false
	mock_ns.net_adapter._my_peer_id = 2

	var spawned: Array = []
	var local_spawned: Array = []
	mock_ns.entity_spawned.connect(func(e): spawned.append(e))
	mock_ns.local_player_spawned.connect(func(e): local_spawned.append(e))

	manager.handle_spawn_entity(_make_spawn_payload(902, 2))

	assert_int(spawned.size()).is_equal(1)
	assert_int(local_spawned.size()).is_equal(1)
	assert_bool(local_spawned[0].has_component(CN_LocalAuthority)).is_true()


func test_handle_spawn_entity_update_does_not_re_emit():
	# A second payload for an already-registered entity is an update, not a spawn.
	manager = SpawnManager.new(mock_ns)
	mock_ns.net_adapter._is_server = false
	mock_ns.net_adapter._my_peer_id = 2

	var spawned: Array = []
	mock_ns.entity_spawned.connect(func(e): spawned.append(e))

	var data = _make_spawn_payload(903, 3)
	manager.handle_spawn_entity(data)
	manager.handle_spawn_entity(data)

	assert_int(spawned.size()).is_equal(1)
