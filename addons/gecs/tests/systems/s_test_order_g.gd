class_name S_TestOrderG
extends System

func deps():
	return {Runs.After: [S_TestOrderE], Runs.Before: []}

func query():
	return q.with_all([C_TestOrderComponent])

func process(entity: Entity, delta: float):
	var c = entity.get_component(C_TestOrderComponent)
	c.execution_log.append("G")
