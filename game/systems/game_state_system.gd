## GameStateSystem.
##
## Manages global game state.
## Currently serves as a placeholder for game state updates.
## Processes entities with the `GameState` component.
class_name GameStateSystem
extends System

func query(q: QueryBuilder) -> QueryBuilder:
	return q.with_all([GameState])


func process(entity: Entity, delta: float):
	pass
