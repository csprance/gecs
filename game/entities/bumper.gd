## Bumper Entity.
##
## Represents a bumper that entities can collide with
## When another entity enters its area, it adds any number of components specified to the entity
## Used to define boundaries or obstacles in the game or kill zones
class_name Bumper
extends Entity

@export var components_to_add: Array[Component] = []

func on_ready() -> void:
	Utils.sync_transform(self)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Entity:
		var entity  = body as Entity
		for comp in components_to_add:
			entity.add_component(comp)
