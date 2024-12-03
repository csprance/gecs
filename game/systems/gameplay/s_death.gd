## Handles the death of bricks
class_name DeathSystem
extends System


func query() -> QueryBuilder:
	return q.with_any([C_Death]) # add required components


func process(entity: Entity, _delta: float) -> void:
	Loggie.debug('Death!', self)
	SoundManager.play('fx', 'kill')
	
	# Add a reward to the game state
	GameState.score += 10

	entity.add_component(C_IsPendingDelete.new()) # mark for deletion
