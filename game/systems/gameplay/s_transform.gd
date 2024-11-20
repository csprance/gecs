## TransformSystem.
##
## Synchronizes the `Transform` component with the entity's actual transform in the scene.
## Updates the entity's position, rotation, and scale based on the `Transform` component.
## Processes entities with the `Transform` component.
class_name TransformSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Transform])


func process(entity: Entity, _delta):
	var transform: C_Transform = entity.get_component(C_Transform) as C_Transform
	entity.global_transform = transform.transform

