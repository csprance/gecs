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
		world = value

## This is called to process the current active [World] instance and the [System]s within it.
## You would call this in _process or _physics_process to update the [_ECS] system.
func process(delta: float) -> void:
	world.process(delta)
