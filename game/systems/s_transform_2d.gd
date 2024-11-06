## Transform2DSystem.
##
## Synchronizes the `Transform` component with the entity's actual transform in the scene.
## Updates the entity's position, rotation, and scale based on the `Transform` component.
## Processes entities with the `Transform` component.
class_name Transform2DSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([Transform])


func process(entity: Entity, _delta):
	var transform: Transform = entity.get_component(Transform)
	# print('Set Entity: ', entity,' Set Position: ', transform.position)
	entity.position = transform.position
	entity.rotation = transform.rotation
	entity.scale = transform.scale

