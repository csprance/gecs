class_name LevelUtils

static func load_level(level: LevelResource) -> void:
	# Find  all of our persistent entities
	var world = ECS.world
	var persistent = world.query.with_all([C_Persistent]).execute()

	# Purge the world of all entities that are not persistent
	world.purge(false, persistent)
	# nuke everything else and take the persistent entities out of the tree
	for child in world.get_children():
		if not child in persistent:
			child.queue_free()
		else:
			world.remove_child(child)
	
	# Create the new level and add our persistent entities to tree again
	var new_level = level.packed_scene.instantiate() as Level
	# add our level in 
	world.add_child(new_level)
	# Set our properties
	world.entity_nodes_root = new_level.entities.get_path()
	world.system_nodes_root = new_level.systems.get_path()
	
	# Add the peristent entities back to the tree
	for entity in persistent:
		world.get_node(world.entity_nodes_root).add_child(entity)
	
	world.initialize()