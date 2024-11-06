## DamageSystem.
##
## Processes entities that have taken damage.
## Reduces the entity's health based on the `Damage` component.
## Plays a sound effect when damage is taken.
## Removes the `Damage` component after processing.
class_name DamageSystem
extends System

func query() -> QueryBuilder:
		return q.with_all([Damage, Health])


func process(entity: Entity, _delta: float):
	var damage = entity.get_component(Damage) as Damage
	var health = entity.get_component(Health) as Health

	# Damage the Health Component by the damage amount
	health.current -= damage.amount

	if health.current > 0:
		Loggie.debug('Damaged', damage, health)
		SoundManager.play('fx', 'damage')
	
	entity.remove_component(Damage)
	
	if health.current <= 0:
		entity.add_component(Death.new())
	
	# give a reward to the player for damage
	var reward = Reward.new()
	reward.points = 10
	GameStateUtils.get_active_game_state_entity().add_component(reward)
