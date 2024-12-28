## Runs once and then removes itself.
## Counts the victims and sets the victim number in GameState
class_name VictimInitSystem
extends System


func query():
	return q.with_all([C_Victim])

func process_all(entities: Array, delta: float):
	GameState.victims = entities.size()
	ECS.world.remove_system(self)
