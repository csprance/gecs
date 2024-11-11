## DamageSystem.
##
## Processes entities that have taken damage.
## Reduces the entity's health based on the `Damage` component.
## Plays a sound effect when damage is taken.
## Removes the `Damage` component after processing.
class_name DamageSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Damage, C_Health]).with_none([C_Death])


func process(entity: Entity, _delta: float):
	var damage = entity.get_component(C_Damage) as C_Damage
	var health = entity.get_component(C_Health) as C_Health

	# Damage the Health Component by the damage amount
	health.current -= damage.amount
	# Determin the cracked amount
	entity.cracked_amt =  1 - (float(health.current) / float(health.total))

	if health.current > 0:
		Loggie.debug('Damaged', damage, health)
		SoundManager.play('fx', 'damage')
		# give a reward to the player for damage
		GameState.score += 10
	
	entity.remove_component(C_Damage)
	
	if health.current <= 0:
		entity.add_component(C_Death.new())

