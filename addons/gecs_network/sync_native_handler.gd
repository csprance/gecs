extends RefCounted
## MultiplayerSynchronizer setup, model instantiation, cleanup, visibility, diagnostics.
##
## Internal helper for NetworkSync. No class_name - not part of public API.

var _ns  # NetworkSync reference (untyped to avoid circular deps)


func _init(network_sync) -> void:
	_ns = network_sync


# ============================================================================
# SYNC MODEL INSTANTIATION (for native sync timing)
# ============================================================================


## Synchronously instantiate model for an entity during spawn.
## This ensures the node structure (Entity -> Model -> _NetSync) exists before
## the server's sync data arrives. Without this, MultiplayerSynchronizer can't
## find its target node and produces "Node not found" errors.
##
## Uses sync_config to determine component names and property paths, keeping
## the addon generic and configurable per-project.
func sync_instantiate_model(entity: Entity) -> bool:
	# Check if model instantiation is configured
	if _ns.sync_config.model_component.is_empty():
		return false  # Not configured, skip

	# Find model component by name
	var model_comp = _ns._find_component_by_type(entity, _ns.sync_config.model_component)
	if not model_comp:
		return false  # No model component

	# Check if already instantiated
	var is_instantiated = model_comp.get(_ns.sync_config.model_instantiated_property)
	if is_instantiated:
		return true  # Already done

	# Get scene path
	var scene_path = model_comp.get(_ns.sync_config.model_scene_path_property)
	if scene_path == null or scene_path == "":
		if _ns.debug_logging:
			print("[NetworkSync] Entity %s has model component but no scene path" % entity.name)
		return false

	# Validate scene path before loading (security: prevent loading arbitrary files)
	if not scene_path.begins_with("res://"):
		push_warning("[NetworkSync] Invalid scene path (must start with res://): %s" % scene_path)
		return false

	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_warning(
			"[NetworkSync] Scene file does not exist or is not a PackedScene: %s" % scene_path
		)
		return false

	# Load and instantiate scene
	var packed_scene = load(scene_path) as PackedScene
	if not packed_scene:
		print("[NetworkSync] Failed to load model scene: %s" % scene_path)
		return false

	var model_instance = packed_scene.instantiate()
	if not model_instance:
		print("[NetworkSync] Failed to instantiate model from: %s" % scene_path)
		return false

	# Add model as child of entity
	entity.add_child(model_instance)

	# Store instance reference on component
	model_comp.set(_ns.sync_config.model_instance_property, model_instance)
	model_comp.set(_ns.sync_config.model_instantiated_property, true)

	# Set position from transform component if available
	if _ns.sync_config.transform_component != "":
		var transform_comp = _ns._find_component_by_type(
			entity, _ns.sync_config.transform_component
		)
		if transform_comp and "position" in transform_comp and model_instance is Node3D:
			(model_instance as Node3D).global_position = transform_comp.position

	# Populate component references (CharacterBody3D, CN_SyncEntity.target_node, etc.)
	populate_model_references(entity, model_instance)

	# Add model_ready_component marker (prevents game's model system from re-processing)
	if _ns.sync_config.model_ready_class != null:
		entity.add_component(_ns.sync_config.model_ready_class.new())

	if _ns.debug_logging:
		print(
			"[NetworkSync] Sync-instantiated model for %s (scene: %s)" % [entity.name, scene_path]
		)

	return true


## Populate component references from instantiated model.
## Sets up CharacterBody3D reference, sync target, multiplayer authority, and animation references.
func populate_model_references(entity: Entity, model_instance: Node) -> void:
	# Set CharacterBody3D reference if configured
	if (
		_ns.sync_config.character_body_component != ""
		and _ns.sync_config.character_body_property != ""
		and model_instance is CharacterBody3D
	):
		var body = model_instance as CharacterBody3D
		var char_body_comp = _ns._find_component_by_type(
			entity, _ns.sync_config.character_body_component
		)
		if char_body_comp:
			char_body_comp.set(_ns.sync_config.character_body_property, body)

		# Set CN_SyncEntity.target_node to the body (for MultiplayerSynchronizer)
		var sync_comp = entity.get_component(CN_SyncEntity)
		if sync_comp:
			sync_comp.target_node = body

		# Propagate multiplayer authority from Entity to CharacterBody3D
		# Godot does NOT inherit authority from parent nodes automatically
		var entity_authority = entity.get_multiplayer_authority()
		body.set_multiplayer_authority(entity_authority)

		if _ns.debug_logging:
			print(
				(
					"[NetworkSync] Set up CharacterBody3D for %s (authority=%d)"
					% [entity.name, entity_authority]
				)
			)

	# Set animation references if configured
	if _ns.sync_config.animation_rig_component != "":
		var anim_rig_comp = _ns._find_component_by_type(
			entity, _ns.sync_config.animation_rig_component
		)
		if anim_rig_comp:
			# Look for Rig node
			if (
				_ns.sync_config.animation_rig_property != ""
				and _ns.sync_config.animation_rig_node_name != ""
			):
				var rig_node = model_instance.get_node_or_null(
					_ns.sync_config.animation_rig_node_name
				)
				if rig_node:
					anim_rig_comp.set(_ns.sync_config.animation_rig_property, rig_node)
					if _ns.debug_logging:
						print(
							(
								"[NetworkSync] Set %s.%s for %s"
								% [
									_ns.sync_config.animation_rig_component,
									_ns.sync_config.animation_rig_property,
									entity.name
								]
							)
						)

			# Look for AnimationPlayer
			if (
				_ns.sync_config.animation_player_property != ""
				and _ns.sync_config.animation_player_node_name != ""
			):
				var anim_player = model_instance.get_node_or_null(
					_ns.sync_config.animation_player_node_name
				)
				if anim_player and anim_player is AnimationPlayer:
					anim_rig_comp.set(_ns.sync_config.animation_player_property, anim_player)
					if _ns.debug_logging:
						print(
							(
								"[NetworkSync] Set %s.%s for %s"
								% [
									_ns.sync_config.animation_rig_component,
									_ns.sync_config.animation_player_property,
									entity.name
								]
							)
						)

			# Look for AnimationTree (created by S_AnimationTreeSetup)
			if (
				_ns.sync_config.animation_tree_property != ""
				and _ns.sync_config.animation_tree_node_name != ""
			):
				var anim_tree = model_instance.get_node_or_null(
					_ns.sync_config.animation_tree_node_name
				)
				if anim_tree and anim_tree is AnimationTree:
					anim_rig_comp.set(_ns.sync_config.animation_tree_property, anim_tree)
					if _ns.debug_logging:
						print(
							(
								"[NetworkSync] Set %s.%s for %s"
								% [
									_ns.sync_config.animation_rig_component,
									_ns.sync_config.animation_tree_property,
									entity.name
								]
							)
						)


# ============================================================================
# AUTO-SETUP NATIVE SYNC (MultiplayerSynchronizer)
# ============================================================================


func auto_setup_native_sync(entity: Entity) -> void:
	var sync_comp = entity.get_component(CN_SyncEntity)
	if not sync_comp:
		return  # No sync component, skip native sync setup

	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		print("Entity %s has CN_SyncEntity but no CN_NetworkIdentity" % entity.id)
		return

	# Get sync target - prefer character_body_component.body if available and target_node not set
	var target = sync_comp.get_sync_target(entity)
	if target == entity and _ns.sync_config.character_body_component != "":
		# target_node wasn't set, check for configured character body component
		var char_body_comp = _ns._find_component_by_type(
			entity, _ns.sync_config.character_body_component
		)
		if char_body_comp:
			var body = (
				char_body_comp.get(_ns.sync_config.character_body_property)
				if _ns.sync_config.character_body_property != ""
				else null
			)
			if body and is_instance_valid(body):
				target = body
				if _ns.debug_logging:
					print(
						(
							"Using %s.%s as sync target for entity: %s"
							% [
								_ns.sync_config.character_body_component,
								_ns.sync_config.character_body_property,
								entity.id
							]
						)
					)

	if target == null:
		print("CN_SyncEntity.get_sync_target() returned null for entity: %s" % entity.id)
		return

	# Check if MultiplayerSynchronizer already exists
	var existing_sync = target.get_node_or_null("_NetSync")
	if existing_sync != null:
		if _ns.debug_logging:
			print("MultiplayerSynchronizer already exists for entity: %s" % entity.id)
		return

	# Validate target has required properties
	if not sync_comp.has_sync_properties():
		if _ns.debug_logging:
			print("No sync properties configured for entity: %s" % entity.id)
		return

	# Create MultiplayerSynchronizer
	var synchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "_NetSync"
	# Note: root_path defaults to ".." (parent), which is the CharacterBody3D
	# Don't override it - let Godot use the default

	# Configure replication
	var config = SceneReplicationConfig.new()

	# Add properties based on component settings
	# NOTE: Using ".:property" format where "." refers to the root_path (parent of synchronizer)
	# The synchronizer's root_path defaults to ".." (parent), so ".:property" means parent's property
	var property_paths = sync_comp.get_property_paths(target)
	var added_paths: Array[String] = []

	for prop_path in property_paths:
		var full_path: String = ""

		# Verify property exists on target
		if prop_path in ["global_position", "global_rotation", "velocity"]:
			# Standard Node3D/CharacterBody3D properties
			# Use ".:property" format - "." is relative to root_path (which is ".." = parent = target)
			full_path = ".:%s" % prop_path
		elif ":" in prop_path:
			# Child node property path (e.g., "Rig:rotation")
			# Format: ChildNode:property (no leading dot for child paths)
			var parts = prop_path.split(":")
			if parts.size() == 2:
				var child_name = parts[0]
				var child_prop = parts[1]
				var child_node = target.get_node_or_null(child_name)
				if child_node and child_prop in child_node:
					full_path = "%s:%s" % [child_name, child_prop]
				else:
					print(
						(
							"Child property '%s' not found on target for entity: %s"
							% [prop_path, entity.id]
						)
					)
			else:
				print("Invalid property path format '%s' for entity: %s" % [prop_path, entity.id])
		else:
			# Custom property on target node - check if exists
			if prop_path in target:
				full_path = ".:%s" % prop_path
			else:
				print("Property '%s' not found on target for entity: %s" % [prop_path, entity.id])

		# Add property and explicitly enable both spawn and sync
		if full_path != "":
			config.add_property(full_path)
			# Explicitly enable spawn sync (initial state when entity appears)
			config.property_set_spawn(full_path, true)
			# Explicitly enable continuous sync (ongoing updates)
			config.property_set_sync(full_path, true)
			# Set replication mode to ALWAYS for reliable position sync
			# (ON_CHANGE can miss updates if delta is small)
			config.property_set_replication_mode(
				full_path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS
			)
			added_paths.append(full_path)

	# Apply configuration BEFORE adding to tree
	synchronizer.replication_config = config

	# Configure advanced options
	synchronizer.visibility_update_mode = sync_comp.visibility_mode
	synchronizer.delta_interval = sync_comp.delta_interval
	synchronizer.replication_interval = sync_comp.replication_interval
	synchronizer.public_visibility = sync_comp.public_visibility

	# Set multiplayer authority BEFORE adding to tree
	# This is critical - Godot uses authority at add time to determine sync direction
	var actual_authority = net_id.peer_id if net_id.peer_id > 0 else 1
	synchronizer.set_multiplayer_authority(actual_authority)

	# Add to target node (this activates the synchronizer)
	target.add_child(synchronizer)

	# Connect to synchronizer signals for diagnostics (only on server - the sender)
	if _ns.net_adapter.is_server() and _ns.debug_logging:
		# synchronized signal: emitted each time a sync is sent/received
		if not synchronizer.synchronized.is_connected(
			_ns._state_handler.on_synchronizer_synchronized
		):
			synchronizer.synchronized.connect(
				_ns._state_handler.on_synchronizer_synchronized.bind(entity.name)
			)

	# DEBUG: Always log synchronizer creation for troubleshooting
	var target_path = target.get_path() if target else "null"
	var is_server_str = "SERVER" if _ns.net_adapter.is_server() else "CLIENT"
	if _ns.debug_logging:
		print(
			(
				"[NetworkSync] %s: Created MultiplayerSynchronizer for %s (target=%s, authority=%d, paths=%s)"
				% [is_server_str, entity.name, target_path, actual_authority, added_paths]
			)
		)

	if _ns.debug_logging:
		# Log detailed synchronizer state
		print(
			(
				"  -> replication_interval=%.3f, delta_interval=%.3f, public_visibility=%s"
				% [
					synchronizer.replication_interval,
					synchronizer.delta_interval,
					synchronizer.public_visibility
				]
			)
		)
		# Verify config properties were added correctly
		var config_props = config.get_properties()
		print("  -> config has %d properties" % config_props.size())
		for i in config_props.size():
			var prop = config_props[i]
			var spawn_enabled = config.property_get_spawn(prop)
			var sync_enabled = config.property_get_sync(prop)
			var repl_mode = config.property_get_replication_mode(prop)
			var mode_names = ["NEVER", "ALWAYS", "ON_CHANGE"]
			var mode_name = (
				mode_names[repl_mode]
				if repl_mode < mode_names.size()
				else "UNKNOWN(%d)" % repl_mode
			)
			print(
				(
					"     [%d] %s (spawn=%s, sync=%s, mode=%s)"
					% [i, prop, spawn_enabled, sync_enabled, mode_name]
				)
			)


## Clean up MultiplayerSynchronizer when entity is removed.
## This must be called BEFORE the entity is freed to prevent "Node not found" errors
## from stale sync data being sent to clients for removed entities.
func cleanup_synchronizer(entity: Entity) -> void:
	if not entity.has_component(CN_SyncEntity):
		return

	var sync_entity = entity.get_component(CN_SyncEntity) as CN_SyncEntity
	if not sync_entity or not sync_entity.target_node:
		return

	var target = sync_entity.target_node
	if not is_instance_valid(target):
		return

	var synchronizer = target.get_node_or_null("_NetSync")
	if synchronizer:
		# Disconnect signals before cleanup to prevent handlers accessing freed nodes
		if synchronizer.synchronized.is_connected(_ns._state_handler.on_synchronizer_synchronized):
			synchronizer.synchronized.disconnect(_ns._state_handler.on_synchronizer_synchronized)
		# Remove from scene tree immediately to stop sync
		synchronizer.get_parent().remove_child(synchronizer)
		synchronizer.queue_free()
		if _ns.debug_logging:
			print("[NetworkSync] Cleaned up MultiplayerSynchronizer for entity: %s" % entity.id)


## Log current sync status for all entities with CN_SyncEntity.
## Useful for debugging sync issues after peer connects.
func log_sync_status() -> void:
	if not _ns.debug_logging:
		return

	var sync_entities: Array = []
	for entity in _ns._world.entities:
		if entity.has_component(CN_SyncEntity):
			sync_entities.append(entity)

	if sync_entities.is_empty():
		print("Sync status: No entities with CN_SyncEntity")
		return

	var prefix = "SERVER" if _ns.net_adapter.is_server() else "CLIENT"
	print("%s: Sync status - %d entities with CN_SyncEntity" % [prefix, sync_entities.size()])

	for entity in sync_entities:
		var sync_comp = entity.get_component(CN_SyncEntity)
		var net_id = entity.get_component(CN_NetworkIdentity)
		var target = sync_comp.get_sync_target(entity)

		var status_parts: Array = []

		# Check MultiplayerSynchronizer
		var synchronizer: MultiplayerSynchronizer = null
		if target:
			synchronizer = target.get_node_or_null("_NetSync") as MultiplayerSynchronizer

		if synchronizer:
			var authority = synchronizer.get_multiplayer_authority()
			var is_local = net_id and net_id.is_local(_ns.net_adapter)
			status_parts.append("sync=OK")
			status_parts.append("auth=%d" % authority)
			status_parts.append("local=%s" % is_local)
			if synchronizer.replication_config:
				var prop_count = synchronizer.replication_config.get_properties().size()
				status_parts.append("props=%d" % prop_count)
		else:
			status_parts.append("sync=MISSING")

		# Target node info
		if target:
			status_parts.append("target=%s" % target.name)
		else:
			status_parts.append("target=null")

		print("  -> %s: %s" % [entity.id, ", ".join(status_parts)])


# ============================================================================
# SYNCHRONIZER VISIBILITY REFRESH
# ============================================================================


## Refresh visibility for all existing MultiplayerSynchronizers.
## Called when a new peer connects to ensure they receive updates from existing entities.
## This forces synchronizers to update their peer visibility lists.
func refresh_synchronizer_visibility() -> void:
	var refreshed_count = 0
	var missing_sync_count = 0

	for entity in _ns._world.entities:
		var sync_comp = entity.get_component(CN_SyncEntity)
		if not sync_comp:
			continue

		var target = sync_comp.get_sync_target(entity)
		if not target:
			continue

		var synchronizer = target.get_node_or_null("_NetSync") as MultiplayerSynchronizer
		if not synchronizer:
			missing_sync_count += 1
			if _ns.debug_logging:
				print("Entity %s has CN_SyncEntity but no MultiplayerSynchronizer yet" % entity.id)
			continue

		# Force visibility update by toggling public_visibility
		# This triggers Godot to rebuild the peer visibility list
		var was_public = synchronizer.public_visibility
		synchronizer.public_visibility = false
		synchronizer.public_visibility = was_public
		refreshed_count += 1

		if _ns.debug_logging:
			print(
				(
					"Refreshed visibility for entity: %s (authority=%d)"
					% [entity.id, synchronizer.get_multiplayer_authority()]
				)
			)

	if _ns.debug_logging:
		var prefix = "SERVER" if _ns.net_adapter.is_server() else "CLIENT"
		print(
			(
				"%s: Refreshed %d synchronizers (%d entities without sync)"
				% [prefix, refreshed_count, missing_sync_count]
			)
		)


# ============================================================================
# POSITION SNAPSHOTS
# ============================================================================


## Send current position snapshot to a specific peer.
## Called deferred after world state to ensure entity setup is complete.
func send_position_snapshot(peer_id: int) -> void:
	var positions: Dictionary = {}

	for entity in _ns._world.entities:
		var net_id = entity.get_component(CN_NetworkIdentity)
		if not net_id:
			continue

		if _ns.sync_config.transform_component == "":
			continue  # Transform component not configured

		var transform_comp = _ns._find_component_by_type(
			entity, _ns.sync_config.transform_component
		)
		if not transform_comp:
			continue

		# Also get position from CharacterBody3D if available (more accurate)
		var sync_comp = entity.get_component(CN_SyncEntity)
		var pos = transform_comp.get("position") if "position" in transform_comp else Vector3.ZERO
		var rot = transform_comp.get("rotation") if "rotation" in transform_comp else Vector3.ZERO

		if sync_comp and sync_comp.target_node:
			var target = sync_comp.target_node
			if "global_position" in target:
				pos = target.global_position
			# Get rig rotation if available (uses configurable node name)
			var rig_name = (
				_ns.sync_config.animation_rig_node_name
				if _ns.sync_config and _ns.sync_config.animation_rig_node_name != ""
				else "Rig"
			)
			var rig = target.get_node_or_null(rig_name)
			if rig and "rotation" in rig:
				rot = rig.rotation

		positions[entity.id] = {"position": pos, "rotation": rot}

	if not positions.is_empty():
		if _ns.debug_logging:
			print(
				"Sending position snapshot to peer %d (%d entities)" % [peer_id, positions.size()]
			)
		_ns._apply_position_snapshot.rpc_id(peer_id, positions)


## Apply position snapshot received from server.
func handle_apply_position_snapshot(positions: Dictionary) -> void:
	if _ns.debug_logging:
		print("Received position snapshot with %d entities" % positions.size())

	for entity_id in positions.keys():
		var entity = _ns._world.entity_id_registry.get(entity_id)
		if not entity:
			continue

		var data = positions[entity_id]
		var pos: Vector3 = data.get("position", Vector3.ZERO)
		var rot: Vector3 = data.get("rotation", Vector3.ZERO)

		# Update transform component
		if _ns.sync_config.transform_component != "":
			var transform_comp = _ns._find_component_by_type(
				entity, _ns.sync_config.transform_component
			)
			if transform_comp:
				if "position" in transform_comp:
					transform_comp.set("position", pos)
				if "rotation" in transform_comp:
					transform_comp.set("rotation", rot)

		# Also update CharacterBody3D directly if available
		var sync_comp = entity.get_component(CN_SyncEntity)
		if sync_comp and sync_comp.target_node:
			var target = sync_comp.target_node
			if "global_position" in target:
				target.global_position = pos
			var rig_name = (
				_ns.sync_config.animation_rig_node_name
				if _ns.sync_config and _ns.sync_config.animation_rig_node_name != ""
				else "Rig"
			)
			var rig = target.get_node_or_null(rig_name)
			if rig and "rotation" in rig:
				rig.rotation = rot
