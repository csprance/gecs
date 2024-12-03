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

## The Current active [World] Instance[br]
## Holds a reference to the currently active [World], allowing access to the [member World.query] instance and any [Entity]s and [System]s within it.
var world: World:
	get:
		return world
	set(value):
		# bring about the end of times for this world
		if world:
			world.disconnect("tree_exited", _on_world_exited)
		world = value
		if world:
			world.connect("tree_exited", _on_world_exited)
			_show_debug()

func _on_world_exited() -> void:
	world = null

## Are we in debug mode?
var debug := false

## This is called to process the current active [World] instance and the [System]s within it.
## You would call this in _process or _physics_process to update the [_ECS] system.[br]
## If you provide a group name it will run just that group otherwise it runs all groups[br]
## Example:
## 	[codeblock]ECS.world.process(world, 'my-system-group')[/codeblock]
func process(delta: float, group: String = '') -> void:
	world.process(delta, group)

## Called after the world is set to show the debug menu that has all entities and components if ECS.debug === True
func _show_debug():
	if ECS.debug:
		var debug_window_scene = preload('res://addons/gecs/ecs_debug.tscn').instantiate()
		debug_window_scene.name = "DebugWindow"
		add_child(debug_window_scene)
		debug_window_scene.create_debug_window()

## A Wildcard for use in relatonship queries. Indicates can be any value for a relation 
## or a target in a Relationship Pair
var wildcard = null

## Get all components of a specific type from a list of entities
func get_components(entities, component_type):
	var components = []
	for entity in entities:
		var component = entity.components.get(component_type.resource_path, null)
		if not component:
			assert(component, "Entity does not have component: " + str(component_type))
		components.append(component)
		
	return components