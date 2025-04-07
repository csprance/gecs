## DamageSystem.
##
## Processes entities that have taken damage.
## Reduces the entity's health based on the `Damage` component.
## Plays a sound effect when damage is taken.
## Removes the `Damage` component after processing.
class_name DamageSystem
extends System

func sub_systems():
	return [
		# Handles damage on entities with health
		[ECS.world.query.with_all([C_Health]).with_any([C_Damage, C_HeavyDamage]).with_none([C_Death, C_Invunerable, C_Breakable]), health_damage_subsys], 
		# Handles damage on breakable entities and heavy damage done to them
		[ECS.world.query.with_all([C_Breakable, C_Health,C_HeavyDamage]).with_none([C_Death, C_Invunerable]), breakable_damage_subsys], 
	]

func breakable_damage_subsys(entity, delta):
	var c_heavy_damage = entity.get_component(C_HeavyDamage) as C_HeavyDamage
	var c_health = entity.get_component(C_Health) as C_Health

	c_health.current -= c_heavy_damage.amount

	if c_health.current <= 0:
		entity.add_component(C_Death.new())

func health_damage_subsys(entity: Entity, _delta: float):
	var c_damage = entity.get_component(C_Damage) as C_Damage
	var c_heavy_damage = entity.get_component(C_Damage) as C_Damage
	var c_health = entity.get_component(C_Health) as C_Health

	var damages = [c_damage, c_heavy_damage].filter( func(damage): return damage != null )

	for damage in damages:
		# Damage the Health Component by the damage amount
		c_health.current -= damage.amount
		entity.remove_component(damage.get_script())

	if c_health.current > 0:
		Loggie.debug('Damaged', c_damage, c_health)
		#SoundManager.play('fx', 'c_damage')

	
	if c_health.current <= 0:
		entity.add_component(C_Death.new())
	
	if entity is Player:
		GameState.health_changed.emit(c_health.current)
