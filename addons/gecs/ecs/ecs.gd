## ECS ([Entity] [Component] [System]) Singleton[br]
## The ECS class acts as the central manager for the entire ECS framework
##
## The [_ECS] class maintains the current active [World] and provides access to [QueryBuilder] for fetching [Entity]s based on their [Component]s.
##[br]
## This singleton allows any part of the game to interact with the ECS system seamlessly.
## [codeblock]
##     var entities = ECS.world.query.with_all([Transform, Velocity]).execute()
##     for entity in entities:
##         entity.get_component(Transform).position += entity.get_component(Velocity).direction * delta
## [/codeblock]
## This is also where you control the setup of the world and process loop of the ECS system.
##[codeblock]
##
##   func _read(delta):
##       ECS.world = world
##
##	 func _process(delta):
##	     ECS.process(delta)
##[/codeblock]
## or in the physics loop
##[codeblock]
##	 func _physics_process(delta):
##	     ECS.process(delta)
##[/codeblock]
class_name _ECS
extends Node

## Emitted when the world is changed with a ref to the new world
signal world_changed(world: World)
##  Emitted when the world is exited
signal world_exited

## The Current active [World] Instance[br]
## Holds a reference to the currently active [World], allowing access to the [member World.query] instance and any [Entity]s and [System]s within it.
var world: World:
	get:
		return world
	set(value):
		# Add the new world to the scenes
		world = value
		if world:
			if not world.is_inside_tree():
				# Add the world to the tree if it is not already
				get_tree().root.get_node("./Root").add_child(world)
			if not world.is_connected("tree_exited", _on_world_exited):
				world.connect("tree_exited", _on_world_exited)
		world_changed.emit(world)
		assert(GECSEditorDebuggerMessages.set_world(world) if debug else true, 'Debug Data')
		
			
## Are we in debug mode? Controlled by project setting gecs/debug_mode
var debug := ProjectSettings.get_setting(GecsSettings.SETTINGS_DEBUG_MODE, false)
## This is an array of functions that get called on the entities when they get added to the world (after they are ready)
var entity_preprocessors: Array[Callable] = []
## This is an array of functions that get called on the entities right before they get removed from the world
var entity_postprocessors: Array[Callable] = []
## A Wildcard for use in relatonship queries. Indicates can be any value for a relation
## or a target in a Relationship Pair ECS.wildcard
var wildcard = null


## This is called to process the current active [World] instance and the [System]s within it.
## You would call this in _process or _physics_process to update the [_ECS] system.[br]
## If you provide a group name it will run just that group otherwise it runs all groups[br]
## Example:
## 	[codeblock]ECS.world.process(world, 'my-system-group')[/codeblock]
func process(delta: float, group: String = "") -> void:
	world.process(delta, group)


## Get all components of a specific type from a list of entities[br]
## If the component does not exist on the entity it will return the default_component if provided or assert
func get_components(entities, component_type, default_component = null) -> Array:
	var components = []
	for entity in entities:
		var component = entity.components.get(component_type.resource_path, null)
		if not component and not default_component:
			assert(component, "Entity does not have component: " + str(component_type))
		if not component and default_component:
			component = default_component
		components.append(component)

	return components


## Called when the world is exited
func _on_world_exited() -> void:
	world = null
	world_exited.emit()
	assert(GECSEditorDebuggerMessages.exit_world() if debug else true, 'Debug Data')
		

func serialize(query: QueryBuilder, config: GECSSerializeConfig = null) -> GecsData:
	return GECSIO.serialize(query, config)


func save(gecs_data: GecsData, filepath: String, binary: bool = false) -> bool:
	return GECSIO.save(gecs_data, filepath, binary)


func deserialize(gecs_filepath: String) -> Array[Entity]:
	return GECSIO.deserialize(gecs_filepath)
