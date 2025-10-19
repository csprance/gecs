class_name S_TestOrderA
extends System
const NAME = 'S_TestOrderA'
func deps():
	return {
		Runs.Before: [ECS.wildcard], # Run before all other systems
		Runs.After: [],
	}

func query():
	return ECS.world.query.with_all([C_TestOrderComponent])

func process(entity: Entity, delta: float):
	var comp = entity.get_component(C_TestOrderComponent)
	comp.execution_log.append("A")
	comp.value += 1
