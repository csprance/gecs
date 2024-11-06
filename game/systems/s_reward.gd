## Any Entity can contain a Reward component to indicate that the player has received a reward.
class_name RewardSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([Reward])


func process(entity: Entity, _delta: float):
	var game_state = GameStateUtils.get_game_state()
	var reward = entity.get_component(Reward) as Reward

	game_state.score += reward.points
	entity.remove_component(Reward)
