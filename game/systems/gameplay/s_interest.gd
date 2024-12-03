## Manages the interest of the entities. They can be interested in something and lose interest
class_name InterestSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Enemy, C_Interested, C_InterestRange, C_Transform]).with_none([C_Death])

# We want to start pathing towards the interesting thing
func process(entity: Entity, delta: float):
	var c_interest = entity.get_component(C_Interested) as C_Interested
	var c_interest_range = entity.get_component(C_InterestRange) as C_InterestRange
	var c_trs =  entity.get_component(C_Transform) as C_Transform

	c_interest.bored_timer -= delta

	# Check if it's too far away and remove the interest component twice as fast
	if c_trs.transform.origin.distance_to(c_interest.target) > c_interest_range.value:
		if c_interest.bored_timer >= 0:
			c_interest.bored_timer -= delta

	# If they're bored, remove the interest component
	if c_interest.bored_timer <= 0:
		entity.remove_component(C_Interested)

