class_name C_NavAgent3D
extends Component

@export_node_path('NavigationAgent3D') var nav_agent_path: NodePath

var _nav_agent: NavigationAgent3D

func set_get_nav_agent(entity: Entity) -> NavigationAgent3D:
	if _nav_agent:
		return _nav_agent
	_nav_agent = entity.get_node(nav_agent_path)
	return _nav_agent
