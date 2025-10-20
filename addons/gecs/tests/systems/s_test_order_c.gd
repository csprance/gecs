class_name S_TestOrderC
extends System
const NAME = 'S_TestOrderC'
func deps():
	return {
		Runs.After: [S_TestOrderB],
		Runs.Before: [S_TestOrderD],
	}

func query():
	return ECS.world.query.with_all([C_TestOrderComponent])

func process(entities: Array[Entity], components: Array, delta: float):
	for entity in entities:
		var comp = entity.get_component(C_TestOrderComponent)
		comp.execution_log.append("C")
		comp.value += 100
