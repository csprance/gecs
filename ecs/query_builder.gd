## QueryBuilder[br]
## A utility class for constructing and executing queries to retrieve entities based on their components.
##
## The QueryBuilder supports filtering entities that have all, any, or exclude specific components,
## as well as filtering by enabled/disabled status using high-performance group indexing.
## [codeblock]
##     var enabled_entities = ECS.world.query
##                    	.with_all([Transform, Velocity])
##                    	.with_any([Health])
##                    	.with_none([Inactive])
##                    	.enabled(true)
##                    	.execute()
##     
##     var disabled_entities = ECS.world.query.enabled(false).execute()
##     var all_entities = ECS.world.query.enabled(null).execute()
##[/codeblock]
## This will efficiently query entities using indexed group lookups rather than
## filtering the entire entity list.
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
# Enabled/disabled filter: true = enabled only, false = disabled only, null = all
var _enabled_filter = null

# Add fields for query result caching
var _cache_valid: bool = false
var _cached_result: Array = []


## Initializes the QueryBuilder with the specified [param world]
func _init(world: World = null):
	_world = world as World


## Allow setting the world after creation for editor time creation
func set_world(world: World):
	_world = world


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
	_enabled_filter = null
	_cache_valid = false
	return self


## Finds entities with all of the provided components.[br]
## [param components] An [Array] of [Component] classes.[br]
## [param returns]: [QueryBuilder] instance for chaining.
func with_all(components: Array = []) -> QueryBuilder:
	var processed = ComponentQueryMatcher.process_component_list(components)
	_all_components = processed.components
	_all_components_queries = processed.queries
	_cache_valid = false
	return self


## Entities must have at least one of the provided components.[br]
## [param components] An [Array] of [Component] classes.[br]
## [param reutrns] [QueryBuilder] instance for chaining.
func with_any(components: Array = []) -> QueryBuilder:
	var processed = ComponentQueryMatcher.process_component_list(components)
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


## Finds entities with specific relationships using weak matching by default (component type and queries).
## [br][b]Weak Matching (default):[/b] Components match by type and component queries are evaluated.
## [br]For strong matching (exact component data), use [method Entity.has_relationship] with [code]weak=false[/code].
func with_relationship(relationships: Array = []) -> QueryBuilder:
	_relationships = relationships
	_cache_valid = false
	return self


## Entities must not have any of the provided relationships using weak matching by default (component type and queries).
## [br][b]Weak Matching (default):[/b] Components match by type and component queries are evaluated.
## [br]For strong matching (exact component data), use [method Entity.has_relationship] with [code]weak=false[/code].
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


## Filter to only enabled entities using internal arrays for optimal performance.[br]
## [param returns] [QueryBuilder] instance for chaining.
func enabled() -> QueryBuilder:
	_enabled_filter = true
	_cache_valid = false
	return self

## Filter to only disabled entities using internal arrays for optimal performance.[br]
## [param returns] [QueryBuilder] instance for chaining.
func disabled() -> QueryBuilder:
	_enabled_filter = false
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
	# Only filter if there are actual property queries (not just empty {} placeholders)
	if not _all_components_queries.is_empty() and _has_actual_queries(_all_components_queries):
		result = _filter_entities_by_queries(result, _all_components, _all_components_queries, true)
	if not _any_components_queries.is_empty() and _has_actual_queries(_any_components_queries):
		result = _filter_entities_by_queries(
			result, _any_components, _any_components_queries, false
		)

	return result


func _internal_execute() -> Array:
	# If we have groups or exclude groups, gather entities from those groups
	if not _groups.is_empty() or not _exclude_groups.is_empty():
		var entities_in_group = []

		# Use Godot's optimized get_nodes_in_group() instead of filtering
		if not _groups.is_empty():
			# For multiple groups, use set operations for efficiency
			var group_set: Set

			for i in range(_groups.size()):
				var group_name = _groups[i]
				var nodes_in_group = _world.get_tree().get_nodes_in_group(group_name)

				# Filter to only Entity nodes
				var entities_in_this_group = nodes_in_group.filter(func(n): return n is Entity)

				if i == 0:
					# First group - start with these entities
					group_set = Set.new(entities_in_this_group)
				else:
					# Subsequent groups - intersect (entity must be in ALL groups)
					group_set = group_set.intersect(Set.new(entities_in_this_group))

			entities_in_group = group_set.to_array() if group_set else []

		# Filter out entities in excluded groups
		if not _exclude_groups.is_empty():
			var exclude_set = Set.new()
			for group_name in _exclude_groups:
				var nodes_in_group = _world.get_tree().get_nodes_in_group(group_name)
				var entities_in_excluded = nodes_in_group.filter(func(n): return n is Entity)
				exclude_set = exclude_set.union(Set.new(entities_in_excluded))

			# Remove excluded entities
			var result_set = Set.new(entities_in_group)
			entities_in_group = result_set.difference(exclude_set).to_array()

		# match the entities in the group with the query
		return matches(entities_in_group)

	# Otherwise, query the world with enabled filter for optimal performance
	var result = (
		_world._query(_all_components, _any_components, _exclude_components, _enabled_filter) as Array[Entity]
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
	# Note: enabled/disabled filtering is now handled in World._query for optimal performance
	return result


## Check if any query in the array has actual property filters (not just empty {})
func _has_actual_queries(queries: Array) -> bool:
	for query in queries:
		if not query.is_empty():
			return true
	return false


## Filter entities based on component queries
func _filter_entities_by_queries(
	entities: Array, components: Array, queries: Array, require_all: bool
) -> Array:
	var filtered = []
	for entity in entities:
		if entity == null:
			continue
		if require_all:
			# Must match all queries
			var matches = true
			for i in range(components.size()):
				var component = entity.get_component(components[i])
				var query = queries[i]
				if not ComponentQueryMatcher.matches_query(component, query):
					matches = false
					break
			if matches:
				filtered.append(entity)
		else:
			# Must match any query
			for i in range(components.size()):
				var component = entity.get_component(components[i])
				var query = queries[i]
				if component and ComponentQueryMatcher.matches_query(component, query):
					filtered.append(entity)
					break
	return filtered


## Check if entity matches any of the queries
func _entity_matches_any_query(entity: Entity, components: Array, queries: Array) -> bool:
	for i in range(components.size()):
		var component = entity.get_component(components[i])
		if component and ComponentQueryMatcher.matches_query(component, queries[i]):
			return true
	return false


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
		# If it's null skip it
		if entity == null:
			continue
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


func _to_string() -> String:
	var parts = []
	
	if not _all_components.is_empty():
		parts.append("with_all(" + _format_components(_all_components) + ")")
	
	if not _any_components.is_empty():
		parts.append("with_any(" + _format_components(_any_components) + ")")
	
	if not _exclude_components.is_empty():
		parts.append("with_none(" + _format_components(_exclude_components) + ")")
	
	if not _relationships.is_empty():
		parts.append("with_relationship(" + _format_relationships(_relationships) + ")")
	
	if not _exclude_relationships.is_empty():
		parts.append("without_relationship(" + _format_relationships(_exclude_relationships) + ")")
	
	if not _groups.is_empty():
		parts.append("with_group(" + str(_groups) + ")")
	
	if not _exclude_groups.is_empty():
		parts.append("without_group(" + str(_exclude_groups) + ")")
	
	if _enabled_filter != null:
		if _enabled_filter:
			parts.append("enabled()")
		else:
			parts.append("disabled()")
	
	if not _all_components_queries.is_empty():
		parts.append("component_queries(" + _format_component_queries(_all_components_queries) + ")")
	
	if not _any_components_queries.is_empty():
		parts.append("any_component_queries(" + _format_component_queries(_any_components_queries) + ")")
	
	if parts.is_empty():
		return "ECS.world.query"
	
	return "ECS.world.query." + ".".join(parts)


func _format_components(components: Array) -> String:
	var names = []
	for component in components:
		if component is Script:
			names.append(component.get_global_name())
		else:
			names.append(str(component))
	return "[" + ", ".join(names) + "]"


func _format_relationships(relationships: Array) -> String:
	var names = []
	for relationship in relationships:
		if relationship.has_method("to_string"):
			names.append(relationship.to_string())
		else:
			names.append(str(relationship))
	return "[" + ", ".join(names) + "]"


func _format_component_queries(queries: Array) -> String:
	var formatted = []
	for query in queries:
		if query.has_method("to_string"):
			formatted.append(query.to_string())
		else:
			formatted.append(str(query))
	return "[" + ", ".join(formatted) + "]"


func compile(query: String) -> QueryBuilder:
	return QueryBuilder.new(_world)


func invalidate_cache():
	_cache_valid = false
