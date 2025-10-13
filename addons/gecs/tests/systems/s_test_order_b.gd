class_name S_TestOrderB
extends System
const NAME = 'S_TestOrderB'
func deps():
	return {
		Runs.After: [S_TestOrderA],
		Runs.Before: [S_TestOrderC],
	}

func query():
	return q.with_all([C_TestOrderComponent])

func process(entity: Entity, delta: float):
	var comp = entity.get_component(C_TestOrderComponent)
	comp.execution_log.append("B")
	comp.value += 10
