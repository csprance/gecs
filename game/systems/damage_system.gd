## DamageSystem.
##
## Processes entities that have taken damage.
## Reduces the entity's health based on the `Damage` component.
## Plays a sound effect when damage is taken.
## Removes the `Damage` component after processing.
class_name DamageSystem
extends System

func _init():
	required_components = [Damage, Health]


func process(entity: Entity, delta: float):
	var damage = entity.get_component(Damage) as Damage
	var health = entity.get_component(Health) as Health

	# Damage the Health Component by the damage amount
	health.current -= damage.amount

	if health.current > 0:
		print('Damaged')
		SoundManager.play('fx', 'damage')

	entity.remove_component(Damage)
