## Flee System.
## Sheep with C_Flee sprint away from the shepherd, pathing through the
## NavigationMesh so they round obstacles instead of running into walls. The
## flee target is the point `safe_radius` away from the shepherd in the
## opposite direction, snapped to the navmesh. When the shepherd is outside
## the sheep's safe radius, C_Flee is removed and the sheep drops back into
## wandering.
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

	var shepherd_pos: Vector3 = shepherd.global_position

	for i in entities.size():
		var entity := entities[i]
		var sheep := entity as Sheep
		if sheep == null:
			continue
		var c_move: C_SheepMovement = moves[i]
		var c_threat: C_SheepThreat = threats[i]
		var c_flock: C_Flocking = flocks[i]
		var c_vel: C_Velocity = velocities[i]

		var away: Vector3 = sheep.global_position - shepherd_pos
		away.y = 0.0
		var dist := away.length()

		if dist > c_threat.safe_radius:
			cmd.remove_component(entity, C_Flee)
			c_vel.velocity = Vector3.ZERO
			continue

		var flee_dir := away.normalized() if dist > 0.001 else Vector3.FORWARD
		var agent := sheep.nav_agent

		# Aim for a point `safe_radius` away from the shepherd, snapped onto
		# the navmesh so pathing actually respects walls and the pen geometry.
		var flee_target: Vector3 = sheep.global_position + flee_dir * c_threat.safe_radius
		flee_target = SheepMath.snap_to_navmesh(agent, flee_target)
		if agent and agent.target_position.distance_to(flee_target) > 0.25:
			agent.target_position = flee_target

		# Follow the navmesh path when one exists, fall back to the raw
		# away-vector on the first frame / when no path is active.
		var desired: Vector3 = flee_dir
		if agent and not agent.is_navigation_finished():
			var next_path_pos := agent.get_next_path_position()
			var path_dir: Vector3 = next_path_pos - sheep.global_position
			path_dir.y = 0.0
			if path_dir.length_squared() > 0.0:
				desired = path_dir.normalized()

		var flock: Vector3 = Flocking.compute(sheep, c_flock)
		var move_dir: Vector3 = desired + flock * c_flock.flock_influence
		if move_dir.is_zero_approx():
			move_dir = desired
		else:
			move_dir = move_dir.normalized()

		c_vel.velocity = move_dir * c_move.run_speed
		SheepMath.face(sheep, move_dir, c_move.rotation_speed, delta)
