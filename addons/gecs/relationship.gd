## Relationship
## Represents a relationship between entities in the ECS framework.
## A relationship consists of a [Component] relation and a target, which can be an [Entity] or an archetype.
##
## Relationships are used to link entities together, allowing for complex queries and interactions.
## They enable entities to have dynamic associations that can be queried and manipulated at runtime.
##
## [b]Example:[/b]
## [codeblock]
##     # Create a 'likes' relationship where e_bob likes e_alice
##     var likes_relationship = Relationship.new(C_Likes.new(), e_alice)
##     e_bob.add_relationship(likes_relationship)
##
##     # Check if e_bob has a 'likes' relationship with e_alice
##     if e_bob.has_relationship(Relationship.new(C_Likes.new(), e_alice)):
##         print("Bob likes Alice!")
## [/codeblock]
class_name Relationship
extends Resource

## The relation component of the relationship.
## This defines the type of relationship and can contain additional data.
var relation

## The target of the relationship.
## This can be an [Entity], an archetype, or null.
var target

## The source of the relationship.
var source

func _init(_relation = null, _target = null):
	 # Assert for class reference vs instance for relation
	assert(not (_relation != null and (_relation is GDScript or _relation is Script)),
		"Relation must be an instance of Component (did you forget to call .new()?)")
	
	# Assert for relation type
	assert(_relation == null or _relation is Component, 
		"Relation must be null or a Component instance")
	
	# Assert for class reference vs instance for target
	assert(not (_target != null and _target is GDScript and _target is Component),
		"Target must be an instance of Component (did you forget to call .new()?)")
	
	# Assert for target type
	assert(_target == null or _target is Entity or _target is Script,
		"Target must be null, an Entity instance, or a Script archetype")
	
	relation = _relation
	target = _target

## Checks if this relationship matches another relationship.
## [param other]: The [Relationship] to compare with.
## [return]: `true` if both the relation and target match, `false` otherwise.
func matches(other: Relationship) -> bool:
	var rel_match = false
	var target_match = false

	# Compare relations
	if other.relation == null or relation == null:
		# If either relation is null, consider it a match (wildcard)
		rel_match = true
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
		else:
			# Unable to compare targets
			target_match = false

	return rel_match and target_match

func valid() -> bool:
	# make sure the target is a valid Entity instance or it's ok if it's null
	var relation_valid = false
	if target == null:
		relation_valid = true
	else:
		relation_valid = is_instance_valid(target)
	
	# Ensure the source is a valid Entity instance; it cannot be null
	var source_valid = is_instance_valid(source)
	
	return relation_valid and source_valid