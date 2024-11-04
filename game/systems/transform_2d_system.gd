## Transform2DSystem.
##
## Synchronizes the `Transform` component with the entity's actual transform in the scene.
## Updates the entity's position, rotation, and scale based on the `Transform` component.
## Processes entities with the `Transform` component.
class_name Transform2DSystem
extends System

func _init():
	required_components = [Transform]


func process(entity: Entity, delta):
	var transform: Transform = entity.get_component(Transform)
	entity.position = transform.position
	entity.rotation = transform.rotation
	entity.scale = transform.scale

