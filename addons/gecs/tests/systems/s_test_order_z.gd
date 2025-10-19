class_name S_TestOrderZ
extends System

func deps():
	return {Runs.After: [], Runs.Before: []}

func query():
	return ECS.world.query.with_all([C_TestOrderComponent])

func process(entity: Entity, delta: float):
	var comp = entity.get_component(C_TestOrderComponent)
	comp.execution_log.append("Z")
