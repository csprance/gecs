class_name Relationship
extends Resource

var relation
var target

func _init(_relation = null, _target = null):
	relation = _relation
	target = _target

func matches(other: Relationship) -> bool:
	var rel_match = false
	var target_match = false

	# Compare relations
	if other.relation == null or relation == null:
		rel_match = true
	else:
		rel_match = relation.equals(other.relation)

	# Compare targets
	if other.target == null or target == null:
		target_match = true
	else:
		if target is Entity and other.target is Entity:
			target_match = target == other.target
		else:
			target_match = target == other.target

	return rel_match and target_match
