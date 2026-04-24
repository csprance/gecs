## Flee System.
## Sheep with C_Flee sprint directly away from the shepherd — no pathfinding
## (panic mode). When the shepherd is outside the sheep's safe radius,
## C_Flee is removed and the sheep drops back into wandering.
class_name FleeSystem
extends System


func query() -> QueryBuilder:
	return (
		q
		.with_all(
			[
				C_Sheep,
				C_Flee,
				C_SheepMovement,
				C_SheepThreat,
				C_Flocking,
				C_Velocity,
			]
		)
		.with_none([C_Penned])
		.iterate(
			[
				C_SheepMovement,
				C_SheepThreat,
				C_Flocking,
				C_Velocity,
			]
		)
	)


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	# components[] order matches iterate(): movement, threat, flocking, velocity.
	var moves: Array = components[0]
	var threats: Array = components[1]
	var flocks: Array = components[2]
	var velocities: Array = components[3]

	var shepherd := SheepMath.get_shepherd()

	if shepherd == null:
		# No shepherd around to flee from — everyone calms down.
		for entity in entities:
			cmd.remove_component(entity, C_Flee)
		return

	var shepherd_pos := shepherd.global_position

	for i in entities.size():
		var entity := entities[i]
		var sheep := (entity as Node) as Node3D
		if sheep == null:
			continue
		var c_move: C_SheepMovement = moves[i]
		var c_threat: C_SheepThreat = threats[i]
		var c_flock: C_Flocking = flocks[i]
		var c_vel: C_Velocity = velocities[i]

		var away := sheep.global_position - shepherd_pos
		away.y = 0.0
		var dist := away.length()

		if dist > c_threat.safe_radius:
			cmd.remove_component(entity, C_Flee)
			c_vel.velocity = Vector3.ZERO
			continue

		var flee_dir := away.normalized() if dist > 0.001 else Vector3.FORWARD
		var flock: Vector3 = Flocking.compute(sheep, entity, c_flock)
		var move_dir: Vector3 = flee_dir + flock * c_flock.flock_influence
		if move_dir.is_zero_approx():
			move_dir = flee_dir
		else:
			move_dir = move_dir.normalized()

		c_vel.velocity = move_dir * c_move.run_speed
		SheepMath.face(sheep, move_dir, c_move.rotation_speed, delta)
