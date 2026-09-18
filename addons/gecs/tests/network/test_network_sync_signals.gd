extends GdUnitTestSuite
## Contract tests for NetworkSync's public spawn signals.
##
## Uses a REAL NetworkSync node (not MockNetworkSync) and drives the @rpc receiver
## methods directly, so the full path the docs promise is exercised:
##   _spawn_entity / _sync_world_state -> SpawnManager -> entity_spawned / local_player_spawned
##
## Also guards against the regression class that hid this bug: a signal that is
## declared (and documented) but never emitted anywhere.

const SIGNAL_SCAN_ROOT := "res://addons/gecs"
const SIGNAL_SCAN_EXCLUDED_DIRS := ["tests"]
## Signals that are intentionally never emitted. Every entry needs a reason;
## do not add one just to make the scan pass.
const SIGNAL_SCAN_ALLOWED_DEAD := {
	# Vestigial since v8.0.0 (remove_relationships emits relationship_removed
	# per-rel). Kept for API stability — see World._on_entity_relationships_batch_removed.
	"relationships_batch_removed": true,
}


class ClientNetAdapter:
	extends NetAdapter

	var _is_server: bool = false
	var _my_peer_id: int = 2

	func is_server() -> bool:
		return _is_server

	func get_my_peer_id() -> int:
		return _my_peer_id

	# No real multiplayer peer in tests — skips multiplayer signal wiring and
	# the server-side deferred broadcast.
	func is_in_game() -> bool:
		return false


var world: World
var net_sync: NetworkSync
var spawned: Array
var local_spawned: Array


func before_test():
	world = World.new()
	world.name = "TestWorld"
	add_child(world)
	ECS.world = world
	net_sync = NetworkSync.attach_to_world(world, ClientNetAdapter.new())
	spawned = []
	local_spawned = []
	net_sync.entity_spawned.connect(func(e): spawned.append(e))
	net_sync.local_player_spawned.connect(func(e): local_spawned.append(e))


func after_test():
	if is_instance_valid(world):
		for entity in world.entities.duplicate():
			world.remove_entity(entity)
			if is_instance_valid(entity):
				entity.free()
		world.free()
	world = null
	net_sync = null


## Build a spawn payload the way the server would, for an entity owned by [param peer_id].
func _make_spawn_payload(entity_id: int, peer_id: int) -> Dictionary:
	var source = Entity.new()
	source.name = "NetEntity%d" % entity_id
	source.add_component(CN_NetworkIdentity.new(peer_id))
	var data = net_sync._spawn_manager.serialize_entity(source)
	source.free()
	data["id"] = entity_id
	return data


# ============================================================================
# SPAWN RPC
# ============================================================================


func test_spawn_rpc_emits_entity_spawned():
	net_sync._spawn_entity(_make_spawn_payload(1001, 3))

	assert_int(spawned.size()).is_equal(1)
	assert_int(spawned[0].id).is_equal(1001)
	# Entity is fully set up by the time the signal fires
	assert_bool(world.entity_id_registry.has(1001)).is_true()
	assert_bool(spawned[0].has_component(CN_NetworkIdentity)).is_true()
	assert_int(spawned[0].get_component(CN_NetworkIdentity).peer_id).is_equal(3)
	# Remote peer's entity is not the local player
	assert_int(local_spawned.size()).is_equal(0)


func test_spawn_rpc_emits_local_player_spawned_for_own_entity():
	net_sync._spawn_entity(_make_spawn_payload(1002, 2))

	assert_int(spawned.size()).is_equal(1)
	assert_int(local_spawned.size()).is_equal(1)
	assert_object(local_spawned[0]).is_same(spawned[0])
	assert_bool(local_spawned[0].has_component(CN_LocalAuthority)).is_true()


func test_server_owned_entity_is_not_local_player():
	# peer_id 0 = server-owned NPC; never the local player, even though the
	# entity spawns fine.
	net_sync._spawn_entity(_make_spawn_payload(1003, 0))

	assert_int(spawned.size()).is_equal(1)
	assert_int(local_spawned.size()).is_equal(0)


func test_duplicate_spawn_rpc_does_not_re_emit():
	var data = _make_spawn_payload(1004, 2)
	net_sync._spawn_entity(data)
	net_sync._spawn_entity(data)

	assert_int(spawned.size()).is_equal(1)
	assert_int(local_spawned.size()).is_equal(1)


func test_stale_session_spawn_does_not_emit():
	var data = _make_spawn_payload(1005, 2)
	data["session_id"] = net_sync._game_session_id + 99
	net_sync._spawn_entity(data)

	assert_int(spawned.size()).is_equal(0)
	assert_int(local_spawned.size()).is_equal(0)


# ============================================================================
# WORLD STATE SYNC (late join)
# ============================================================================


func test_world_state_sync_emits_for_every_entity():
	# Late joiner: server is on a different session id, world state carries
	# two remote entities and our own player.
	var server_session := 7
	var entities: Array[Dictionary] = []
	for pair in [[1101, 1], [1102, 3], [1103, 2]]:
		var data = _make_spawn_payload(pair[0], pair[1])
		data["session_id"] = server_session
		entities.append(data)

	net_sync._sync_world_state({"entities": entities, "session_id": server_session})

	assert_int(spawned.size()).is_equal(3)
	assert_int(local_spawned.size()).is_equal(1)
	assert_int(local_spawned[0].id).is_equal(1103)


# ============================================================================
# REGRESSION GUARD: no declared-but-never-emitted signals
# ============================================================================


func test_every_declared_signal_is_emitted_somewhere():
	# entity_spawned / local_player_spawned were declared, documented and used in
	# the example for months without a single emit. A dead signal is legal
	# GDScript and fails silently, so scan the source for them.
	var sources: Dictionary = {}  # path -> source text
	_collect_sources(SIGNAL_SCAN_ROOT, sources)
	assert_int(sources.size()).is_greater(0)

	var all_source := "\n".join(sources.values())
	var decl := RegEx.create_from_string("(?m)^\\s*signal\\s+(\\w+)")

	var dead: Array[String] = []
	for path in sources:
		for m in decl.search_all(sources[path]):
			var sig: String = m.get_string(1)
			if SIGNAL_SCAN_ALLOWED_DEAD.has(sig):
				continue
			var emit := RegEx.create_from_string(
				"\\b%s\\.emit\\(|emit_signal\\(\\s*&?\"%s\"" % [sig, sig]
			)
			if emit.search(all_source) == null:
				dead.append("%s (%s)" % [sig, path])

	assert_array(dead).is_empty()


func _collect_sources(dir_path: String, out: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if sub in SIGNAL_SCAN_EXCLUDED_DIRS:
			continue
		_collect_sources(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			var path := dir_path.path_join(file)
			out[path] = FileAccess.get_file_as_string(path)


# ============================================================================
# HOST: the server never receives its own spawn RPC, so it is notified from
# the deferred broadcast instead.
# ============================================================================


class HostNetAdapter:
	extends NetAdapter

	func is_server() -> bool:
		return true

	func get_my_peer_id() -> int:
		return 1

	func is_in_game() -> bool:
		return true


## Swap the client NetworkSync from before_test() for a hosting one.
func _become_host() -> void:
	world.remove_child(net_sync)
	net_sync.free()
	net_sync = NetworkSync.attach_to_world(world, HostNetAdapter.new())
	net_sync.entity_spawned.connect(func(e): spawned.append(e))
	net_sync.local_player_spawned.connect(func(e): local_spawned.append(e))


func _add_host_entity(peer_id: int) -> Entity:
	var entity = Entity.new()
	entity.name = "HostEntity%d" % peer_id
	entity.add_component(CN_NetworkIdentity.new(peer_id))
	world.add_entity(entity)
	return entity


func test_host_gets_both_signals_for_own_player():
	_become_host()
	var player = _add_host_entity(1)

	# Broadcast (and the notification) is deferred so components can settle
	assert_int(spawned.size()).is_equal(0)
	await get_tree().process_frame

	assert_int(spawned.size()).is_equal(1)
	assert_object(spawned[0]).is_same(player)
	assert_int(local_spawned.size()).is_equal(1)
	assert_object(local_spawned[0]).is_same(player)
	assert_bool(player.has_component(CN_LocalAuthority)).is_true()


func test_host_gets_entity_spawned_for_remote_players_and_npcs():
	_become_host()
	_add_host_entity(2)  # a client's player
	_add_host_entity(0)  # server-owned NPC
	await get_tree().process_frame

	assert_int(spawned.size()).is_equal(2)
	assert_int(local_spawned.size()).is_equal(0)


func test_host_does_not_emit_for_non_networked_or_cancelled_entities():
	_become_host()
	var plain = Entity.new()
	plain.name = "PlainEntity"
	world.add_entity(plain)

	# Added then removed in the same frame: broadcast is cancelled, no signal
	var cancelled = _add_host_entity(1)
	world.remove_entity(cancelled)
	cancelled.free()
	await get_tree().process_frame

	assert_int(spawned.size()).is_equal(0)
	assert_int(local_spawned.size()).is_equal(0)
