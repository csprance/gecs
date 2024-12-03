## TransformSystem.
##
## Synchronizes the `Transform` component with the entity's actual transform in the scene.
## Updates the entity's position, rotation, and scale based on the `Transform` component.
## Processes entities with the `Transform` component.
class_name TransformSystem
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Transform])

func process_all(entities: Array, _delta):
	var transforms = ECS.get_components(entities, C_Transform) as Array[C_Transform]
	for i in range(entities.size()):
		entities[i].global_transform = transforms[i].transform

