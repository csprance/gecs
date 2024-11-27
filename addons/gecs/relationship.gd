class_name Relationship
extends Resource


## The component representing the relation
var relation: Component
## The target entity or class of entity
var target

func _init(_relation: Component, _target = null):
    relation = _relation
    if _target == null:
        target = ECS.WildCard.Target
    else:
        target = _target

## Checks if this relationship matches another, considering wildcards
func matches(other: Relationship) -> bool:
    var rel_match = false
    var target_match = false

    # Compare relations
    if other.relation == null or other.relation == ECS.WildCard.Relation:
        rel_match = true
    elif relation == null or relation == ECS.WildCard.Relation:
        rel_match = true
    else:
        rel_match = relation.equals(other.relation)

    # Compare targets
    if other.target == null or other.target == ECS.WildCard.Target:
        target_match = true
    elif target == null or target == ECS.WildCard.Target:
        target_match = true
    else:
        if target is Entity and other.target is Entity:
            target_match = target == other.target
        elif target is Entity:
            target_match = target == other.target
        elif other.target is Entity:
            target_match = other.target == target
        else:
            target_match = target == other.target

    return rel_match and target_match