# meta-description: A query-driven reactive node. Override query() + each() or sub_observers().
class_name _CLASS_
extends Observer


## The observer's reactive spec. Return a QueryBuilder with on_* event modifiers chained on.
## Omit / return null if using sub_observers() exclusively.
func query() -> QueryBuilder:
	return q.with_all([Component]).on_added().on_removed()


## Unified callback. Fires for every event declared on query().
## `event` is an Observer.Event value or a StringName for custom events.
## `payload` depends on event type — see Observer class docs.
## Full event set: ADDED / REMOVED / CHANGED / MATCH / UNMATCH /
## RELATIONSHIP_ADDED / RELATIONSHIP_REMOVED / <StringName for custom events>.
func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	match event:
		Observer.Event.ADDED:
			pass
		Observer.Event.REMOVED:
			pass


# Optional: compose multiple reactive axes in one node (mirrors sub_systems).
# Each tuple: [QueryBuilder with events, Callable(event, entity, payload)]
#
# func sub_observers() -> Array[Array]:
# 	return [
# 		[q.with_all([Component]).on_match().on_unmatch(), _on_match_state],
# 		[q.with_all([Component]).on_event(&"custom_event"), _on_custom_event],
# 	]
#
# func _on_match_state(event, entity, _payload):
# 	pass
#
# func _on_custom_event(event, entity, data):
# 	pass


# Optional lifecycle hook — called once after the observer is added to the World.
# func setup() -> void:
# 	pass
