## Relationship
## Represents a relationship between entities in the ECS framework.
## A relationship consists of a [Component] relation and a target, which can be an [Entity], a [Component], or an archetype.
##
## Relationships are used to link entities together, allowing for complex queries and interactions.
## They enable entities to have dynamic associations that can be queried and manipulated at runtime.
## The powerful relationship system supports component-based targets for hierarchical type systems.
##
## [b]Relationship Types:[/b]
## [br]• [b]Entity Relationships:[/b] Link entities to other entities
## [br]• [b]Component Relationships:[/b] Link entities to component instances for type hierarchies
## [br]• [b]Archetype Relationships:[/b] Link entities to component/entity classes
##
## [b]Query Features:[/b]
## [br]• [b]Type Matching:[/b] Find entities by relationship component type (default)
## [br]• [b]Query Matching:[/b] Use dictionaries to match by specific property criteria
## [br]• [b]Wildcard Queries:[/b] Use [code]null[/code] targets to find any relationship of a type
##
## [b]Basic Entity Relationship Example:[/b]
## [codeblock]
##     # Create a 'likes' relationship where e_bob likes e_alice
##     var likes_relationship = Relationship.new(C_Likes.new(), e_alice)
##     e_bob.add_relationship(likes_relationship)
##
##     # Check if e_bob has a 'likes' relationship with e_alice
##     if e_bob.has_relationship(Relationship.new(C_Likes.new(), e_alice)):
##         print("Bob likes Alice!")
## [/codeblock]
##
## [b]Component-Based Relationship Example:[/b]
## [codeblock]
##     # Create a damage type hierarchy using components as targets
##     var fire_damage = C_FireDamage.new(50)
##     var poison_damage = C_PoisonDamage.new(25)
##
##     # Entity has different types of damage
##     entity.add_relationship(Relationship.new(C_Damaged.new(), fire_damage))
##     entity.add_relationship(Relationship.new(C_Damaged.new(), poison_damage))
##
##     # Query for entities with any damage type (wildcard)
##     var damaged_entities = ECS.world.query.with_relationship([
##         Relationship.new(C_Damaged.new(), null)
##     ]).execute()
##
##     # Query for entities with fire damage amount >= 50 using component query
##     var fire_damaged = ECS.world.query.with_relationship([
##         Relationship.new(C_Damaged.new(), {C_FireDamage: {'amount': {"_gte": 50}}})
##     ]).execute()
##
##     # Check if entity has any fire damage (type matching)
##     var has_fire_damage = entity.has_relationship(
##         Relationship.new(C_Damaged.new(), C_FireDamage.new())
##     )
## [/codeblock]
##
## [b]Component Query Examples:[/b]
## [codeblock]
##     # Query relation by property value
##     var entities = ECS.world.query.with_relationship([
##         Relationship.new({C_Eats: {'value': {"_eq": 8}}}, e_apple)
##     ]).execute()
##
##     # Query target by property value
##     var entities = ECS.world.query.with_relationship([
##         Relationship.new(C_Damage.new(), {C_Health: {'amount': {"_gte": 50}}})
##     ]).execute()
##
##     # Query both relation AND target
##     var entities = ECS.world.query.with_relationship([
##         Relationship.new(
##             {C_Buff: {'duration': {"_gt": 10}}},
##             {C_Player: {'level': {"_gte": 5}}}
##         )
##     ]).execute()
## [/codeblock]
class_name Relationship
extends Resource

## The relation component of the relationship.
## This defines the type of relationship and can contain additional data.
var relation

## The target of the relationship.
## This can be an [Entity], a [Component], an archetype, or null.
var target

## The source of the relationship.
var source

## Component query for relation matching (if relation was created from dictionary)
var relation_query: Dictionary = {}

## Component query for target matching (if target was created from dictionary)
var target_query: Dictionary = {}

## Flag to track if this relationship was created from a component query dictionary (private - used for validation)
var _is_query_relationship: bool = false


func _init(_relation = null, _target = null):
	# Handle component queries (dictionaries) for relation
	if _relation is Dictionary:
		_is_query_relationship = true
		# Extract component type and query from dictionary
		for component_type in _relation:
			var query = _relation[component_type]
			# Store the query and create component instance
			relation_query = query
			_relation = component_type.new()
			break

	# Handle component queries (dictionaries) for target
	if _target is Dictionary:
		_is_query_relationship = true
		# Extract component type and query from dictionary
		for component_type in _target:
			var query = _target[component_type]
			# Store the query and create component instance
			target_query = query
			_target = component_type.new()
			break

	# Assert for class reference vs instance for relation (skip for dictionaries)
	if not _relation is Dictionary:
		assert(
			not (_relation != null and (_relation is GDScript or _relation is Script)),
			"Relation must be an instance of Component (did you forget to call .new()?)"
		)

	# Assert for relation type
	assert(
		_relation == null or _relation is Component, "Relation must be null or a Component instance"
	)

	# Assert for class reference vs instance for target (skip for dictionaries)
	if not _target is Dictionary:
		assert(
			not (_target != null and _target is GDScript and _target is Component),
			"Target must be an instance of Component (did you forget to call .new()?)"
		)

	# Assert for target type
	assert(
		_target == null or _target is Entity or _target is Script or _target is Component,
		"Target must be null, an Entity instance, a Script archetype, or a Component instance"
	)

	relation = _relation
	target = _target


## Checks if this relationship matches another relationship.
## [param other]: The [Relationship] to compare with.
## [return]: `true` if both the relation and target match, `false` otherwise.
##
## [b]Matching Modes:[/b]
## [br]• [b]Type Matching:[/b] Components match by type (default behavior)
## [br]• [b]Query Matching:[/b] If component query dictionary used, evaluates property criteria
## [br]• [b]Wildcard Matching:[/b] [code]null[/code] relations or targets act as wildcards and match anything
func matches(other: Relationship) -> bool:
	var rel_match = false
	var target_match = false

	# Compare relations
	if other.relation == null or relation == null:
		# If either relation is null, consider it a match (wildcard)
		rel_match = true
	else:
		# Check if other relation has component query (query relationships)
		if not other.relation_query.is_empty():
			# Other has component query, check if this relation matches that query
			if relation.get_script() == other.relation.get_script():
				rel_match = ComponentQueryMatcher.matches_query(relation, other.relation_query)
			else:
				rel_match = false
		# Check if this relation has component query (this is query relationship)
		elif not relation_query.is_empty():
			# This has component query, check if other relation matches this query
			if relation.get_script() == other.relation.get_script():
				rel_match = ComponentQueryMatcher.matches_query(other.relation, relation_query)
			else:
				rel_match = false
		else:
			# Standard type matching by script type
			rel_match = relation.get_script() == other.relation.get_script()

	# Compare targets
	if other.target == null or target == null:
		# If either target is null, consider it a match (wildcard)
		target_match = true
	else:
		if target == other.target:
			target_match = true
		elif target is Entity and other.target is Script:
			# target is an entity instance, other.target is an archetype
			target_match = target.get_script() == other.target
		elif target is Script and other.target is Entity:
			# target is an archetype, other.target is an entity instance
			target_match = other.target.get_script() == target
		elif target is Entity and other.target is Entity:
			# Both targets are entities; compare references directly
			target_match = target == other.target
		elif target is Script and other.target is Script:
			# Both targets are archetypes; compare directly
			target_match = target == other.target
		elif target is Component and other.target is Component:
			# Both targets are components; check for query or type matching
			# Check if other target has component query
			if not other.target_query.is_empty():
				# Other has component query, check if this target matches that query
				if target.get_script() == other.target.get_script():
					target_match = ComponentQueryMatcher.matches_query(target, other.target_query)
				else:
					target_match = false
			# Check if this target has component query
			elif not target_query.is_empty():
				# This has component query, check if other target matches this query
				if target.get_script() == other.target.get_script():
					target_match = ComponentQueryMatcher.matches_query(other.target, target_query)
				else:
					target_match = false
			else:
				# Standard type matching by script type
				target_match = target.get_script() == other.target.get_script()
		elif target is Component and other.target is Script:
			# target is component instance, other.target is component archetype
			target_match = target.get_script() == other.target
		elif target is Script and other.target is Component:
			# target is component archetype, other.target is component instance
			target_match = other.target.get_script() == target
		else:
			# Unable to compare targets
			target_match = false

	return rel_match and target_match


func valid() -> bool:
	# make sure the target is valid or null
	var target_valid = false
	if target == null:
		target_valid = true
	elif target is Entity:
		target_valid = is_instance_valid(target)
	elif target is Component:
		# Components are Resources, so they're always valid once created
		target_valid = true
	elif target is Script:
		# Script archetypes are always valid
		target_valid = true
	else:
		target_valid = false

	# Ensure the source is a valid Entity instance; it cannot be null
	var source_valid = is_instance_valid(source)

	return target_valid and source_valid


## Provides a consistent string representation for cache keys and debugging.
## Two relationships with the same relation type and target should produce identical strings.
func _to_string() -> String:
	var parts = []

	# Format relation component
	if relation == null:
		parts.append("null")
	elif not relation_query.is_empty():
		# This is a query relationship - include the query criteria
		parts.append(relation.get_script().resource_path + str(relation_query))
	else:
		# Standard relation - just the type
		parts.append(relation.get_script().resource_path)

	# Format target
	if target == null:
		parts.append("null")
	elif target is Entity:
		# Use instance_id for stability - entity ID may not be set yet
		parts.append("Entity#" + str(target.get_instance_id()))
	elif target is Component:
		if not target_query.is_empty():
			# Component with query
			parts.append(target.get_script().resource_path + str(target_query))
		else:
			# Type matching - use Script instance ID (consistent with query caching)
			parts.append(target.get_script().resource_path + "#" + str(target.get_script().get_instance_id()))
	elif target is Script:
		# Archetype target
		parts.append("Archetype:" + target.resource_path)
	else:
		parts.append(str(target))

	return "Relationship(" + parts[0] + " -> " + parts[1] + ")"
