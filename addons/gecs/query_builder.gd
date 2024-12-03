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

## Query for entities that are targets of specific relationships
func with_reverse_relationship(relationships: Array = []) -> QueryBuilder:
	for rel in relationships:
		if rel.relation != null:
			var rev_key = "reverse_" + rel.relation.get_script().resource_path
			if _world.reverse_relationship_index.has(rev_key):
				return self.with_all(_world.reverse_relationship_index[rev_key])
	return self

## Parses a query string and configures the QueryBuilder accordingly
## Query syntax: WITH (Components) ANY (Components) NONE (Components) HAS (Relations) NOT (Relations)
## [param query_str] The query string to parse
## [param returns] QueryBuilder instance for chaining
func from_string(query_str: String) -> QueryBuilder:
	# Split into sections
	var sections = query_str.to_upper().split(" ")
	var current_section = ""
	var i = 0
	
	while i < sections.size():
		var section = sections[i].strip_edges()
		
		match section:
			"WITH":
				current_section = "WITH"
				i += 1
				if i < sections.size():
					var components = _parse_component_list(sections[i])
					with_all(components)
			"ANY":
				current_section = "ANY"
				i += 1
				if i < sections.size():
					var components = _parse_component_list(sections[i])
					with_any(components)
			"NONE":
				current_section = "NONE"
				i += 1
				if i < sections.size():
					var components = _parse_component_list(sections[i])
					with_none(components)
			"HAS":
				current_section = "HAS"
				i += 1
				if i < sections.size():
					var relationships = _parse_relationship_list(sections[i])
					with_relationship(relationships)
			"NOT":
				current_section = "NOT"
				i += 1
				if i < sections.size():
					var relationships = _parse_relationship_list(sections[i])
					without_relationship(relationships)
		i += 1
	
	return self

func _parse_component_list(component_str: String) -> Array:
	# Remove parentheses and split by comma
	component_str = component_str.trim_prefix("(").trim_suffix(")")
	var components = []
	for comp_name in component_str.split(","):
		comp_name = comp_name.strip_edges()
		# Attempt to get the component class from its name
		var component = ClassDB.instantiate(comp_name)
		if component:
			components.append(component)
	return components

func _parse_relationship_list(relation_str: String) -> Array:
	# Remove parentheses and split by comma
	relation_str = relation_str.trim_prefix("(").trim_suffix(")")
	var relationships = []
	for rel in relation_str.split(","):
		rel = rel.strip_edges()
		var parts = rel.split("->")
		if parts.size() == 2:
			var relation_type = parts[0].strip_edges()
			var target = parts[1].strip_edges()
			
			var relation_component = ClassDB.instantiate(relation_type)
			var target_entity = target if target == "*" else ClassDB.instantiate(target)
			
			if relation_component:
				relationships.append(Relationship.new(relation_component.new(), target_entity if target != "*" else ECS.wildcard))
	
	return relationships

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

## Filters a provided list of entities using the current query criteria.
## Unlike execute(), this doesn't query the world but instead filters the provided entities.
## [param entities] Array of entities to filter
## [param returns] Array of entities that match the query criteria
func matches(entities: Array) -> Array:
	var result = []
	
	for entity in entities:
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
	
	clear()
	return result

func combine(other: QueryBuilder) -> QueryBuilder:
	_all_components += other._all_components
	_any_components += other._any_components
	_exclude_components += other._exclude_components
	return self

func as_array() -> Array:
	return [_all_components, _any_components, _exclude_components]
