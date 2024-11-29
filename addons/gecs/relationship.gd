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

func _init(_relation = null, _target = null):
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
        if target is Entity and other.target is Entity:
            # Both targets are entities; compare references directly
            target_match = target == other.target
        else:
            # Compare targets (could be archetypes or other types)
            target_match = target == other.target

    return rel_match and target_match
