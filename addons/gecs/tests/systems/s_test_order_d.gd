class_name S_TestOrderD
extends System

const NAME = 'S_TestOrderD'

func deps():
	return {
		Runs.After: [ECS.wildcard], # Run after all other systems
		Runs.Before: [],
	}

func query():
	return q.with_all([C_TestOrderComponent])

func process(entity: Entity, delta: float):
	var comp = entity.get_component(C_TestOrderComponent)
	comp.execution_log.append("D")
	comp.value += 1000
