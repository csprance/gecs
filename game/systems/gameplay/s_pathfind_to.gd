class_name PathFindToSystem
extends System

func query():
	return q.with_all([C_PathFindTo, C_Transform, C_NavAgent3D, C_Movement, C_Velocity]).with_none([C_Death])


func process(entity: Entity, delta: float):
	var c_path_find_to  = entity.get_component(C_PathFindTo) as C_PathFindTo
	var c_trs  = entity.get_component(C_Transform) as C_Transform
	var c_nav_agent_3d  = entity.get_component(C_NavAgent3D) as C_NavAgent3D
	var c_movement  = entity.get_component(C_Movement) as C_Movement
	var c_velocity  = entity.get_component(C_Velocity) as C_Velocity


	var navigation_agent: NavigationAgent3D = c_nav_agent_3d.set_get_nav_agent(entity)

	# Set the target position if it's not the same as the navigation agent's target
	if navigation_agent.target_position != c_path_find_to.target:
		navigation_agent.set_target_position(c_path_find_to.target)
		
	# Remove the path find to component if the navigation agent is finished and bail out
	if navigation_agent.is_navigation_finished():
		entity.remove_component(C_PathFindTo)
		return

	# Get the next path position and set the velocity to move toward it based on the movement speed
	var next_path_position: Vector3 = navigation_agent.get_next_path_position()

	c_velocity.velocity = c_trs.transform.origin.direction_to(next_path_position) * c_movement.speed
