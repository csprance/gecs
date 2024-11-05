## ECS (Entity Component System) Singleton
##
## The ECS class acts as the central manager for the entire ECS framework.
## It maintains the current active world and provides access to query builders for fetching entities based on their components.
##
## This singleton allows any part of the game to interact with the ECS system seamlessly.
##
## Example:
##     var query = ECS.buildQuery().all([Transform, Velocity]).execute()
##     for entity in query:
##         entity.get_component(Transform).position += entity.get_component(Velocity).direction * delta
extends Node

## The Current active World Instance
##
## Holds a reference to the currently active world, allowing access to all entities and systems within it.
var world: World:
	get:
		return world
	set(value):
		world = value

## Builds a new QueryBuilder instance for constructing and executing queries.
##
## @return QueryBuilder A new instance of QueryBuilder initialized with the current world.
func buildQuery() -> QueryBuilder:
	return QueryBuilder.new(world)
