class_name SimpleLifetimeSystem
extends System

## How often to check lifetimes. 10Hz granularity is imperceptible for entities
## that live 1–10s and cuts per-frame iteration cost ~6× vs running every frame.
@export var check_rate_seconds: float = 0.1


func setup():
	safe_iteration = false
	set_tick_rate(check_rate_seconds)


func query() -> QueryBuilder:
	return q.with_all([C_Lifetime]).iterate([C_Lifetime])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	# tick_source.interval is the actual time between invocations; frame delta
	# is still ~0.016s and would make lifetimes decay 6× too slow.
	var tick_delta: float = tick_source.interval
	var lifetimes = components[0]
	for i in range(entities.size()):
		var c_lifetime = lifetimes[i]
		if c_lifetime != null:
			c_lifetime.lifetime -= tick_delta
			if c_lifetime.lifetime <= 0.0:
				cmd.remove_entity(entities[i])
