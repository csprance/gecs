class_name Relationships

static func attacking_players():
	return Relationship.new(C_IsAttacking.new(), Player)

static func attacking_anything():
	return Relationship.new(C_IsAttacking.new(), ECS.wildcard)

static func range_attacking_players():
	return Relationship.new(C_IsAttackingRanged.new(), Player)

static func range_attacking_anything():
	return Relationship.new(C_IsAttackingRanged.new(), ECS.wildcard)

static func chasing_players():
	return Relationship.new(C_IsChasing.new(), Player)

static func chasing_anything():
	return Relationship.new(C_IsChasing.new(), ECS.wildcard)

## Applys to entities interacting with things
static func interacting_with_anything():
	return Relationship.new(C_Interacting.new(), ECS.wildcard)

## Applies to the entities being interacted with
static func interactable_being_interacted_with():
	return Relationship.new(C_BeingInteractedWith.new(), ECS.wildcard)

static func interactor_can_interact_with():
	return Relationship.new(C_CanInteractWith.new(), ECS.wildcard)