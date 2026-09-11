## GECS IO Utility Class[br]
##
## Provides functions for generating UUIDs, serializing/deserializing [Entity]s to/from [GecsData],
## and saving/loading [GecsData] to/from files.
class_name GECSIO

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

## Serialize a [QueryBuilder] of [Entity](s) to [GecsData] format.[br]
## Optionally takes a [GECSSerializeConfig] to customize what gets serialized.
static func serialize(query: QueryBuilder, config: GECSSerializeConfig = null) -> GecsData:
	return serialize_entities(query.execute() as Array[Entity], config)

## Serialize a list of [Entity](s) to [GecsData] format.[br]
## Optionally takes a [GECSSerializeConfig] to customize what gets serialized.
static func serialize_entities(entities: Array, config: GECSSerializeConfig = null) -> GecsData:
	# Pass 1: Serialize entities from original query
	var entity_data_array: Array[GecsEntityData] = []
	var processed_entities: Dictionary = {} # id -> bool
	var entity_id_mapping: Dictionary = {} # id -> Entity
	for entity in entities:
		var effective_config = _resolve_config(entity, config)
		var entity_data = _serialize_entity(entity, false, effective_config)
		entity_data_array.append(entity_data)
		processed_entities[entity.id] = true
		entity_id_mapping[entity.id] = entity

	# Pass 2: Scan relationships and auto-include referenced entities (if enabled)
	var entities_to_check = entities.duplicate()
	var check_index = 0

	while check_index < entities_to_check.size():
		var entity = entities_to_check[check_index]
		var effective_config = _resolve_config(entity, config)

		# Only proceed if config allows including related entities
		if effective_config.include_related_entities:
			# Check all relationships of this entity
			for relationship in entity.relationships:
				if relationship.target is Entity:
					var target_entity = relationship.target as Entity
					var target_id = target_entity.id

					# If this entity hasn't been processed yet, auto-include it
					if not processed_entities.has(target_id):
						var target_config = _resolve_config(target_entity, config)
						var auto_entity_data = _serialize_entity(target_entity, true, target_config)
						entity_data_array.append(auto_entity_data)
						processed_entities[target_id] = true
						entity_id_mapping[target_id] = target_entity

						# Add to list for further relationship checking
						entities_to_check.append(target_entity)

		check_index += 1

	return GecsData.new(entity_data_array)

## Save [GecsData] to a file at the specified path.[br]
## If binary is true, saves in binary format (.res), otherwise text format (.tres).
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

## Load and deserialize [Entity](s) from a file at the specified path.[br]
## Supports both binary (.res) and text (.tres) formats, tries binary first.
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

## Deserialize [GecsData] into a list of [Entity](s).[br]
## This can be used so you can serialize entities to GECS Data and then Deserailize that [GecsSData] later
static func deserialize_gecs_data(gecs_data: GecsData) -> Array[Entity]:
	var entities: Array[Entity] = []
	var id_to_entity: Dictionary = {} # id -> Entity

	# Pass 1: Create all entities and build ID mapping
	for entity_data in gecs_data.entities:
		var entity = _deserialize_entity(entity_data)
		entities.append(entity)
		id_to_entity[entity.id] = entity

	# Pass 2: Restore relationships using ID mapping
	for i in entities.size():
		var entity = entities[i]
		var entity_data = gecs_data.entities[i]

		# Restore relationships
		for rel_data in entity_data.relationships:
			var relationship = rel_data.to_relationship(id_to_entity)
			if relationship != null:
				entity.add_relationship(relationship)
			# Note: Invalid relationships are skipped with warning logged in to_relationship()

	return entities

## Helper function to resolve the effective configuration for an entity
## Priority: provided_config > entity.serialize_config > world.default_serialize_config > fallback
static func _resolve_config(entity: Entity, provided_config: GECSSerializeConfig) -> GECSSerializeConfig:
	if provided_config != null:
		return provided_config
	return entity.get_effective_serialize_config()

## Helper function to serialize a single entity with its components and relationships
static func _serialize_entity(entity: Entity, auto_included: bool, config: GECSSerializeConfig) -> GecsEntityData:
	# Serialize components (filtered by config)
	var components: Array[Component] = []
	for component in entity.components.values():
		if config.should_include_component(component):
			# Duplicate the component to avoid modifying the original
			components.append(component.duplicate(true))

	# Serialize relationships (if enabled by config)
	var relationships: Array[GecsRelationshipData] = []
	if config.include_relationships:
		for relationship in entity.relationships:
			var rel_data = GecsRelationshipData.from_relationship(relationship)
			relationships.append(rel_data)

	return GecsEntityData.new(
		entity.name,
		entity.scene_file_path if entity.scene_file_path != "" else "",
		components,
		relationships,
		auto_included,
		entity.id
	)

## Helper function to load and deserialize entities from a given file path
static func _load_from_path(file_path: String) -> Array[Entity]:
	print("GECS _load_from_path: Loading file: ", file_path)
	var gecs_data = load(file_path) as GecsData
	if not gecs_data:
		push_error("GECS deserialize: Could not load GecsData resource: " + file_path)
		return []

	print("GECS _load_from_path: Loaded GecsData with ", gecs_data.entities.size(), " entities")

	return deserialize_gecs_data(gecs_data)

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

	# Restore id (important: set this directly)
	entity.id = entity_data.id

	# Add components (they're already properly typed as Component resources)
	for component in entity_data.components:
		entity.add_component(component.duplicate(true))

	return entity
