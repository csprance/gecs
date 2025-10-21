class_name S_TestOrderE
extends System

func deps():
	return {Runs.After: [], Runs.Before: []}

func query():
	return ECS.world.query.with_all([C_TestOrderComponent])

func process(entities: Array[Entity], components: Array, delta: float):
	for entity in entities:
		var c = entity.get_component(C_TestOrderComponent)
		c.execution_log.append("E")
