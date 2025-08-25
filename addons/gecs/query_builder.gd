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
# Components queries that an entity must match
var _all_components_queries: Array = []
# Components queries that an entity must match for any components
var _any_components_queries: Array = []
# Groups that an entity must be in
var _groups: Array = []
# Groups that an entity must not be in
var _exclude_groups: Array = []

# Add fields for query result caching
var _cache_valid: bool = false
var _cached_result: Array = []


## Initializes the QueryBuilder with the specified [param world]
func _init(world: World):
	_world = world as World


## Clears the query criteria, resetting all filters. Mostly used in testing
## [param returns] -  The current instance of the QueryBuilder for chaining.
func clear():
	_all_components = []
	_any_components = []
	_exclude_components = []
	_relationships = []
	_exclude_relationships = []
	_all_components_queries = []
	_any_components_queries = []
	_groups = []
	_exclude_groups = []
	_cache_valid = false
	return self


## Helper to process components list that might contain queries
func _process_component_list(components: Array) -> Dictionary:
	var result := {"components": [], "queries": []}

	for component in components:
		if component is Dictionary:
			# Handle component query case
			for component_type in component:
				result.components.append(component_type)
				result.queries.append(component[component_type])
		else:
			# Handle regular component case
			result.components.append(component)
			result.queries.append({}) # Empty query for regular components

	return result


## Finds entities with all of the provided components.[br]
## [param components] An [Array] of [Component] classes.[br]
## [param returns]: [QueryBuilder] instance for chaining.
func with_all(components: Array = []) -> QueryBuilder:
	var processed = _process_component_list(components)
	_all_components = processed.components
	_all_components_queries = processed.queries
	_cache_valid = false
	return self


## Entities must have at least one of the provided components.[br]
## [param components] An [Array] of [Component] classes.[br]
## [param reutrns] [QueryBuilder] instance for chaining.
func with_any(components: Array = []) -> QueryBuilder:
	var processed = _process_component_list(components)
	_any_components = processed.components
	_any_components_queries = processed.queries
	_cache_valid = false
	return self


## Entities must not have any of the provided components.[br]
## Params: [param components] An [Array] of [Component] classes.[br]
## [param reutrns] [QueryBuilder] instance for chaining.
func with_none(components: Array = []) -> QueryBuilder:
	# Don't process queries for with_none, just take the components directly
	_exclude_components = components.map(
		func(comp): return comp if not comp is Dictionary else comp.keys()[0]
	)
	_cache_valid = false
	return self


## Finds entities with specific relationships.
func with_relationship(relationships: Array = []) -> QueryBuilder:
	_relationships = relationships
	_cache_valid = false
	return self


## Entities must not have any of the provided relationships.
func without_relationship(relationships: Array = []) -> QueryBuilder:
	_exclude_relationships = relationships
	_cache_valid = false
	return self


## Query for entities that are targets of specific relationships
func with_reverse_relationship(relationships: Array = []) -> QueryBuilder:
	for rel in relationships:
		if rel.relation != null:
			var rev_key = "reverse_" + rel.relation.get_script().resource_path
			if _world.reverse_relationship_index.has(rev_key):
				return self.with_all(_world.reverse_relationship_index[rev_key])
	_cache_valid = false
	return self


## Finds entities with specific groups.
func with_group(groups: Array[String] = []) -> QueryBuilder:
	_groups.append_array(groups)
	_cache_valid = false
	return self


## Entities must not have any of the provided groups.
func without_group(groups: Array[String] = []) -> QueryBuilder:
	_exclude_groups.append_array(groups)
	_cache_valid = false
	return self


func execute_one() -> Entity:
	# Execute the query and return the first matching entity
	var result = execute()
	if result.size() > 0:
		return result[0]
	return null


## Executes the constructed query and retrieves matching entities.[br]
## [param returns] -  An [Array] of [Entity] that match the query criteria.
func execute() -> Array:
	var result
	if _cache_valid:
		result = _cached_result
	else:
		result = _internal_execute()
		_cached_result = result
		_cache_valid = true

	# Apply component queries on the cached result
	if not _all_components_queries.is_empty():
		result = _filter_entities_by_queries(result, _all_components, _all_components_queries, true)
	if not _any_components_queries.is_empty():
		result = _filter_entities_by_queries(
			result, _any_components, _any_components_queries, false
		)

	return result


func _internal_execute() -> Array:
	# If we have groups or exclude groups, gather entities from those groups
	if not _groups.is_empty() or not _exclude_groups.is_empty():
		var entities_in_group = []
		# Find entities in group from the world
		if not _groups.is_empty():
			entities_in_group = _world.entities.filter(
				func(e):
					for g in _groups:
						if e.is_in_group(g):
							return true
					return false
			)
		# Filter out entities in excluded groups
		if not _exclude_groups.is_empty():
			entities_in_group = entities_in_group.filter(
				func(e):
					if not e:
						return false
					for g in _exclude_groups:
						if e.is_in_group(g):
							return false
					return true
			)
		# match the entities in the group with the query
		return matches(entities_in_group)

	# Otherwise, query the world
	var result = (
		_world._query(_all_components, _any_components, _exclude_components) as Array[Entity]
	)

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

	# Return the structural query result (caching handled in execute())
	return result


## Filter entities based on component queries
func _filter_entities_by_queries(
	entities: Array, components: Array, queries: Array, require_all: bool
) -> Array:
	var filtered = []
	for entity in entities:
		if require_all:
			# Must match all queries
			var matches = true
			for i in range(components.size()):
				var component = entity.get_component(components[i])
				var query = queries[i]
				if not _matches_component_query(component, query):
					matches = false
					break
			if matches:
				filtered.append(entity)
		else:
			# Must match any query
			for i in range(components.size()):
				var component = entity.get_component(components[i])
				var query = queries[i]
				if component and _matches_component_query(component, query):
					filtered.append(entity)
					break
	return filtered


## Check if entity matches any of the queries
func _entity_matches_any_query(entity: Entity, components: Array, queries: Array) -> bool:
	for i in range(components.size()):
		var component = entity.get_component(components[i])
		if component and _matches_component_query(component, queries[i]):
			return true
	return false


## Helper method to check if a component's properties match a query
func _matches_component_query(component: Component, query: Dictionary) -> bool:
	if query.is_empty():
		return true

	for property in query:
		if not component.get(property):
			return false

		var property_value = component.get(property)
		var property_query = query[property]

		for operator in property_query:
			match operator:
				"func":
					if not property_query[operator].call(property_value):
						return false
				"_eq":
					if property_value != property_query[operator]:
						return false
				"_gt":
					if property_value <= property_query[operator]:
						return false
				"_lt":
					if property_value >= property_query[operator]:
						return false
				"_gte":
					if property_value < property_query[operator]:
						return false
				"_lte":
					if property_value > property_query[operator]:
						return false
				"_ne":
					if property_value == property_query[operator]:
						return false
				"_nin":
					if property_value in property_query[operator]:
						return false
				"_in":
					if not (property_value in property_query[operator]):
						return false

	return true


## Filters a provided list of entities using the current query criteria.[br]
## Unlike execute(), this doesn't query the world but instead filters the provided entities.[br][br]
## [param entities] Array of entities to filter[br]
## [param returns] Array of entities that match the query criteria[br]
func matches(entities: Array) -> Array:
	# if the query is empty all entities match
	if is_empty():
		return entities
	var result = []

	for entity in entities:
		assert(entity is Entity, "Must be an entity")
		var matches = true

		# Check all required components
		for component in _all_components:
			if not entity.has_component(component):
				matches = false
				break

		# If still matching and we have any_components, check those
		if matches and not _any_components.is_empty():
			matches = false
			for component in _any_components:
				if entity.has_component(component):
					matches = true
					break

		# Check excluded components
		if matches:
			for component in _exclude_components:
				if entity.has_component(component):
					matches = false
					break

		# Check required relationships
		if matches and not _relationships.is_empty():
			for relationship in _relationships:
				if not entity.has_relationship(relationship):
					matches = false
					break

		# Check excluded relationships
		if matches and not _exclude_relationships.is_empty():
			for relationship in _exclude_relationships:
				if entity.has_relationship(relationship):
					matches = false
					break

		if matches:
			result.append(entity)

	return result


func combine(other: QueryBuilder) -> QueryBuilder:
	_all_components += other._all_components
	_all_components_queries += other._all_components_queries
	_any_components += other._any_components
	_any_components_queries += other._any_components_queries
	_exclude_components += other._exclude_components
	# If you have exclude component queries, include them as well
	# _exclude_components_queries += other._exclude_components_queries
	_relationships += other._relationships
	_exclude_relationships += other._exclude_relationships
	_groups += other._groups
	_exclude_groups += other._exclude_groups
	_cache_valid = false
	return self


func as_array() -> Array:
	return [
		_all_components,
		_any_components,
		_exclude_components,
		_relationships,
		_exclude_relationships
	]


func is_empty() -> bool:
	return (
		_all_components.is_empty()
		and _any_components.is_empty()
		and _exclude_components.is_empty()
		and _relationships.is_empty()
		and _exclude_relationships.is_empty()
	)


func compile(query: String) -> QueryBuilder:
	return QueryBuilder.new(_world)


func invalidate_cache():
	_cache_valid = false
