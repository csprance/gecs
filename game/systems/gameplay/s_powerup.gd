## The Powerup System runs for any entity that has a powerup on it
class_name PowerupSystem
extends System


func query():
	return q.with_all([C_Powerup])


func process(entity: Entity, delta: float):
	var powerup = entity.get_component(C_Powerup) as C_Powerup
	
	# Remove the component when powerup is done.
	powerup.time -= delta
	Loggie.debug(powerup.time)
	if powerup.time <= 0:
		Loggie.debug('%s Powerup De-activated!' % powerup.type)
		entity.remove_component(C_Powerup)
		return
	
	Loggie.debug('%s Powerup Running!' % powerup.type)
	# Run the Effect for the powerup
	match powerup.type:
		C_Powerup.PowerupType.SPEED:
			pass        
		C_Powerup.PowerupType.MEGA:
			pass
		C_Powerup.PowerupType.CAPTURE:
			pass
