# meta-description: An Observer watches for changes to a specific type of Component on all Entities in the world.
class_name _CLASS_
extends Observer


func watch() -> Resource:
	return Component

# func on_component_added(entity: Entity, component: Resource):
# 	pass

# func on_component_removed(entity: Entity, component: Resource):
# 	pass

# func on_component_changed(
# 	entity: Entity, component: Resource, property: String, new_value: Variant, old_value: Variant
# ):
# 	pass
