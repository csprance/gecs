## GECSTracker: run a computation and learn its ECS data dependencies.
##
## [method track] evaluates a [Callable] with lightweight instrumentation
## enabled on [method QueryBuilder.execute] and
## [method Entity.get_component] / [method Entity.has_component], and reports
## every query executed and every component type read, no matter how deep in
## helper code the access happened.[br]
## [br]
## This is a general observability primitive. Typical uses:[br]
## - [b]Reactive derivations[/b]: derive a value from the world, subscribe an
##   [Observer] to exactly the reported dependencies, re-derive on change.[br]
## - [b]Cache invalidation[/b]: memoize an expensive derivation and invalidate
##   when any dependency mutates.[br]
## - [b]Tooling[/b]: audit what a function actually touches.[br]
## [br]
## Cost: while inactive (the default), the instrumentation is a single static
## bool branch on the hot paths. While a tracked call runs, each query
## execution and component read additionally invokes one static callback.
## Tracking is not re-entrant: calls to [method track] must not nest.[br]
## [b]Example:[/b]
## [codeblock]
## var deps := GECSTracker.track(func(): return _derive_hud_state())
## # deps.result  -> the callable's return value
## # deps.queries -> Array[QueryBuilder] executed during the call
## # deps.reads   -> Array[Script] component types read during the call
## [/codeblock]
class_name GECSTracker
extends RefCounted

static var _builders: Array = []
static var _reads: Dictionary = {}


## Evaluate [param fn] with dependency instrumentation enabled. Returns
## [code]{result, queries: Array[QueryBuilder], reads: Array[Script]}[/code].
## Queries are the builder instances that executed (deduplicated by instance);
## reads are the component Scripts passed to get_component / has_component
## (deduplicated by type).
static func track(fn: Callable) -> Dictionary:
	_builders = []
	_reads = {}
	QueryBuilder.set_execute_tracker(_on_query_executed)
	Entity.set_read_tracker(_on_component_read)
	var result: Variant = fn.call()
	QueryBuilder.set_execute_tracker(Callable())
	Entity.set_read_tracker(Callable())
	return {result = result, queries = _builders, reads = _reads.keys()}


static func _on_query_executed(builder) -> void:
	if not _builders.has(builder):
		_builders.append(builder)


static func _on_component_read(component) -> void:
	# get_component/has_component accept a Script or a component instance;
	# normalize to the Script so reads deduplicate per component type.
	var script = component if component is Script else component.get_script()
	if script:
		_reads[script] = true
