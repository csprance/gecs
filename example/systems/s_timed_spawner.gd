## TimedSpawnerSystem
##
## Example system demonstrating tick source usage.
## This system spawns entities at a fixed interval (every 2 seconds) instead of every frame.
##
## To use this system:
## 1. Register the tick source in your world setup (e.g., in World's _ready or autoload):
##    ECS.world.create_interval_tick_source(2.0, 'spawner-tick')
##
## 2. Add this system to your world
##
## 3. The system will only run every 2 seconds instead of every frame
class_name TimedSpawnerSystem
extends System

@export var entity_scene: PackedScene

var spawn_count: int = 0


## Override tick() to specify which tick source to use
func tick() -> TickSource:
	return ECS.world.get_tick_source('spawner-tick')


## This process method now only runs when the tick source ticks (every 2 seconds)
## The delta value will be the tick source's delta (2.0 for IntervalTickSource)
func process(_entities: Array[Entity], _components: Array, delta: float) -> void:
	if not entity_scene:
		return

	spawn_count += 1
	print("TimedSpawner: Spawning entity #%d (delta: %.2f)" % [spawn_count, delta])

	call_deferred('_spawn_entity')


func _spawn_entity():
	if entity_scene:
		var entity = entity_scene.instantiate() as Entity
		ECS.world.add_entity(entity)
