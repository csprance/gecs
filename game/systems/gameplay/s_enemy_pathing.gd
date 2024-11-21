class_name EnemyPathingSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Enemy, C_CharacterBody3D, C_Interested, C_InterestRange, C_Transform]).with_none([C_Death])

# We want to start pathing towards the interesting thing
func process(entity: Entity, _delta: float):
	var c_interest = entity.get_component(C_Interested) as C_Interested
	var c_interest_range = entity.get_component(C_InterestRange) as C_InterestRange
	var c_trs =  entity.get_component(C_Transform) as C_Transform
	# Check if it's too far away and remove the interest component
	if c_trs.transform.origin.distance_to(c_interest.target) > c_interest_range.value:
		entity.remove_component(C_Interested)
		return
	


