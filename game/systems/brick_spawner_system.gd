## BrickSpawnerSystem
##
## A brick spawner system spawns bricks and then deletes itself
class_name BrickSpawnerSystem
extends System

@export var NUM_BRICKS:= 0
var brick_scene = preload('res://game/entities/brick.tscn')

func _init():
	# We want this system to run even with no components
	process_empty = true

func process(entity, delta):
	var world = ECS.world as World
	spawn_bricks(world)
	# Remove this system so it only runs once
	world.remove_system(self)

func spawn_bricks(world: World):
	for num in range(NUM_BRICKS):
		# Create a brick get it's transform component and set it
		var brick_entity = brick_scene.instantiate() as Brick
		# Add the entity to the world then modify it's components (Otherwise components won't be ready yet)
		world.add_entity(brick_entity)
		# Get and modify transform Component
		var trs = brick_entity.get_component(Transform) as Transform
		trs.position = Vector2(100 * num, 500 )
