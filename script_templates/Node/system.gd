# meta-description: A System processes all Entities that match a query.
class_name _CLASS_
extends System

# Remember: Systems contain the meat and potatos of everything and can delete
# themselves or add other systems etc. System order matters.
## Override this method to define the [System]s that this system depends on.[br]
## If not overridden the system will run based on the order of the systems in the [World][br]
## and the order of the systems in the [World] will be based on the order they were added to the [World].[br]
func deps() -> Dictionary[int, Array]:
	return {
		Runs.After: [],
		Runs.Before: [],
	}


## Override this method and return a [QueryBuilder] to define the required [Component]s for the system.[br]
## If not overridden, the system will run on every update with no entities.
func query() -> QueryBuilder:
	return q.with_all([]) # Use q.with_all([YourComponent])


## Runs once after the system has been added to the [World] to setup anything on the system one time[br]
# func setup():
# 	pass


## Override this method to define any sub-systems that should be processed by this system.[br]
# func sub_systems() -> Array[Array]:
# 	return [
# 		[q.with_all([YourComponent]), process_subsystem]
# 	]
#
# func process_subsystem(entities: Array[Entity], components: Array, delta: float):
# 	pass


## The main processing function for the system.[br]
## Override this method to define your system's behavior.[br]
## [param entities] Array of entities matching the system's query[br]
## [param components] Array of component arrays (in order from iterate()), or empty if no iterate() call[br]
## [param delta] The time elapsed since the last frame[br][br]
## [b]Simple approach:[/b] Loop through entities and use get_component()[br]
## [b]Fast approach:[/b] Use iterate() in query and access component arrays directly
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	# Per-entity processing (simple)
	for entity in entities:
		pass # Your code here...

	# OR batch processing (fast) - requires query().iterate([Components])
	# var your_components = components[0]
	# for i in entities.size():
	# 	# Process entities[i] with your_components[i]