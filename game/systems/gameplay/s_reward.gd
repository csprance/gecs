## Any Entity can contain a Reward component to indicate that the player has received a reward.
class_name RewardSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Reward])


func process(entity: Entity, _delta: float):
	var reward = entity.get_component(C_Reward) as C_Reward

	GameState.score += reward.points
	entity.remove_component(C_Reward)
