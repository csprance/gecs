## ECS ([Entity] [Component] [System]) Singleton[br]
## The ECS class acts as the central manager for the entire ECS framework
##
## The [_ECS] class maintains the current active [World] and provides access to [QueryBuilder] for fetching [Entity]s based on their [Component]s.
##[br]
## This singleton allows any part of the game to interact with the ECS system seamlessly.
## [codeblock]
##     var entities = ECS.buildQuery().with_all([Transform, Velocity]).execute()
##     for entity in entities:
##         entity.get_component(Transform).position += entity.get_component(Velocity).direction * delta
## [/codeblock]
class_name _ECS
extends Node

## The Current active [World] Instance
##
## Holds a reference to the currently active world, allowing access to all [Entity]s and [System]s within it.
var world: World:
	get:
		return world
	set(value):
		world = value

## Builds a new QueryBuilder instance for constructing and executing queries.[br]
## [param returns] - A new instance of [QueryBuilder] initialized with the current world.
func buildQuery() -> QueryBuilder:
	return QueryBuilder.new(world)
