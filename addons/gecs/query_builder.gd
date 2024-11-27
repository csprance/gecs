## QueryBuilder[br]
## A utility class for constructing and executing queries to retrieve entities based on their components.
##
## The QueryBuilder supports filtering entities that have all, any, or exclude specific components.
## [codeblock]
##     var entities = ECS.world.query
##                    	.with_all([Transform, Velocity])
##                    	.with_any([Health])
##                    	.with_none([Inactive])
##                    	.execute()
##[/codeblock]
## This will retrieve all entities that have both `Transform` and `Velocity` components,
## have at least one of the `Health` component,
## and do not have the `Inactive` component.
class_name QueryBuilder
extends RefCounted

# The world instance to query against.
var _world: World
# Components that an entity must have all of.
var _all_components: Array = []
# Components that an entity must have at least one of.
var _any_components: Array = []
# Components that an entity must not have.
var _exclude_components: Array = []
# Relationships that entities must have
var _relationships: Array = []
# Relationships that entities must not have
var _exclude_relationships: Array = []

## Initializes the QueryBuilder with the specified [param world]
func _init(world: World):
	_world = world as World

func clear():
	_all_components = []
	_any_components = []
	_exclude_components = []
	_relationships = []
	_exclude_relationships = []
	return self

## Finds entities with all of the provided components.[br]
## [param components] An [Array] of [Component] classes.[br]
## [param returns]: [QueryBuilder] instance for chaining.
func with_all(components: Array = []) -> QueryBuilder:
	_all_components = components
	return self

## Entities must have at least one of the provided components.[br]
## [param components] An [Array] of [Component] classes.[br]
## [param reutrns] [QueryBuilder] instance for chaining.
func with_any(components: Array = []) -> QueryBuilder:
	_any_components = components
	return self

## Entities must not have any of the provided components.[br]
## Params: [param components] An [Array] of [Component] classes.[br]
## [param reutrns] [QueryBuilder] instance for chaining.
func with_none(components: Array = []) -> QueryBuilder:
	_exclude_components = components
	return self

## Finds entities with specific relationships.
func with_relationship(relationships: Array = []) -> QueryBuilder:
	_relationships = relationships
	return self

## Entities must not have any of the provided relationships.
func without_relationship(relationships: Array = []) -> QueryBuilder:
	_exclude_relationships = relationships
	return self

## Executes the constructed query and retrieves matching entities.[br]
## [param returns] -  An [Array] of [Entity] that match the query criteria.
func execute() -> Array:
	var result = _world._query(_all_components, _any_components, _exclude_components) as Array[Entity]
	# Handle relationship filtering
	if not _relationships.is_empty() or not _exclude_relationships.is_empty():
		var filtered_entities: Array = []
		for entity in result:
			var matches = true
			# Required relationships
			for relationship in _relationships:
				if not entity.has_relationship(relationship):
					matches = false
					break
			# Excluded relationships
			if matches:
				for ex_relationship in _exclude_relationships:
					if entity.has_relationship(ex_relationship):
						matches = false
						break
			if matches:
				filtered_entities.append(entity)
		result = filtered_entities
	clear()
	return result

func combine(other: QueryBuilder) -> QueryBuilder:
	_all_components += other._all_components
	_any_components += other._any_components
	_exclude_components += other._exclude_components
	return self

func as_array() -> Array:
	return [_all_components, _any_components, _exclude_components]
