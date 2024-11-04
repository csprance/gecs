## The damage system is reponsible for taking in a dmage component doing stuff
## with it to an entity and reducing the health of an entity
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
