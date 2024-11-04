## KillSystem.
##
## Removes entities whose health has dropped to zero or below.
## Processes entities with the `Health` component.
## Plays a sound effect upon entity death.
class_name KillSystem
extends System

func _init() -> void:
	required_components = [Health]


func process(entity: Entity, delta: float) -> void:
	var health = entity.get_component(Health) as Health

	# If it's health is below 0 remove the entity
	if health.current <= 0:
		print('DIED!')
		SoundManager.play('fx', 'kill')
		WorldManager.world.remove_entity(entity)
