## QueryBuilder
##
## A utility class for constructing and executing queries to retrieve entities based on their components.
## It supports filtering entities that have all, any, or exclude specific components.
##
## Example:
##     var query = QueryBuilder.new(world)
##     var entities = query.all([Transform, Velocity]).any([Health]).exclude([Inactive]).execute()
##
## This will retrieve all entities that have both `Transform` and `Velocity` components,
## have at least one of the `Health` component,
## and do not have the `Inactive` component.
class_name QueryBuilder
extends Object

## The world instance to query against.
var world: World
## Components that an entity must have all of.
var all_components: Array = []
## Components that an entity must have at least one of.
var any_components: Array = []
## Components that an entity must not have.
var exclude_components: Array = []

## Initializes the QueryBuilder with the specified world.
##
## @param world The world instance to query.
func _init(world: World):
	self.world = world

## Specifies that entities must have all of the provided components.
##
## @param components An array of component classes.
## @return QueryBuilder Returns the QueryBuilder instance for chaining.
func all(components: Array) -> QueryBuilder:
	all_components += components
	return self

## Specifies that entities must have at least one of the provided components.
##
## @param components An array of component classes.
## @return QueryBuilder Returns the QueryBuilder instance for chaining.
func any(components: Array) -> QueryBuilder:
	any_components += components
	return self

## Specifies that entities must not have any of the provided components.
##
## @param components An array of component classes.
## @return QueryBuilder Returns the QueryBuilder instance for chaining.
func exclude(components: Array) -> QueryBuilder:
	exclude_components += components
	return self

## Executes the constructed query and retrieves matching entities.
##
## @return Array An array of entities that match the query criteria.
func execute() -> Array:
	return world.query(all_components, any_components, exclude_components)
