class_name S_NetworkProjectile
extends System
## Projectile movement system - moves projectiles and handles cleanup.
## Runs on ALL clients (local simulation after spawn-only sync).

const LIFETIME := 3.0  # Seconds before projectile is removed
const ARENA_BOUND := 10.0  # Remove if outside this bound

var _lifetime_tracker: Dictionary = {}  # entity_id -> time_alive


func query() -> QueryBuilder:
	return q.with_all([C_Projectile, C_NetVelocity]).iterate([C_NetVelocity])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var velocities = components[0]

	for i in entities.size():
		var entity = entities[i]
		var velocity = velocities[i] as C_NetVelocity

		# Move projectile
		if entity is Node3D:
			entity.global_position += velocity.direction * delta

		# Track lifetime
		var lifetime = _lifetime_tracker.get(entity.id, 0.0)
		lifetime += delta
		_lifetime_tracker[entity.id] = lifetime

		# Check if should be removed
		var should_remove = lifetime > LIFETIME
		if entity is Node3D:
			var pos = entity.global_position
			should_remove = should_remove or abs(pos.x) > ARENA_BOUND or abs(pos.z) > ARENA_BOUND

		if should_remove:
			_lifetime_tracker.erase(entity.id)
			cmd.remove_entity(entity)
			cmd.add_custom(entity.queue_free)
