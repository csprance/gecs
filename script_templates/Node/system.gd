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
	return q


## Runs once after the system has been added to the [World] to setup anything on the system one time[br]
# func setup():
# 	pass


## Override this method to define any sub-systems that should be processed by this system.[br]
# func sub_systems() -> Array[Array]:
# 	_has_subsystems = false # If this method is not overridden then we are not using sub systems
# 	return []


## The main processing function for the system.[br]
## This method can be overridden by subclasses to define the system's behavior if using query().[br]
## If using [method System.sub_systems] then this method will not be called.[br]
## [param entity] The [Entity] being processed.[br]
## [param delta] The time elapsed since the last frame.
func process(entity: Entity, delta: float) -> void:
	pass # Code here...


## Often you want to process all entities that match the system's query, this method does that.[br]
## This way instead of running one function for each entity you can run one function for all entities.[br]
## By default this method will run the [method System.process] method for each entity.[br]
## but you can override this method to do something different.[br]
## [param entities] The [Entity]s to process.[br]
## [param delta] The time elapsed since the last frame.
# func process_all(entities: Array, delta: float) -> void:
# 	pass