## System[br]
## The base class for all systems within the ECS framework.
##
## Systems contain the core logic and behavior, processing [Entity]s that have specific [Component]s.[br]
## Each system defines the [Component]s required for it to process an [Entity] and implements the `[method System.process]` method.[br][br]
## [b]Example:[/b]
##[codeblock]
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
##[/codeblock]
@icon('res://addons/qt_ecs/assets/system.svg')
class_name System
extends Node

## Determines whether the system should run even when there are no [Entity]s to process.
var process_empty := false

## Override this method and return a [QueryBuilder] to define the required [Component]s for the system.[br]
## If not overridden, the system will run on every update with no entities.
func query(q: QueryBuilder) -> QueryBuilder:
	process_empty = true
	return q

## The main processing function for the system.[br]
## This method should be overridden by subclasses to define the system's behavior.[br]
## [param entity] The [Entity] being processed.[br]
## [param delta] The time elapsed since the last frame.
func process(entity: Entity, delta: float) -> void:
	assert(false, "The 'process' method must be overridden in subclasses.")


## Processes all [Entity]s that match the system's required [Component]s.[br]
## [param entities] An [Array] of [Entity] to process.[br]
## [param delta] The time elapsed since the last frame.
func process_entities(entities: Array, delta: float):
	# If we have no entities and we want to process even when empty do it once and return
	if entities.size() == 0 and process_empty:
		process(null, delta)

	# otherwise process all the entities (wont happen if empty array)
	for entity in entities:
		process(entity, delta)
		entity.on_update(delta)
