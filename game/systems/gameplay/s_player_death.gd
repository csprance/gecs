## Any Entity can contain a PlayerDeath component to indicate that the player has died.
class_name PlayerDeathSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_PlayerDeath])


func process(entity: Entity, _delta: float):
	GameState.lives -= 1
	
	Loggie.debug("PlayerDeathSystem", "Player died. Lives remaining: " + str(GameState.lives))
	entity.remove_component(C_PlayerDeath)
