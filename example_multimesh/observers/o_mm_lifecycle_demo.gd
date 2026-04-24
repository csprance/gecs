## MultiMesh example observer demo — same reactive axes as the simple example's
## O_LifecycleDemo, renamed to avoid class_name collision between example projects.
##
## Showcases:
##   1. on_added C_Lifetime  → spawn counter
##   2. on_removed C_Lifetime → despawn counter
##   3. on_match/on_unmatch  → monitor for entities that are both moving (C_Velocity)
##      and have a transform (C_Transform). Demonstrates query-membership transitions.
##   4. on_event(&"mm_milestone") + world.emit_event(...) → custom user events
##
## Also demonstrates using [member Observer.cmd] to queue structural changes from a callback.
class_name O_MMLifecycleDemo
extends Observer

var spawn_count: int = 0
var despawn_count: int = 0
var currently_tracked: int = 0

const MILESTONE_EVERY := 250


func sub_observers() -> Array[Array]:
	return [
		[q.with_all([C_Lifetime]).on_added(), _on_spawn],
		[q.with_all([C_Lifetime]).on_removed(), _on_despawn],
		# Monitor: entities that are both moving AND positioned.
		[q.with_all([C_Velocity, C_Transform]).on_match().on_unmatch(), _on_tracked_state],
		[q.on_event(&"mm_milestone"), _on_milestone],
	]


func _on_spawn(_event: Variant, entity: Entity, _payload: Variant) -> void:
	spawn_count += 1
	if spawn_count % MILESTONE_EVERY == 0:
		ECS.world.emit_event(&"mm_milestone", entity, {"count": spawn_count})


func _on_despawn(_event: Variant, _entity: Entity, _payload: Variant) -> void:
	despawn_count += 1


func _on_tracked_state(event: Variant, _entity: Entity, _payload: Variant) -> void:
	match event:
		Observer.Event.MATCH:
			currently_tracked += 1
		Observer.Event.UNMATCH:
			currently_tracked -= 1


func _on_milestone(_event: Variant, _entity: Entity, data: Variant) -> void:
	print(
		(
			"[mm-observer-demo] spawned=%d  despawned=%d  tracked-now=%d"
			% [data.count, despawn_count, currently_tracked]
		)
	)
