## Verify `setup()` is called
class_name SetupTestSystem
extends System

var setup_was_called := false


func setup():
	setup_was_called = true


func query():
	process_empty = true
	return ECS.world.query


func process(_entities: Array[Entity], _components: Array, _delta: float):
	pass
