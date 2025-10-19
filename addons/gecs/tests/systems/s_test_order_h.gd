class_name S_TestOrderH
extends System

func deps():
	return {Runs.After: [S_TestOrderF, S_TestOrderG], Runs.Before: []}

func query():
	return ECS.world.query.with_all([C_TestOrderComponent])

func process(entity: Entity, delta: float):
	var c = entity.get_component(C_TestOrderComponent)
	c.execution_log.append("H")
