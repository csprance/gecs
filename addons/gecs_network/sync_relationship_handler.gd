extends RefCounted
## Relationship sync: serialize/deserialize relationships as creation recipes, broadcast add/remove.
##
## Internal helper for NetworkSync. No class_name - not part of public API.
##
## Design principle: Sync the "recipe", not the "object". The receiver creates fresh
## relation component instances with defaults via .new(). If relation component data
## matters, it's processed server-side and results reach clients via existing component
## property sync.
##
## Creation Recipe Format:
##   { "r": "res://game/components/c_damaged.gd", "tt": "E", "t": "uuid-123" }
##
## Target types:
##   "E" = Entity (resolved via entity_id_registry)
##   "C" = Component (instantiated from script path)
##   "S" = Script (loaded as archetype reference)
##   "N" = Null (no target)

## NetworkSync reference (untyped to avoid circular deps).
## Expected interface: sync_config, net_adapter, _world, _game_session_id,
## _applying_network_data, _sync_relationship_add, _sync_relationship_remove.
var _ns

## Pending relationships waiting for entity target resolution.
## { source_entity_id: Array[Dictionary] } where each dict is a raw recipe.
var _pending_relationships: Dictionary = {}

## Flag to prevent sync loops when applying received relationship data.
var _applying_relationship_data: bool = false


func _init(network_sync) -> void:
	_ns = network_sync


# ============================================================================
# SERIALIZATION
# ============================================================================


## Serialize a single Relationship into a creation recipe dictionary.
## Returns empty dictionary if relationship cannot be serialized.
func serialize_relationship(relationship: Relationship) -> Dictionary:
	if not _ns.sync_config or not _ns.sync_config.sync_relationships:
		return {}

	var relation = relationship.relation
	if relation == null:
		return {}

	var relation_script = relation.get_script()
	if relation_script == null or relation_script.resource_path == "":
		return {}

	var recipe: Dictionary = {
		"r": relation_script.resource_path,
	}

	var target = relationship.target
	if target == null:
		recipe["tt"] = "N"
		recipe["t"] = ""
	elif target is Entity:
		recipe["tt"] = "E"
		recipe["t"] = target.id
	elif target is Component:
		var target_script = target.get_script()
		if target_script == null or target_script.resource_path == "":
			return {}
		recipe["tt"] = "C"
		recipe["t"] = target_script.resource_path
	elif target is Script:
		recipe["tt"] = "S"
		recipe["t"] = target.resource_path
	else:
		# Unsupported target type
		return {}

	return recipe


## Deserialize a creation recipe dictionary into a Relationship.
## Returns null if the recipe is invalid or Entity target is unresolved.
## When an Entity target cannot be resolved, returns null (caller should queue for deferred resolution).
func deserialize_relationship(data: Dictionary) -> Relationship:
	var relation_path = data.get("r", "")
	var target_type = data.get("tt", "")
	var target_ref = data.get("t", "")

	if relation_path == "" or target_type == "":
		return null

	var relation_instance = _load_script_instance(relation_path)
	if relation_instance == null:
		return null

	# Resolve target based on type
	var target = _resolve_target(target_type, target_ref)
	if target == null and target_type != "N":
		return null

	return Relationship.new(relation_instance, target)


## Load and instantiate a script from a validated resource path.
func _load_script_instance(script_path: String):
	if not script_path.begins_with("res://") or not ResourceLoader.exists(script_path):
		return null
	var script = load(script_path)
	if script == null:
		return null
	if not script is Script or not script.can_instantiate():
		return null
	return script.new()


## Resolve a relationship target from its serialized type and reference.
## Returns null for "N" (null target), Entity for "E", Component instance for "C", Script for "S".
func _resolve_target(target_type: String, target_ref: String):
	match target_type:
		"N":
			return null
		"E":
			# Entity not yet in world returns null - caller should queue for deferred resolution
			if target_ref != "" and _ns and _ns._world and _ns._world.entity_id_registry:
				return _ns._world.entity_id_registry.get(target_ref)
			return null
		"C":
			return _load_script_instance(target_ref)
		"S":
			if target_ref.begins_with("res://") and ResourceLoader.exists(target_ref):
				return load(target_ref)
	return null


## Serialize all relationships for an entity.
func serialize_entity_relationships(entity: Entity) -> Array[Dictionary]:
	if not _ns.sync_config or not _ns.sync_config.sync_relationships:
		return []

	var result: Array[Dictionary] = []
	for relationship in entity.relationships:
		var recipe = serialize_relationship(relationship)
		if not recipe.is_empty():
			result.append(recipe)
	return result


## Deserialize and apply relationships to an entity from an array of recipes.
## Unresolvable Entity targets are queued for deferred resolution.
func apply_entity_relationships(entity: Entity, data: Array) -> void:
	if data.is_empty():
		return

	_applying_relationship_data = true

	for recipe in data:
		var relationship = deserialize_relationship(recipe)
		if relationship != null:
			if is_instance_valid(entity):
				entity.add_relationship(relationship)
		elif recipe.get("tt", "") == "E":
			# Entity target unresolved - queue for deferred resolution
			if not _pending_relationships.has(entity.id):
				_pending_relationships[entity.id] = []
			_pending_relationships[entity.id].append(recipe)
		else:
			push_warning("SyncRelationshipHandler: Failed to deserialize relationship recipe: %s" % str(recipe))

	_applying_relationship_data = false


# ============================================================================
# DEFERRED ENTITY TARGET RESOLUTION
# ============================================================================


## Called when an entity is added to the world. Check if any pending relationships
## were waiting for this entity as their target.
func try_resolve_pending(entity: Entity) -> void:
	if _pending_relationships.is_empty():
		return

	# Check all pending sources to see if any are waiting for this entity as target
	var resolved_sources: Array[String] = []

	_applying_relationship_data = true
	for source_id in _pending_relationships.keys():
		if _ns == null or _ns._world == null or _ns._world.entity_id_registry == null:
			_applying_relationship_data = false
			return
		var source_entity = _ns._world.entity_id_registry.get(source_id)
		if source_entity == null:
			# Source entity no longer exists - clean up
			resolved_sources.append(source_id)
			continue

		var pending_recipes: Array = _pending_relationships[source_id]
		var still_pending: Array = []

		for recipe in pending_recipes:
			if recipe.get("tt", "") == "E" and recipe.get("t", "") == entity.id:
				# This pending relationship was waiting for the newly added entity
				var relationship = deserialize_relationship(recipe)
				if relationship != null and is_instance_valid(source_entity):
					source_entity.add_relationship(relationship)
				# else: still can't resolve (shouldn't happen since entity was just added)
			else:
				still_pending.append(recipe)

		if still_pending.is_empty():
			resolved_sources.append(source_id)
		else:
			_pending_relationships[source_id] = still_pending
	_applying_relationship_data = false

	for source_id in resolved_sources:
		_pending_relationships.erase(source_id)


# ============================================================================
# SIGNAL HANDLERS (called from NetworkSync)
# ============================================================================


## Called when a relationship is added to an entity in the local world.
func on_relationship_added(entity: Entity, relationship: Relationship) -> void:
	_broadcast_relationship_change(entity, relationship, _ns._sync_relationship_add)


## Called when a relationship is removed from an entity in the local world.
func on_relationship_removed(entity: Entity, relationship: Relationship) -> void:
	_broadcast_relationship_change(entity, relationship, _ns._sync_relationship_remove)


## Shared guard/authority/serialize/broadcast logic for relationship changes.
## rpc_callable is the bound RPC function to invoke (e.g. _ns._sync_relationship_add).
func _broadcast_relationship_change(entity: Entity, relationship: Relationship, rpc_callable: Callable) -> void:
	# Guard against sync loops
	if _applying_relationship_data or _ns._applying_network_data:
		return

	if not _ns.sync_config or not _ns.sync_config.sync_relationships:
		return

	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		return  # Non-networked entity

	# Authority check: only broadcast if we have authority
	if not _ns.net_adapter.is_server():
		# Client can only broadcast for own entities
		if net_id.peer_id != _ns.net_adapter.get_my_peer_id():
			return

	var recipe = serialize_relationship(relationship)
	if recipe.is_empty():
		return

	var payload = {"entity_id": entity.id, "recipe": recipe, "session_id": _ns._game_session_id}

	rpc_callable.rpc(payload)


# ============================================================================
# RPC HANDLERS (called from NetworkSync RPC stubs)
# ============================================================================


## Handle incoming relationship add RPC.
func handle_relationship_add(payload: Dictionary) -> void:
	var entity_id = payload.get("entity_id", "")
	var recipe = payload.get("recipe", {})
	var session_id = payload.get("session_id", 0)

	# Reject stale RPCs
	if session_id != _ns._game_session_id:
		return

	if _ns._world == null:
		return

	var sender_id = _ns.net_adapter.get_remote_sender_id()
	var entity = _ns._world.entity_id_registry.get(entity_id)
	if entity == null:
		return

	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		return

	# Authority validation (mirrors handle_add_component pattern)
	if _ns.net_adapter.is_server():
		# Server accepts from entity owner only
		if net_id.peer_id != sender_id:
			return
		# Relay to all clients. Trust assumption: recipe script paths (res://) are
		# relayed as-is. Receiving clients validate paths via _load_script_instance
		# (res:// prefix check + ResourceLoader.exists), so blast radius is limited
		# to scripts already present in the project.
		_ns._sync_relationship_add.rpc(payload)
	else:
		# Client accepts from server only
		if sender_id != 1:
			return
		# Skip if this is our own entity
		if net_id.is_local(_ns.net_adapter):
			return

	# Deserialize and apply
	_applying_relationship_data = true
	var relationship = deserialize_relationship(recipe)
	if relationship != null:
		if is_instance_valid(entity):
			entity.add_relationship(relationship)
	elif recipe.get("tt", "") == "E":
		# Queue for deferred resolution
		if not _pending_relationships.has(entity_id):
			_pending_relationships[entity_id] = []
		_pending_relationships[entity_id].append(recipe)
	_applying_relationship_data = false


## Handle incoming relationship remove RPC.
func handle_relationship_remove(payload: Dictionary) -> void:
	var entity_id = payload.get("entity_id", "")
	var recipe = payload.get("recipe", {})
	var session_id = payload.get("session_id", 0)

	# Reject stale RPCs
	if session_id != _ns._game_session_id:
		return

	if _ns._world == null:
		return

	var sender_id = _ns.net_adapter.get_remote_sender_id()
	var entity = _ns._world.entity_id_registry.get(entity_id)
	if entity == null:
		return

	var net_id = entity.get_component(CN_NetworkIdentity)
	if not net_id:
		return

	# Authority validation
	if _ns.net_adapter.is_server():
		if net_id.peer_id != sender_id:
			return
		# Relay to all clients (same trust assumption as handle_relationship_add)
		_ns._sync_relationship_remove.rpc(payload)
	else:
		if sender_id != 1:
			return
		if net_id.is_local(_ns.net_adapter):
			return

	# Deserialize a matching relationship pattern and remove
	_applying_relationship_data = true
	var relationship = deserialize_relationship(recipe)
	if relationship != null:
		entity.remove_relationship(relationship)
	else:
		# Fallback: target may be despawned, scan existing relationships by recipe fields
		var relation_path = recipe.get("r", "")
		var target_id = recipe.get("t", "")
		var found := false
		for existing_rel in entity.relationships:
			if existing_rel.relation == null:
				continue
			var rel_script = existing_rel.relation.get_script()
			if rel_script == null or rel_script.resource_path != relation_path:
				continue
			# Match target by entity id if target type is Entity
			if recipe.get("tt", "") == "E":
				if existing_rel.target is Entity and existing_rel.target.id == target_id:
					entity.remove_relationship(existing_rel)
					found = true
					break
				# Target entity already freed - match by null target with same relation
				if existing_rel.target == null or not is_instance_valid(existing_rel.target):
					entity.remove_relationship(existing_rel)
					found = true
					break
			else:
				# Non-Entity target: match by script path
				var target_ref = recipe.get("t", "")
				var target_type = recipe.get("tt", "")
				var matches := false

				if target_type == "N":
					# Null target: match null or freed targets
					if existing_rel.target == null or not is_instance_valid(existing_rel.target):
						matches = true
				elif target_type == "C":
					# Component target: match by script path
					if existing_rel.target is Component:
						var target_script = existing_rel.target.get_script()
						if target_script != null and target_script.resource_path == target_ref:
							matches = true
					elif existing_rel.target == null or not is_instance_valid(existing_rel.target):
						matches = true
				elif target_type == "S":
					# Script target: match by script path
					if existing_rel.target is Script:
						if existing_rel.target.resource_path == target_ref:
							matches = true
					elif existing_rel.target == null or not is_instance_valid(existing_rel.target):
						matches = true

				if matches:
					entity.remove_relationship(existing_rel)
					found = true
					break
		if not found:
			push_warning("handle_relationship_remove: no matching relationship found for entity_id=%s recipe=%s" % [entity_id, recipe])
	_applying_relationship_data = false


# ============================================================================
# STATE MANAGEMENT
# ============================================================================


## Clear all pending state for a new game session.
func reset() -> void:
	_pending_relationships.clear()
	_applying_relationship_data = false
