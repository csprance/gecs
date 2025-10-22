## Observer that watches relationships
class_name O_RelationshipObserver
extends Observer

# Note: Observers don't currently have relationship_added/removed callbacks
# This is a placeholder for when relationship observing is implemented
var relationship_events: Array = []

func watch() -> Resource:
	return C_ObserverTest

func match() -> QueryBuilder:
	return q.with_all([C_ObserverTest])

func reset() -> void:
	relationship_events.clear()
