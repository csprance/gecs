## Handles the death of bricks
class_name DeathSystem
extends System


func query() -> QueryBuilder:
	return q.with_any([C_Death]) # add required components


func process(entity: Entity, _delta: float) -> void:
	Loggie.debug('Death!', self)
	#SoundManager.play('fx', 'kill')
	
	# If we have a reward, give it to the player
	var c_reward = entity.get_component(C_Reward) as C_Reward
	if c_reward:
		GameState.score += c_reward.points

	var c_lives = entity.get_component(C_Lives) as C_Lives
	if not c_lives:
		# If we have no more lives, we are dead mark it for delete
		entity.add_component(C_IsPendingDelete.new()) # mark for deletion
		return
	# If we have lives, check to see if we can respawn and mark it for respawn
	c_lives.lives -= 1
	if c_lives.lives > 0:
		var new_entity = entity.duplicate() # duplicate the entity
		new_entity.remove_component(C_Death) # remove the death component
		# mark for delete
		entity.add_component(C_IsPendingDelete.new()) 
		# Add entity to the world after the respawn time
		await ECS.world.get_tree().create_timer(c_lives.respawn_time).timeout
		ECS.world.add_entity(new_entity)
		new_entity.add_components([C_Transform.new(c_lives.respawn_location), C_Lives.new(c_lives.lives, c_lives.respawn_time, c_lives.respawn_location)])
		Utils.sync_from_transform(new_entity) # sync the transform
		return
	if c_lives.lives <= 0:
		entity.add_component(C_IsPendingDelete.new()) # mark for deletion
		return
