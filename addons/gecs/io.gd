class_name GECSIO


static func serialize(query: QueryBuilder) -> GecsData:
	var entity_data_array: Array[GecsEntityData] = []
	
	for entity in query.execute() as Array[Entity]:
		var components: Array[Component] = []
		for component in entity.components.values():
			# Duplicate the component to avoid modifying the original
			components.append(component)
		
		var entity_data = GecsEntityData.new(
			entity.name,
			entity.scene_file_path if entity.scene_file_path != "" else "",
			components
		)
		entity_data_array.append(entity_data)
	
	return GecsData.new(entity_data_array)


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
	
	for entity_data in gecs_data.entities:
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
		
		# Add components (they're already properly typed as Component resources)
		for component in entity_data.components:
			entity.add_component(component.duplicate(true))
		
		entities.append(entity)
	
	return entities