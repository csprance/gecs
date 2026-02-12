class_name RandomSpawnerSystem
extends System

@export var random_mover_scene: PackedScene

func _init():
	# Use PER_GROUP flush mode - spawns will be visible to other systems next frame
	command_buffer_flush_mode = "PER_GROUP"


func process(_es: Array, _cs: Array, _d: float):
	# Use CommandBuffer instead of call_deferred
	var entitya = random_mover_scene.instantiate() as Entity
	entitya.color = Color(randf(), randf(), randf())

	# Queue entity addition - will be executed at end of process group
	cmd.add_entity(entitya)

	# Queue relationship addition
	if ECS.world.entities.size() % 3 == 0:
		cmd.add_relationship(entitya, Relationship.new(C_IsSpecial.new()))
