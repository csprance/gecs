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
var _exclude_relationships: Array = []
# Structural relationship classification (populated by with_relationship/without_relationship)
var _structural_rel_keys: Array = []  # Exact rel:// slot keys for archetype matching
var _wildcard_rel_types: Array = []  # Relation paths for wildcard index lookup
var _post_filter_relationships: Array = []  # Property-query and script-target rels (entity-level)
var _structural_ex_rel_keys: Array = []
var _wildcard_ex_rel_types: Array = []
var _post_filter_ex_relationships: Array = []
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
# Components to iterate in archetype mode (ordered array of component types)
var _iterate_components: Array = []

# ------------------------------------------------------------------------------
# Observer event declarations (FLECS-style). A query with any of these set is an
# Observer spec; a query with none of them set is a plain System filter. The
# mask uses Observer.Event bit flags.
# ------------------------------------------------------------------------------
# Bitmask of Observer.Event flags this query reacts to.
var _observer_events_mask: int = 0
# Optional property filter for Observer.Event.CHANGED. Empty = all properties fire.
var _observer_changed_props: Array[StringName] = []
# Optional relation-type filter for RELATIONSHIP_ADDED (scripts). Empty = any relation type.
var _observer_rel_add_types: Array = []
# Optional relation-type filter for RELATIONSHIP_REMOVED (scripts). Empty = any relation type.
var _observer_rel_remove_types: Array = []
# Custom event names this query listens for (StringName).
var _observer_event_names: Array[StringName] = []

# Add fields for query result caching
var _cache_valid: bool = false
var _cached_result: Array = []
# World cache_version when _cached_result was stored — detects stale cache without signal reliance
var _cached_world_version: int = -1

# OPTIMIZATION: Cache the query hash key to avoid recalculating FNV-1a hash every frame
var _cache_key: int = -1
var _cache_key_valid: bool = false


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
	_structural_rel_keys = []
	_wildcard_rel_types = []
	_post_filter_relationships = []
	_structural_ex_rel_keys = []
	_wildcard_ex_rel_types = []
	_post_filter_ex_relationships = []
	_all_components_queries = []
	_any_components_queries = []
	_groups = []
	_exclude_groups = []
	_enabled_filter = null
	_iterate_components = []
	_observer_events_mask = 0
	_observer_changed_props = []
	_observer_rel_add_types = []
	_observer_rel_remove_types = []
	_observer_event_names = []
	_cache_valid = false
	_cache_key_valid = false
	return self


## Finds entities with all of the provided components.[br]
## [param components] An [Array] of [Component] classes.[br]
## [param returns]: [QueryBuilder] instance for chaining.
func with_all(components: Array = []) -> QueryBuilder:
	var processed = ComponentQueryMatcher.process_component_list(components)
	_all_components = processed.components
	_all_components_queries = processed.queries
	_cache_valid = false
	_cache_key_valid = false
	return self


## Entities must have at least one of the provided components.[br]
## [param components] An [Array] of [Component] classes.[br]
## [param reutrns] [QueryBuilder] instance for chaining.
func with_any(components: Array = []) -> QueryBuilder:
	var processed = ComponentQueryMatcher.process_component_list(components)
	_any_components = processed.components
	_any_components_queries = processed.queries
	_cache_valid = false
	_cache_key_valid = false
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
	_cache_key_valid = false
	return self


## Finds entities with specific relationships using weak matching by default (component type and queries).
## [br][b]Weak Matching (default):[/b] Components match by type and component queries are evaluated.
## [br]For strong matching (exact component data), use [method Entity.has_relationship] with [code]weak=false[/code].
func with_relationship(relationships: Array = []) -> QueryBuilder:
	_relationships = relationships
	_cache_valid = false
	_cache_key_valid = false
	# Classify each relationship into structural vs post-filter.
	# Exact entity/component targets keep structural matching but include compatible
	# script/wildcard slot keys so legacy weak-match semantics still hold.
	_structural_rel_keys = []
	_wildcard_rel_types = []
	_post_filter_relationships = []
	for rel in relationships:
		var rel_path = _world._get_relationship_relation_path(rel) if _world else ""
		if rel._is_query_relationship or rel_path == "":
			# Property queries can't be structural
			_post_filter_relationships.append(rel)
		elif rel.target is Script:
			# Script target: use wildcard index to narrow, then post-filter for script match
			if not _wildcard_rel_types.has(rel_path):
				_wildcard_rel_types.append(rel_path)
			_post_filter_relationships.append(rel)
		elif rel.target == null:
			# Pure wildcard: use wildcard index only
			if not _wildcard_rel_types.has(rel_path):
				_wildcard_rel_types.append(rel_path)
		else:
			# Entity/Component target: match exact target plus compatible
			# archetype/wildcard slots without needing an entity post-filter.
			if _world:
				if not _wildcard_rel_types.has(rel_path):
					_wildcard_rel_types.append(rel_path)
				var compatible_keys = _world._get_compatible_relationship_slot_keys(rel)
				if compatible_keys.size() == 1:
					_structural_rel_keys.append(compatible_keys[0])
				elif not compatible_keys.is_empty():
					_structural_rel_keys.append(compatible_keys)
	return self


## Entities must not have any of the provided relationships using weak matching by default (component type and queries).
## [br][b]Weak Matching (default):[/b] Components match by type and component queries are evaluated.
## [br]For strong matching (exact component data), use [method Entity.has_relationship] with [code]weak=false[/code].
func without_relationship(relationships: Array = []) -> QueryBuilder:
	_exclude_relationships = relationships
	_cache_valid = false
	_cache_key_valid = false
	# Classify each exclude relationship into structural vs post-filter.
	_structural_ex_rel_keys = []
	_wildcard_ex_rel_types = []
	_post_filter_ex_relationships = []
	for rel in relationships:
		var rel_path = _world._get_relationship_relation_path(rel) if _world else ""
		if rel._is_query_relationship or rel_path == "":
			_post_filter_ex_relationships.append(rel)
		elif rel.target is Script:
			# Script target: can't exclude structurally, use post-filter
			_post_filter_ex_relationships.append(rel)
		elif rel.target == null:
			# Wildcard exclusion: exclude all archetypes with that relation type
			if not _wildcard_ex_rel_types.has(rel_path):
				_wildcard_ex_rel_types.append(rel_path)
		else:
			# Entity/Component target exclusion: use structural slot keys only.
			# Do NOT add to _wildcard_ex_rel_types — that would exclude ALL
			# archetypes with the relation type, not just the specific target.
			if _world:
				var compatible_keys = _world._get_compatible_relationship_slot_keys(rel)
				if compatible_keys.size() == 1:
					_structural_ex_rel_keys.append(compatible_keys[0])
				elif not compatible_keys.is_empty():
					_structural_ex_rel_keys.append(compatible_keys)
	return self


## Finds entities with specific groups.
func with_group(groups: Array[String] = []) -> QueryBuilder:
	_groups.append_array(groups)
	_cache_valid = false
	_cache_key_valid = false
	return self


## Entities must not have any of the provided groups.
func without_group(groups: Array[String] = []) -> QueryBuilder:
	_exclude_groups.append_array(groups)
	_cache_valid = false
	_cache_key_valid = false
	return self


## Filter to only enabled entities using internal arrays for optimal performance.[br]
## [param returns] [QueryBuilder] instance for chaining.
func enabled() -> QueryBuilder:
	_enabled_filter = true
	_cache_valid = false
	_cache_key_valid = false
	return self


## Filter to only disabled entities using internal arrays for optimal performance.[br]
## [param returns] [QueryBuilder] instance for chaining.
func disabled() -> QueryBuilder:
	_enabled_filter = false
	_cache_valid = false
	_cache_key_valid = false
	return self


## Specifies the component order for batch processing iteration.[br]
## This determines the order of component arrays passed to System.process_batch()[br]
## [param components] An array of component types in the desired iteration order[br]
## [param returns] [QueryBuilder] instance for chaining.[br][br]
## [b]Example:[/b]
## [codeblock]
## func query() -> QueryBuilder:
##     return q.with_all([C_Velocity, C_Timer]).enabled().iterate([C_Velocity, C_Timer])
##
## func process_batch(entities: Array[Entity], components: Array, delta: float) -> void:
##     var velocities = components[0] # C_Velocity (first in iterate)
##     var timers = components[1] # C_Timer (second in iterate)
## [/codeblock]
func iterate(components: Array) -> QueryBuilder:
	_iterate_components = components
	return self


#region Observer Event Declarations
## Declare this query as an [Observer] spec that fires when a component matching
## [method with_all]/[method with_any] is added to a matching entity.[br]
## [param returns] - [QueryBuilder] for chaining.
func on_added() -> QueryBuilder:
	_observer_events_mask |= (1 << Observer.Event.ADDED)
	return self


## Declare this query fires when a component matching [method with_all]/[method with_any]
## is removed from a matching entity.[br]
## [param returns] - [QueryBuilder] for chaining.
func on_removed() -> QueryBuilder:
	_observer_events_mask |= (1 << Observer.Event.REMOVED)
	return self


## Declare this query fires when a property on a matching component changes.[br]
## [param properties] Optional list of property names to filter by (empty = all properties).[br]
## Chaining [code].on_changed([&"a"]).on_changed([&"b"])[/code] accumulates filters
## (append-and-dedup) rather than replacing — matches [method on_event] semantics.[br]
## [param returns] - [QueryBuilder] for chaining.
func on_changed(properties: Array[StringName] = []) -> QueryBuilder:
	_observer_events_mask |= (1 << Observer.Event.CHANGED)
	for p in properties:
		if not _observer_changed_props.has(p):
			_observer_changed_props.append(p)
	return self


## Declare this query as a monitor: fire when an entity NEWLY matches the full query.[br]
## [param returns] - [QueryBuilder] for chaining.
func on_match() -> QueryBuilder:
	_observer_events_mask |= (1 << Observer.Event.MATCH)
	return self


## Declare this query as a monitor: fire when an entity STOPS matching the full query.[br]
## [param returns] - [QueryBuilder] for chaining.
func on_unmatch() -> QueryBuilder:
	_observer_events_mask |= (1 << Observer.Event.UNMATCH)
	return self


## Declare this query fires when a relationship is added to a matching entity.[br]
## [param relation_types] Optional list of relation [Component] script types to filter by (empty = any).[br]
## Chained calls accumulate filter types (append-and-dedup) rather than replacing.[br]
## [param returns] - [QueryBuilder] for chaining.
func on_relationship_added(relation_types: Array = []) -> QueryBuilder:
	_observer_events_mask |= (1 << Observer.Event.RELATIONSHIP_ADDED)
	for t in relation_types:
		if not _observer_rel_add_types.has(t):
			_observer_rel_add_types.append(t)
	return self


## Declare this query fires when a relationship is removed from a matching entity.[br]
## [param relation_types] Optional list of relation [Component] script types to filter by (empty = any).[br]
## Chained calls accumulate filter types (append-and-dedup) rather than replacing.[br]
## [param returns] - [QueryBuilder] for chaining.
func on_relationship_removed(relation_types: Array = []) -> QueryBuilder:
	_observer_events_mask |= (1 << Observer.Event.RELATIONSHIP_REMOVED)
	for t in relation_types:
		if not _observer_rel_remove_types.has(t):
			_observer_rel_remove_types.append(t)
	return self


## Declare this query reacts to a custom event emitted via [method World.emit_event].[br]
## May be chained multiple times to listen for several events on the same query.[br]
## [param event_name] The event [StringName] to subscribe to.[br]
## [param returns] - [QueryBuilder] for chaining.
func on_event(event_name: StringName) -> QueryBuilder:
	if not _observer_event_names.has(event_name):
		_observer_event_names.append(event_name)
	return self


## True if this query declares any observer events (lifecycle, monitor, relationship, or custom).
func has_observer_events() -> bool:
	return _observer_events_mask != 0 or not _observer_event_names.is_empty()


## True if this query declares the given [Observer.Event] flag.
func has_event(event: Observer.Event) -> bool:
	return (_observer_events_mask & (1 << event)) != 0


## True if this query declares the given custom event name.
func has_custom_event(event_name: StringName) -> bool:
	return _observer_event_names.has(event_name)


## Return the set of component/relationship script resource paths this query's filters
## reference. Used by the world's monitor dispatch to decide whether a structural
## mutation on an entity could affect this query's membership.
func _component_sensitivity() -> Array[String]:
	var paths: Array[String] = []
	_collect_script_paths(_all_components, paths)
	_collect_script_paths(_any_components, paths)
	_collect_script_paths(_exclude_components, paths)
	for rel in _relationships:
		var rel_path = _world._get_relationship_relation_path(rel) if _world else ""
		if rel_path != "" and not paths.has(rel_path):
			paths.append(rel_path)
	for rel in _exclude_relationships:
		var rel_path = _world._get_relationship_relation_path(rel) if _world else ""
		if rel_path != "" and not paths.has(rel_path):
			paths.append(rel_path)
	return paths


func _collect_script_paths(components: Array, out: Array[String]) -> void:
	for c in components:
		if c is Script and c.resource_path != "" and not out.has(c.resource_path):
			out.append(c.resource_path)


#endregion Observer Event Declarations


func execute_one() -> Entity:
	# Execute the query and return the first matching entity
	var result = execute()
	if result.size() > 0:
		return result[0]
	return null


## Executes the constructed query and retrieves matching entities.[br]
## [param returns] -  An [Array] of [Entity] that match the query criteria.
func execute() -> Array:
	# For relationship or group filters we need fresh filtering every call (no stale cached filtered result)
	# Only post-filter relationships and groups prevent caching
	var has_post_filter_rels := (
		not _post_filter_relationships.is_empty() or not _post_filter_ex_relationships.is_empty()
	)
	var uses_group_filters := not _groups.is_empty() or not _exclude_groups.is_empty()

	# Detect stale cache via world version counter (robust fallback for signal delivery)
	if _cache_valid and _world and _cached_world_version != _world.cache_version:
		_cache_valid = false

	var structural_result: Array
	if _cache_valid and not has_post_filter_rels and not uses_group_filters:
		# Safe to reuse full cached result only for purely structural component queries
		structural_result = _cached_result
	else:
		# Recompute base structural/group result (without relationship filtering caching)
		structural_result = _internal_execute()
		# Only cache if no dynamic relationship/group filters are present
		if not has_post_filter_rels and not uses_group_filters:
			_cached_result = structural_result
			_cache_valid = true
			_cached_world_version = _world.cache_version if _world else -1
		else:
			_cache_valid = false  # force recompute next call

	var result = structural_result
	# Apply component property queries (post structural)
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
		else:
			# If no required groups but we have exclude_groups, start with ALL entities from component query
			# This handles the case of "without_group" queries
			entities_in_group = (
				(
					_world
					._query(
						_all_components,
						_any_components,
						_exclude_components,
						_enabled_filter,
						get_cache_key(),
						_structural_rel_keys,
						_wildcard_rel_types,
						_structural_ex_rel_keys,
						_wildcard_ex_rel_types,
					)
				)
				as Array[Entity]
			)

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
	# OPTIMIZATION: Pass pre-calculated cache key to avoid rehashing
	# Pass structural relationship info to world._query() for archetype-level filtering
	var result = (
		(
			_world
			._query(
				_all_components,
				_any_components,
				_exclude_components,
				_enabled_filter,
				get_cache_key(),
				_structural_rel_keys,
				_wildcard_rel_types,
				_structural_ex_rel_keys,
				_wildcard_ex_rel_types,
			)
		)
		as Array[Entity]
	)

	# Post-filter: only property-query and script-target relationships
	if not _post_filter_relationships.is_empty() or not _post_filter_ex_relationships.is_empty():
		var filtered_entities: Array = []
		for entity in result:
			var matches = true
			for relationship in _post_filter_relationships:
				if not entity.has_relationship(relationship):
					matches = false
					break
			if matches:
				for ex_relationship in _post_filter_ex_relationships:
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
	entities: Array,
	components: Array,
	queries: Array,
	require_all: bool,
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
	_relationships += other._relationships
	_exclude_relationships += other._exclude_relationships
	_groups += other._groups
	_exclude_groups += other._exclude_groups
	_cache_valid = false
	_reclassify_relationships()
	return self


## Reclassify all relationships into structural/wildcard/post-filter buckets.
## Called after combine() merges raw _relationships/_exclude_relationships arrays.
func _reclassify_relationships() -> void:
	if not _relationships.is_empty():
		with_relationship(_relationships)
	if not _exclude_relationships.is_empty():
		without_relationship(_exclude_relationships)


func as_array() -> Array:
	return [
		_all_components,
		_any_components,
		_exclude_components,
		_relationships,
		_exclude_relationships,
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
		parts.append(
			"component_queries(" + _format_component_queries(_all_components_queries) + ")"
		)

	if not _any_components_queries.is_empty():
		parts.append(
			"any_component_queries(" + _format_component_queries(_any_components_queries) + ")"
		)

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
	_cache_key_valid = false


## Called when a relationship is added or removed (only for queries using relationships)
## Relationship changes do NOT affect structural cache key; queries only re-filter at execute time
func _on_relationship_changed(_entity: Entity, _relationship: Relationship):
	_cache_valid = false
	_cache_key_valid = false


## Get the cached query hash key, calculating it only once
## OPTIMIZATION: Avoids recalculating FNV-1a hash every frame in hot path queries
func get_cache_key() -> int:
	# Cache key includes structural relationships (exact type-match and wildcard)
	if not _cache_key_valid:
		if _world:
			# Filter to structural relationships for cache key
			var structural_rels: Array = []
			for rel in _relationships:
				if (
					not rel._is_query_relationship
					and _world._get_relationship_relation_path(rel) != ""
				):
					structural_rels.append(rel)
			var structural_ex_rels: Array = []
			for rel in _exclude_relationships:
				if (
					not rel._is_query_relationship
					and _world._get_relationship_relation_path(rel) != ""
				):
					structural_ex_rels.append(rel)
			_cache_key = (
				QueryCacheKey
				.build(
					_all_components,
					_any_components,
					_exclude_components,
					structural_rels,
					structural_ex_rels,
				)
			)
			_cache_key_valid = true
		else:
			return -1
	return _cache_key


## Get matching archetypes directly for column-based iteration
## OPTIMIZATION: Skip entity flattening, return archetypes directly for cache-friendly processing
## [br][br]
## [b]Example:[/b]
## [codeblock]
## func process_all(entities: Array, delta: float):
##     for archetype in query().archetypes():
##         var transforms = archetype.get_column(transform_path)
##         for i in range(transforms.size()):
##             # Process transform directly from packed array
## [/codeblock]
func archetypes() -> Array[Archetype]:
	return _world.get_matching_archetypes(self)
