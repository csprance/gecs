class_name NativeSyncHandler
extends RefCounted
## NativeSyncHandler — manages MultiplayerSynchronizer lifecycle for entities with CN_NativeSync.
##
## Called from SpawnManager._apply_component_data() after authority markers are injected.
## Follows same delegation pattern as SpawnManager, SyncSender, SyncReceiver.
##
## Critical ordering constraints (must NOT be reordered):
##   1. Set replication_config BEFORE add_child()
##   2. Call set_multiplayer_authority() BEFORE add_child()
##   3. Call add_child() — activates replication

var _ns  # NetworkSync reference (untyped to avoid circular deps)


func _init(network_sync) -> void:
	_ns = network_sync


## Set up a MultiplayerSynchronizer for entity if it has CN_NativeSync.
## Idempotent: no-op if "_NetSync" child already exists.
func setup_native_sync(entity: Entity) -> void:
	var native_sync: CN_NativeSync = entity.get_component(CN_NativeSync)
	if native_sync == null:
		return

	var net_id: CN_NetworkIdentity = entity.get_component(CN_NetworkIdentity)
	if net_id == null:
		return

	# Idempotent guard — skip if already set up
	if entity.get_node_or_null("_NetSync") != null:
		return

	var config := SceneReplicationConfig.new()

	if native_sync.sync_position:
		var path := ".:position"
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_sync(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)

	if native_sync.sync_rotation:
		var path := ".:rotation"
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_sync(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)

	var synchronizer := MultiplayerSynchronizer.new()
	synchronizer.name = "_NetSync"
	synchronizer.replication_config = config                        # BEFORE add_child
	synchronizer.replication_interval = native_sync.replication_interval

	# CRITICAL: peer_id=0 means server-owned in GECS v2; Godot uses 1 for server
	var authority: int = net_id.peer_id if net_id.peer_id > 0 else 1
	synchronizer.set_multiplayer_authority(authority)               # BEFORE add_child

	entity.add_child(synchronizer)                                  # Activates replication


## Remove the MultiplayerSynchronizer child from entity.
## Call before entity.queue_free() to ensure clean teardown.
func cleanup_native_sync(entity: Entity) -> void:
	var synchronizer = entity.get_node_or_null("_NetSync")
	if synchronizer:
		synchronizer.get_parent().remove_child(synchronizer)
		synchronizer.queue_free()


## Force visibility refresh on all entity synchronizers.
## Called deferred after world state is sent to a new peer, so synchronizers
## know to send initial snapshots to the newly connected client.
func refresh_synchronizer_visibility() -> void:
	if _ns._world == null:
		return
	for entity in _ns._world.entities:
		var synchronizer = entity.get_node_or_null("_NetSync") as MultiplayerSynchronizer
		if not synchronizer:
			continue
		# Use documented update_visibility(0) API — 0 = all peers
		synchronizer.update_visibility(0)
