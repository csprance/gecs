## CommandBuffer
##
## Queues structural changes (add/remove components, entities, relationships) for deferred execution.[br]
## Enables safe iteration by batching operations and executing them after system processing completes.[br]
## User-visible events (signals, observer callbacks, monitor transitions) fire in the exact order
## commands were queued; archetype moves are coalesced to ONE transition per touched entity.[br]
##
## [b]Problem it solves:[/b]
## - Eliminates need for backwards iteration during entity removal
## - Removes defensive snapshot overhead (O(N) memory)
## - Coalesces per-entity archetype moves: a remove+add state transition is ONE move, not two
##
## [b]Example Usage:[/b]
##[codeblock]
##     func process(entities: Array[Entity], components: Array, delta: float) -> void:
##         for entity in entities:
##             if should_delete(entity):
##                 cmd.remove_entity(entity)  # Queued for later
##             if should_transform(entity):
##                 cmd.remove_component(entity, C_OldState)
##                 cmd.add_component(entity, C_NewState.new())
##         # Auto-executes after system completes (based on flush mode)
##[/codeblock]
class_name CommandBuffer
extends RefCounted

## Op codes for queued commands. Records are packed flat into _ops as
## [op, entity, a, b] quads — cheaper to queue than a capturing lambda.
enum {
	OP_ADD_COMPONENT,
	OP_REMOVE_COMPONENT,
	OP_ADD_COMPONENTS,
	OP_REMOVE_COMPONENTS,
	OP_ADD_ENTITY,
	OP_REMOVE_ENTITY,
	OP_ADD_RELATIONSHIP,
	OP_REMOVE_RELATIONSHIP,
	OP_CUSTOM,
}

## Flat op-record storage: [op_code, entity, a, b] repeated. See enum for slot meanings.
var _ops: Array = []

## Reference to the world for executing commands
var _world: World = null

## Statistics for debugging (optional)
var _stats := {
	"commands_queued": 0,
	"commands_executed": 0,
	"last_execution_time_ms": 0.0,
}


func _init(world: World = null):
	_world = world if world else ECS.world


## Queue adding a component to an entity
func add_component(entity: Entity, component: Resource) -> void:
	_ops.append(OP_ADD_COMPONENT)
	_ops.append(entity)
	_ops.append(component)
	_ops.append(null)
	_stats["commands_queued"] += 1


## Queue removing a component from an entity
func remove_component(entity: Entity, component_type: Variant) -> void:
	_ops.append(OP_REMOVE_COMPONENT)
	_ops.append(entity)
	_ops.append(component_type)
	_ops.append(null)
	_stats["commands_queued"] += 1


## Queue adding multiple components to an entity (batched per-entity)
func add_components(entity: Entity, components: Array) -> void:
	_ops.append(OP_ADD_COMPONENTS)
	_ops.append(entity)
	_ops.append(components)
	_ops.append(null)
	_stats["commands_queued"] += 1


## Queue removing multiple components from an entity (batched per-entity)
func remove_components(entity: Entity, component_types: Array) -> void:
	_ops.append(OP_REMOVE_COMPONENTS)
	_ops.append(entity)
	_ops.append(component_types)
	_ops.append(null)
	_stats["commands_queued"] += 1


## Queue adding an entity to the world
func add_entity(entity: Entity) -> void:
	_ops.append(OP_ADD_ENTITY)
	_ops.append(entity)
	_ops.append(null)
	_ops.append(null)
	_stats["commands_queued"] += 1


## Queue removing an entity from the world
func remove_entity(entity: Entity) -> void:
	_ops.append(OP_REMOVE_ENTITY)
	_ops.append(entity)
	_ops.append(null)
	_ops.append(null)
	_stats["commands_queued"] += 1


## Queue adding a relationship to an entity
func add_relationship(entity: Entity, relationship: Relationship) -> void:
	_ops.append(OP_ADD_RELATIONSHIP)
	_ops.append(entity)
	_ops.append(relationship)
	_ops.append(null)
	_stats["commands_queued"] += 1


## Queue removing a relationship from an entity
func remove_relationship(entity: Entity, relationship: Relationship, limit: int = -1) -> void:
	_ops.append(OP_REMOVE_RELATIONSHIP)
	_ops.append(entity)
	_ops.append(relationship)
	_ops.append(limit)
	_stats["commands_queued"] += 1


## Queue a custom operation (for complex multi-step operations)
## The callable should take no parameters and perform the desired operation
func add_custom(callable: Callable) -> void:
	_ops.append(OP_CUSTOM)
	_ops.append(null)
	_ops.append(callable)
	_ops.append(null)
	_stats["commands_queued"] += 1


## Execute all queued commands in the order they were queued.[br]
## Signals/observers fire per-op in queued order; archetype moves are deferred
## and coalesced to a single transition per touched entity (committed at the end,
## or just-in-time before an entity add/remove op needs consistent state).
## Cache invalidation is deferred until all commands complete.
func execute() -> void:
	if _ops.is_empty():
		return

	var start_time := Time.get_ticks_usec()

	# Take ownership of the current queue before iterating. A queued command may
	# synchronously trigger observer dispatch (PER_CALLBACK flush reads
	# `has_pending_commands()`); if `_ops` still held this batch, the reentrant
	# `execute()` would re-run the same records and recurse infinitely. Commands
	# queued during iteration land in a fresh `_ops` and are flushed by the next
	# `execute()` call.
	var to_run: Array = _ops
	_ops = []

	# Suppress cache invalidation during batch execution; _end_suppress fires once at end.
	# Force _pending_invalidation so _end_suppress always fires exactly one membership
	# bump — commands always mutate state, so caches must always be notified after execute().
	_world._begin_suppress()
	_world._pending_invalidation = true
	# Defer archetype moves: world handlers queue touched entities instead of moving
	# them per-op. _end_deferred_moves() commits one transition per touched entity.
	var owns_deferral := _world._begin_deferred_moves()

	var i := 0
	var n := to_run.size()
	while i < n:
		var op: int = to_run[i]
		var entity = to_run[i + 1]
		var a = to_run[i + 2]
		var b = to_run[i + 3]
		i += 4
		match op:
			OP_ADD_COMPONENT:
				if is_instance_valid(entity):
					entity.add_component(a)
			OP_REMOVE_COMPONENT:
				if is_instance_valid(entity):
					entity.remove_component(a)
			OP_ADD_COMPONENTS:
				if is_instance_valid(entity):
					entity.add_components(a)
			OP_REMOVE_COMPONENTS:
				if is_instance_valid(entity):
					entity.remove_components(a)
			OP_ADD_ENTITY:
				if is_instance_valid(entity):
					_world.add_entity(entity)
			OP_REMOVE_ENTITY:
				if is_instance_valid(entity):
					# Commit any pending move first so removal sees consistent archetype state.
					_world._commit_deferred_move(entity)
					_world.remove_entity(entity)
			OP_ADD_RELATIONSHIP:
				if is_instance_valid(entity):
					entity.add_relationship(a)
			OP_REMOVE_RELATIONSHIP:
				if is_instance_valid(entity):
					entity.remove_relationship(a, b)
			OP_CUSTOM:
				a.call()

	if owns_deferral:
		_world._end_deferred_moves()
	_world._end_suppress()

	# Update statistics
	_stats["commands_executed"] += to_run.size() / 4
	_stats["last_execution_time_ms"] = (Time.get_ticks_usec() - start_time) / 1000.0


## Clear all queued commands without executing them
func clear() -> void:
	_ops.clear()


## Check if there are any queued commands
func is_empty() -> bool:
	return _ops.is_empty()


## Get the number of queued commands
func size() -> int:
	return _ops.size() / 4


## Get statistics for debugging (only useful when commands have been executed)
func get_stats() -> Dictionary:
	return _stats.duplicate()
