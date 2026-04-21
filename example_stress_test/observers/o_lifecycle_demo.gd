## Observer demo — showcases every major Observer feature via sub_observers():
##   1. on_added  → fires when C_Lifetime is added (an entity is spawned)
##   2. on_removed → fires when C_Lifetime is removed (an entity is despawned)
##   3. on_match/on_unmatch → query monitor for entities that are simultaneously
##      moving (C_Velocity) AND flagged special (C_IsSpecial). Fires exactly once
##      on entry/exit of that combined state.
##   4. on_event(&"milestone") + world.emit_event(...) → custom user events
##
## The observer also demonstrates using [member Observer.cmd] to queue structural
## changes safely from a callback — here, randomly flagging ~10% of spawns with
## C_IsSpecial to drive the monitor transitions.
class_name O_LifecycleDemo
extends Observer

var spawn_count: int = 0
var despawn_count: int = 0
var currently_special: int = 0

const MILESTONE_EVERY := 50
const SPECIAL_CHANCE := 0.10


func sub_observers() -> Array[Array]:
	return [
		# 1. Spawn counter: C_Lifetime is added to every spawned entity.
		[q.with_all([C_Lifetime]).on_added(), _on_spawn],
		# 2. Despawn counter: C_Lifetime is removed when the entity is destroyed.
		[q.with_all([C_Lifetime]).on_removed(), _on_despawn],
		# 3. Query monitor: moving AND special → transitional on_match / on_unmatch.
		[q.with_all([C_Velocity, C_IsSpecial]).on_match().on_unmatch(), _on_special_state],
		# 4. Custom event: listen for milestones emitted by this observer itself.
		[q.on_event(&"milestone"), _on_milestone],
	]


func _on_spawn(_event: Variant, entity: Entity, _payload: Variant) -> void:
	spawn_count += 1
	# Demo: queue a structural change from inside an observer callback. ~10% of
	# newly spawned entities gain C_IsSpecial, which will make them transition into
	# the monitor query on the next frame.
	if randf() < SPECIAL_CHANCE:
		cmd.add_component(entity, C_IsSpecial.new())
	# Demo: emit a custom event every N spawns. The _on_milestone sub-observer below
	# picks it up — showing event round-trip within a single Observer node.
	if spawn_count % MILESTONE_EVERY == 0:
		ECS.world.emit_event(&"milestone", entity, {"count": spawn_count})


func _on_despawn(_event: Variant, _entity: Entity, _payload: Variant) -> void:
	despawn_count += 1


func _on_special_state(event: Variant, _entity: Entity, _payload: Variant) -> void:
	match event:
		Observer.Event.MATCH:
			currently_special += 1
		Observer.Event.UNMATCH:
			currently_special -= 1


func _on_milestone(_event: Variant, _entity: Entity, data: Variant) -> void:
	print(
		"[observer-demo] spawned=%d  despawned=%d  special-now=%d"
		% [data.count, despawn_count, currently_special]
	)
