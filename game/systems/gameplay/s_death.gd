## Handles the death of bricks
class_name DeathSystem
extends System

@export var powerup_pickup_scene: PackedScene

var rng = RandomNumberGenerator.new()

func query() -> QueryBuilder:
	return q.with_any([C_Death]) # add required components


func process(entity: Entity, _delta: float) -> void:
	rng.randomize()
	Loggie.debug('Death!', self)
	SoundManager.play('fx', 'kill')
	
	# Add a reward to the game state
	GameState.score += 10
	
	# Get the Game State Component
	GameState.bricks -= 1

	# Randomyly Create a powerup entity
	# TODO: Random thought what if we had a Luck factor here? lol
	if rng.randf_range(0.0, 1.0) > 0.8:
		# Create the pickup
		var powerup_pickup = powerup_pickup_scene.duplicate(true).instantiate()
		# Add the pickup to the world
		ECS.world.add_entity(powerup_pickup)
		# Set the trs of the pickup to that of the entity that just died
		var entity_trs = entity.get_component(C_Transform) as C_Transform
		var pickup_trs = powerup_pickup.get_component(C_Transform) as C_Transform
		pickup_trs.position = entity_trs.position
		

	# This entity is dead remove it from the world
	ECS.world.remove_entity(entity)
