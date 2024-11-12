## Handles the death of bricks
class_name DeathSystem
extends System

@export var powerup_pickup_scene: PackedScene

func query() -> QueryBuilder:
	return q.with_any([C_Death]) # add required components


func process(entity: Entity, _delta: float) -> void:
	Loggie.debug('Death!', self)
	SoundManager.play('fx', 'kill')
	
	# Add a reward to the game state
	GameState.score += 10
	
	# Get the Game State Component
	GameState.bricks -= 1

	# Randomyly Create a powerup entity
	# TODO: Random thought what if we had a Luck factor here? lol
	if randf_range(0.0, 1.0) > 0.8:
		var transform = entity.get_component(C_Transform) as C_Transform
		spawn_powerup(C_Powerup.PowerupType.CAPTURE, 10.0, transform.position)

	# This entity is dead remove it from the world
	ECS.world.remove_entity(entity)


func spawn_powerup(type: C_Powerup.PowerupType, time:float, position: Vector2):
	var powerup_pickup = powerup_pickup_scene.duplicate(true).instantiate()
	ECS.world.add_entity(powerup_pickup)
	# Add the powerup to the entity
	var powerup = C_Powerup.new()
	powerup.type = type
	powerup.time =  time
	var transform = powerup_pickup.get_component(C_Transform) as C_Transform
	transform.position = position
	
	powerup_pickup.add_components([powerup, transform])
