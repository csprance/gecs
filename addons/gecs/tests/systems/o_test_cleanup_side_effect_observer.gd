## Observer that removes C_ObserverHealth as a side effect when C_ObserverTest is removed.
## Used to test re-entrancy safety in remove_entity: if signals remain connected during
## the observer notification loop, health_observer will be notified twice.
class_name O_TestCleanupSideEffectObserver
extends Observer

func watch() -> Resource:
	return C_ObserverTest

func match() -> QueryBuilder:
	return q.with_all([C_ObserverTest])

func on_component_removed(entity: Entity, component: Resource) -> void:
	if entity.has_component(C_ObserverHealth):
		entity.remove_component(C_ObserverHealth)
