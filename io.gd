class_name GECSIO


static func serialize(query: QueryBuilder) -> GecsData:
	var entity_data_array: Array[GecsEntityData] = []
	var processed_entities: Dictionary = {} # uuid -> bool
	var entity_uuid_mapping: Dictionary = {} # uuid -> Entity
	
	# Pass 1: Serialize entities from original query
	var query_entities = query.execute() as Array[Entity]
	for entity in query_entities:
		var entity_data = _serialize_entity(entity, false)
		entity_data_array.append(entity_data)
		processed_entities[entity.uuid] = true
		entity_uuid_mapping[entity.uuid] = entity
	
	# Pass 2: Scan relationships and auto-include referenced entities
	var entities_to_check = query_entities.duplicate()
	var check_index = 0
	
	while check_index < entities_to_check.size():
		var entity = entities_to_check[check_index]
		
		# Check all relationships of this entity
		for relationship in entity.relationships:
			if relationship.target is Entity:
				var target_entity = relationship.target as Entity
				var target_id = target_entity.uuid
				
				# If this entity hasn't been processed yet, auto-include it
				if not processed_entities.has(target_id):
					var auto_entity_data = _serialize_entity(target_entity, true)
					entity_data_array.append(auto_entity_data)
					processed_entities[target_id] = true
					entity_uuid_mapping[target_id] = target_entity
					
					# Add to list for further relationship checking
					entities_to_check.append(target_entity)
		
		check_index += 1
	
	return GecsData.new(entity_data_array)


## Helper function to serialize a single entity with its components and relationships
static func _serialize_entity(entity: Entity, auto_included: bool) -> GecsEntityData:
	# Serialize components
	var components: Array[Component] = []
	for component in entity.components.values():
		# Duplicate the component to avoid modifying the original
		components.append(component.duplicate(true))
	
	# Serialize relationships
	var relationships: Array[GecsRelationshipData] = []
	for relationship in entity.relationships:
		var rel_data = GecsRelationshipData.from_relationship(relationship)
		relationships.append(rel_data)
	
	return GecsEntityData.new(
		entity.name,
		entity.scene_file_path if entity.scene_file_path != "" else "",
		components,
		relationships,
		auto_included,
		entity.uuid
	)


static func save(gecs_data: GecsData, filepath: String, binary: bool = false) -> bool:
	var final_path = filepath
	var flags = 0
	
	if binary:
		# Convert .tres to .res for binary format
		final_path = filepath.replace(".tres", ".res")
		flags = ResourceSaver.FLAG_COMPRESS # Binary format uses no flags, .res extension determines format
	# else: text format (default flags = 0)
	
	var result = ResourceSaver.save(gecs_data, final_path, flags)
	if result != OK:
		push_error("GECS save: Failed to save resource to: " + final_path)
		return false
	return true


static func deserialize(gecs_filepath: String) -> Array[Entity]:
	# Try binary first (.res), then text (.tres)
	var binary_path = gecs_filepath.replace(".tres", ".res")
	
	if ResourceLoader.exists(binary_path):
		return _load_from_path(binary_path)
	elif ResourceLoader.exists(gecs_filepath):
		return _load_from_path(gecs_filepath)
	else:
		push_error("GECS deserialize: File not found: " + gecs_filepath)
		return []


static func _load_from_path(file_path: String) -> Array[Entity]:
	print("GECS _load_from_path: Loading file: ", file_path)
	var gecs_data = load(file_path) as GecsData
	if not gecs_data:
		push_error("GECS deserialize: Could not load GecsData resource: " + file_path)
		return []
	
	print("GECS _load_from_path: Loaded GecsData with ", gecs_data.entities.size(), " entities")
	var entities: Array[Entity] = []
	var uuid_to_entity: Dictionary = {} # uuid -> Entity
	
	# Pass 1: Create all entities and build UUID mapping
	for entity_data in gecs_data.entities:
		var entity = _deserialize_entity(entity_data)
		entities.append(entity)
		uuid_to_entity[entity.uuid] = entity
	
	# Pass 2: Restore relationships using UUID mapping
	for i in range(entities.size()):
		var entity = entities[i]
		var entity_data = gecs_data.entities[i]
		
		# Restore relationships
		for rel_data in entity_data.relationships:
			var relationship = rel_data.to_relationship(uuid_to_entity)
			if relationship != null:
				entity.add_relationship(relationship)
			# Note: Invalid relationships are skipped with warning logged in to_relationship()
	
	return entities


## Helper function to deserialize a single entity with its components and uuid
static func _deserialize_entity(entity_data: GecsEntityData) -> Entity:
	var entity: Entity
	
	# Check if this entity is a prefab (has scene file)
	if entity_data.scene_path != "":
		var scene_path = entity_data.scene_path
		if ResourceLoader.exists(scene_path):
			var packed_scene = load(scene_path) as PackedScene
			if packed_scene:
				entity = packed_scene.instantiate() as Entity
			else:
				push_warning("GECS deserialize: Could not load scene: " + scene_path + ", creating new entity")
				entity = Entity.new()
		else:
			push_warning("GECS deserialize: Scene file not found: " + scene_path + ", creating new entity")
			entity = Entity.new()
	else:
		# Create new entity
		entity = Entity.new()
	
	# Set entity name
	entity.name = entity_data.entity_name
	
	# Restore uuid (important: set this before accessing the property to avoid generating new UUID)
	if entity_data.uuid != "":
		# Set the uuid directly (bypassing the property getter to avoid UUID generation)
		entity.set("uuid", entity_data.uuid)
	else:
		# Fallback for old format: generate UUID but log warning
		push_warning("GECS deserialize: Entity '" + entity_data.entity_name + "' missing uuid, generating new UUID")
		# Let the property getter generate a new UUID
		var __ = entity.uuid
	
	# Add components (they're already properly typed as Component resources)
	for component in entity_data.components:
		entity.add_component(component.duplicate(true))
	
	return entity


## Generates a custom GUID using random bytes.[br]
## The format uses 16 random bytes encoded to hex and formatted with hyphens.
static func uuid() -> String:
	const BYTE_MASK: int = 0b11111111
	# 16 random bytes with the bytes on index 6 and 8 modified
	var b = [
		randi() & BYTE_MASK, randi() & BYTE_MASK, randi() & BYTE_MASK, randi() & BYTE_MASK,
		randi() & BYTE_MASK, randi() & BYTE_MASK, ((randi() & BYTE_MASK) & 0x0f) | 0x40, randi() & BYTE_MASK,
		((randi() & BYTE_MASK) & 0x3f) | 0x80, randi() & BYTE_MASK, randi() & BYTE_MASK, randi() & BYTE_MASK,
		randi() & BYTE_MASK, randi() & BYTE_MASK, randi() & BYTE_MASK, randi() & BYTE_MASK,
	]

	return '%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x' % [
		# low
		b[0], b[1], b[2], b[3],

		# mid
		b[4], b[5],

		# hi
		b[6], b[7],

		# clock
		b[8], b[9],

		# clock
		b[10], b[11], b[12], b[13], b[14], b[15]
	]
