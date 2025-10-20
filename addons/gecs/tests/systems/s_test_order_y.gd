class_name S_TestOrderY
extends System

func deps():
	return {Runs.After: [], Runs.Before: []}

func query():
	return ECS.world.query.with_all([C_TestOrderComponent])

func process(entities: Array[Entity], components: Array, delta: float):
	for entity in entities:
		var comp = entity.get_component(C_TestOrderComponent)
		comp.execution_log.append("Y")
