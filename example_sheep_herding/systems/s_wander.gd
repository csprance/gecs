## Wander System.
## Picks a random target around the sheep, drives the NavigationAgent3D toward
## it, and writes steering into C_Velocity. Escalates to fleeing if the
## shepherd wanders into the sheep's flee radius.
class_name WanderSystem
extends System


func query() -> QueryBuilder:
	return (
		q
		.with_all(
			[
				C_Sheep,
				C_SheepMovement,
				C_SheepThreat,
				C_Flocking,
				C_Wander,
				C_Velocity,
			]
		)
		.with_none([C_Flee, C_Penned])
		.iterate(
			[
				C_SheepMovement,
				C_SheepThreat,
				C_Flocking,
				C_Wander,
				C_Velocity,
			]
		)
	)


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	# components[] order matches iterate(): movement, threat, flocking, wander, velocity.
	var moves: Array = components[0]
	var threats: Array = components[1]
	var flocks: Array = components[2]
	var wanders: Array = components[3]
	var velocities: Array = components[4]

	var shepherd := SheepMath.get_shepherd()
	var shepherd_valid := shepherd != null
	var shepherd_pos := shepherd.global_position if shepherd_valid else Vector3.ZERO

	for i in entities.size():
		var entity := entities[i]
		var sheep_entity := entity as Sheep
		var sheep := (entity as Node) as Node3D
		if sheep == null or sheep_entity == null:
			continue
		var c_move: C_SheepMovement = moves[i]
		var c_threat: C_SheepThreat = threats[i]
		var c_flock: C_Flocking = flocks[i]
		var c_wander: C_Wander = wanders[i]
		var c_vel: C_Velocity = velocities[i]

		if shepherd_valid:
			var dist_sq := SheepMath.xz_distance_sq(sheep.global_position, shepherd_pos)
			if dist_sq < c_threat.flee_radius * c_threat.flee_radius:
				cmd.add_component(entity, C_Flee.new())
				c_vel.velocity = Vector3.ZERO
				continue

		if c_wander.time_left > 0.0:
			c_wander.time_left -= delta
			c_vel.velocity = Vector3.ZERO
			continue

		var agent := sheep_entity.nav_agent

		# Arrived? Pick a new target and rest.
		var xz_to_target := c_wander.target - sheep.global_position
		xz_to_target.y = 0.0
		var arrived := xz_to_target.length() <= c_wander.reach_distance
		if arrived or c_wander.target == Vector3.ZERO:
			c_wander.target = _pick_target(sheep.global_position, c_wander.wander_radius)
			c_wander.time_left = randf_range(0.3, c_wander.rest_time)
			if agent:
				agent.target_position = c_wander.target
			c_vel.velocity = Vector3.ZERO
			continue

		if agent and agent.target_position.distance_to(c_wander.target) > 0.01:
			agent.target_position = c_wander.target

		# Desired direction: follow NavigationAgent3D path if available, else straight.
		var desired: Vector3
		if agent and not agent.is_navigation_finished():
			var next_path_pos := agent.get_next_path_position()
			desired = next_path_pos - sheep.global_position
			desired.y = 0.0
			if desired.length_squared() > 0.0:
				desired = desired.normalized()
		else:
			desired = xz_to_target.normalized()

		var flock: Vector3 = Flocking.compute(sheep, entity, c_flock)
		var move_dir := desired + flock * c_flock.flock_influence
		if move_dir.is_zero_approx():
			c_vel.velocity = Vector3.ZERO
			continue
		move_dir = move_dir.normalized()

		c_vel.velocity = move_dir * c_move.walk_speed
		SheepMath.face(sheep, move_dir, c_move.rotation_speed, delta)


func _pick_target(origin: Vector3, radius: float) -> Vector3:
	var angle := randf() * TAU
	var r := sqrt(randf()) * radius
	return origin + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
