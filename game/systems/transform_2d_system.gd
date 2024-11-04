# The transform system handles all the position, rotation and scale changes
class_name Transform2DSystem
extends System

func _init():
	required_components = [Transform]


func process(entity: Entity, delta):
	var transform: Transform = entity.get_component(Transform)
	entity.position = transform.position
	entity.rotation = transform.rotation
	entity.scale = transform.scale

