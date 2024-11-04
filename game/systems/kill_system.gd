## The kill system is responsible for killing any entity with health
## after the health gets to 0 it gets removed by the world
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
