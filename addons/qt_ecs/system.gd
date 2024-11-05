## System
##
## The base class for all systems within the ECS framework.
## Systems contain the core logic and behavior, processing entities that have specific components.
##
## Each system defines the components required for it to process an entity and implements the `process` method.
##
## Example:
##     class_name MovementSystem
##     extends System
##
##     func _init():
##         required_components = [Transform, Velocity]
##
##     func process(entity: Entity, delta: float) -> void:
##         var transform = entity.get_component(Transform)
##         var velocity = entity.get_component(Velocity)
##         transform.position += velocity.direction * velocity.speed * delta
@icon('res://addons/qt_ecs/assets/system.svg')
class_name System
extends Node

## The list of Components that an Entity must possess all of to be processed by this system.
var required_components: Array[Variant] = []
## Determines whether the system should run even when there are no entities to process.
var process_empty := false


## The main processing function for the system.
##
## This method should be overridden by subclasses to define the system's behavior.
##
## @param entity The entity being processed.
## @param delta The time elapsed since the last frame.
func process(entity: Entity, delta: float) -> void:
	assert(false, "The 'process' method must be overridden in subclasses.")

## Processes all entities that match the system's required components.
##
## @param entities An array of entities to process.
## @param delta The time elapsed since the last frame.
func process_entities(entities: Array, delta: float):
	# If we have no entities and we want to process even when empty do it once and return
	if entities.size() == 0 and process_empty:
		process(null, delta)

	# otherwise process all the entities (wont happen if empty array)
	for entity in entities:
		process(entity, delta)
		entity.on_update(delta)
