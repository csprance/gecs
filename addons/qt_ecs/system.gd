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

var q: QueryBuilder


## Override this method and return a [QueryBuilder] to define the required [Component]s for the system.[br]
## If not overridden, the system will run on every update with no entities.
func query() -> QueryBuilder:
	process_empty = true
	return q

## The main processing function for the system.[br]
## This method should be overridden by subclasses to define the system's behavior.[br]
## [param entity] The [Entity] being processed.[br]
## [param delta] The time elapsed since the last frame.
func process(entity: Entity, delta: float) -> void:
	assert(false, "The 'process' method must be overridden in subclasses.")

## handles the processing of all [Entity]s that match the system's query [Component]s.[br]
## [param delta] The time elapsed since the last frame.
func _handle(delta: float):
	# Build our single QueryBuilder object
	if q == null:
		q = ECS.buildQuery()
	var did_run := false
	# Query for the entities that match the system's query
	var entities = query().execute() as Array[Entity]

	# If we have no entities and we want to process even when empty do it once and return
	if entities.size() == 0 and process_empty:
		process(null, delta)
		did_run = true
	else:
		# otherwise process all the entities (wont happen if empty array)
		for entity in entities:
			did_run = true
			process(entity, delta)
			entity.on_update(delta)
	
	if did_run:
		# Log the whole thing
		_log_handle(entities, q)


func _log_handle(entities, q):
	Loggie.msg("""
[%s]
  -> Query: %s
  -> Entities: %s
""" % [self, self.query(), entities]).domain('ecs').debug()
