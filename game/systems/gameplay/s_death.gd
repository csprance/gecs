## Handles the death of bricks
class_name DeathSystem
extends System


func query() -> QueryBuilder:
	return q.with_any([C_Death]) # add required components


func process(entity: Entity, _delta: float) -> void:
	Loggie.debug('Death!', self)
	SoundManager.play('fx', 'kill')
	var c_lives = entity.get_component(C_Lives) as C_Lives
	if not c_lives:
		# If we have no more lives, we are dead mark it for delete
		entity.add_component(C_IsPendingDelete.new()) # mark for deletion
		return
	# If we have lives, check to see if we can respawn and mark it for respawn
	c_lives.lives -= 1
	if c_lives.lives > 0:
		entity.add_component(C_NeedsRespawn.new()) # mark for respawn
		return
	if c_lives.lives <= 0:
		entity.add_component(C_IsPendingDelete.new()) # mark for deletion
		return
