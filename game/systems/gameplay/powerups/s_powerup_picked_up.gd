class_name PowerupPickedUpSystem
extends System

func query():
	return q.with_all([C_PowerupPickedUp])

func process(entity, _delta):
	var powerup = entity.get_component(C_PowerupPickedUp) as C_PowerupPickedUp
	var powerup_entity: Entity

	match powerup.powerup.get_script():
		C_MegaBall:
			# Add it to a single ball
			Loggie.debug('Mega')
			var balls = Utils.get_active_balls()
			powerup_entity = balls[0]
		C_CaptureNextBall:
			# Add it to the paddle
			Loggie.debug('Capture Next Ball')
			var paddles = Utils.get_active_paddles()
			powerup_entity = paddles[0]
		C_SpeedModifier:
			# Add it to a single ball
			Loggie.debug('Speed Modifier')
			var balls = Utils.get_active_balls()
			powerup_entity = balls[0]
		_:
			Loggie.debug('Unknown Pickup Event')
	
	powerup_entity.add_component(powerup.powerup)

	# Nuke the event after it's processed once
	ECS.world.remove_entity(entity)
