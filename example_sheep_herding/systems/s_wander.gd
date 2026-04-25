## Wander System.
## One state machine — travel → at goal? → timeout → set new goal → repeat —
## split across two sub-queries that share a single loop. The query split is
## the only place penning matters; the loop just takes an `is_penned` flag.
##
## - Free sheep (`with_none([C_Flee, C_Penned])`): pick goals around themselves
##   and bolt to fleeing if the shepherd crosses the threat radius.
## - Penned sheep (`with_all([C_Penned]).with_none([C_Flee])`): pick goals
##   inside the pen and ignore the shepherd entirely (FleeSystem also excludes
##   C_Penned, so they never get a C_Flee added in the first place).
class_name WanderSystem
extends System

## Inset from the pen boundary when sampling a new goal inside a pen, so sheep
## don't pick targets right on the wall.
const PEN_GOAL_INSET: float = 0.5


func sub_systems() -> Array[Array]:
	return [
		[
			(
				q
				.with_all(
					[C_Sheep, C_SheepMovement, C_SheepThreat, C_Flocking, C_Wander, C_Velocity]
				)
				.with_none([C_Flee, C_Penned])
				.iterate([C_SheepMovement, C_SheepThreat, C_Flocking, C_Wander, C_Velocity])
			),
			_process_free,
		],
		[
			(
				q
				.with_all(
					[
						C_Sheep,
						C_SheepMovement,
						C_SheepThreat,
						C_Flocking,
						C_Wander,
						C_Velocity,
						C_Penned
					]
				)
				.with_none([C_Flee])
				.iterate([C_SheepMovement, C_SheepThreat, C_Flocking, C_Wander, C_Velocity])
			),
			_process_penned,
		],
	]


func _process_free(entities: Array[Entity], components: Array, delta: float) -> void:
	_run_loop(entities, components, delta, false)


func _process_penned(entities: Array[Entity], components: Array, delta: float) -> void:
	_run_loop(entities, components, delta, true)


## Shared per-frame loop for free and penned wanderers. The two only diverge in
## (a) whether the shepherd-flee trigger fires, and (b) where new goals are
## sampled — both gated on `is_penned`.
func _run_loop(entities: Array[Entity], components: Array, delta: float, is_penned: bool) -> void:
	# components[] order matches iterate(): movement, threat, flocking, wander, velocity.
	var moves: Array = components[0]
	var threats: Array = components[1]
	var flocks: Array = components[2]
	var wanders: Array = components[3]
	var velocities: Array = components[4]

	var shepherd := SheepMath.get_shepherd() if not is_penned else null
	var shepherd_valid := shepherd != null
	var shepherd_pos: Vector3 = shepherd.global_position if shepherd_valid else Vector3.ZERO

	for i in entities.size():
		var entity := entities[i]
		var sheep := entity as Sheep
		if sheep == null:
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

		var agent := sheep.nav_agent

		# Arrived? Pick a new target and rest.
		var xz_to_target := Vector3(c_wander.target - sheep.global_position)
		xz_to_target.y = 0.0
		var arrived := xz_to_target.length() <= c_wander.reach_distance
		if arrived or c_wander.target == Vector3.ZERO:
			var picked := _pick_goal(sheep.global_position, c_wander, entity, is_penned)
			# Snap onto the navmesh so the NavigationAgent3D always gets a
			# reachable destination and sheep don't wander into unbaked space.
			c_wander.target = SheepMath.snap_to_navmesh(agent, picked)
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

		var flock: Vector3 = Flocking.compute(sheep, c_flock)
		var move_dir := desired + flock * c_flock.flock_influence
		if move_dir.is_zero_approx():
			c_vel.velocity = Vector3.ZERO
			continue
		move_dir = move_dir.normalized()

		c_vel.velocity = move_dir * c_move.walk_speed
		SheepMath.face(sheep, move_dir, c_move.rotation_speed, delta)


## Penned sheep sample around the pen center within `radius - inset`; everyone
## else samples around their own position within `wander_radius`.
func _pick_goal(sheep_pos: Vector3, c_wander: C_Wander, entity: Entity, is_penned: bool) -> Vector3:
	if is_penned:
		var c_penned := entity.get_component(C_Penned) as C_Penned
		if c_penned:
			var inset_radius: float = max(0.0, c_penned.radius - PEN_GOAL_INSET)
			return _random_disc_point(c_penned.center, inset_radius)
	return _random_disc_point(sheep_pos, c_wander.wander_radius)


func _random_disc_point(origin: Vector3, radius: float) -> Vector3:
	var angle := randf() * TAU
	var r := sqrt(randf()) * radius
	return origin + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
