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
## [br]• [b]Exact Matching:[/b] Find entities with specific relationship data
## [br]• [b]Weak Matching:[/b] Find entities by relationship type regardless of data
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
##     # Query for entities with specific fire damage amount
##     var fire_damaged = ECS.world.query.with_relationship([
##         Relationship.new(C_Damaged.new(), C_FireDamage.new(50))
##     ]).execute()
##     
##     # Check if entity has any fire damage using weak matching
##     var has_fire_damage = entity.has_relationship(
##         Relationship.new(C_Damaged.new(), C_FireDamage.new(999)), true
##     )
## [/codeblock]
##
## [b]Weak vs Strong Matching:[/b]
## [codeblock]
##     # Strong matching (default) - exact component data match
##     entity.has_relationship(Relationship.new(C_Eats.new(5), target), false)
##     
##     # Weak matching - matches by component type, ignores data
##     entity.has_relationship(Relationship.new(C_Eats.new(999), target), true)
## [/codeblock]
##
## [b]Custom Matching with equals() Override:[/b]
## [codeblock]
##     # Override equals() in your component for custom matching logic
##     class_name C_DamageType extends Component:
##         @export var damage_type: String = "physical"
##         
##         func equals(other: Component) -> bool:
##             if not other is C_DamageType:
##                 return false
##             return damage_type == other.damage_type  # Only match by type
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


func _init(_relation = null, _target = null):
	# Assert for class reference vs instance for relation
	assert(
		not (_relation != null and (_relation is GDScript or _relation is Script)),
		"Relation must be an instance of Component (did you forget to call .new()?)"
	)

	# Assert for relation type
	assert(
		_relation == null or _relation is Component, "Relation must be null or a Component instance"
	)

	# Assert for class reference vs instance for target
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
## [param weak]: If [code]true[/code], uses weak matching (component type only). If [code]false[/code], uses strong matching (exact component data).
## [return]: `true` if both the relation and target match according to the matching mode, `false` otherwise.
##
## [b]Matching Modes:[/b]
## [br]• [b]Strong Matching (default):[/b] Components must have identical data using [code]equals()[/code] method
## [br]• [b]Weak Matching:[/b] Components only need to be the same type (same [code]resource_path[/code])
## [br]• [b]Wildcard Matching:[/b] [code]null[/code] relations or targets act as wildcards and match anything
func matches(other: Relationship, weak = false) -> bool:
	var rel_match = false
	var target_match = false

	# Compare relations
	if other.relation == null or relation == null:
		# If either relation is null, consider it a match (wildcard)
		rel_match = true
	else:
		if weak:
			rel_match = relation.get_script() == other.relation.get_script()
		else:
			# Use the equals method from the Component class to compare relations
			rel_match = relation.equals(other.relation)

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
			# Both targets are components; use weak or strong matching
			if weak:
				target_match = target.get_script() == other.target.get_script()
			else:
				target_match = target.equals(other.target)
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
