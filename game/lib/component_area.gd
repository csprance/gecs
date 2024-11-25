## ComponentArea3D manages the addition and removal of components for entities 
## or a parent entity entering or exiting the area.
class_name ComponentArea3D
extends Node3D

signal entity_entered(entity:Entity, parent_entity:Entity)
signal entity_exited(entity:Entity, parent_entity:Entity)

## What entity is this attached to
@export var parent_entity : Entity
## Any components you want to add to an entity as it enters the area
@export var parent_on_enter : Array[Component] = []
## Any component you want to remove from an entity as it leaves the area
@export var parent_on_exit : Array[Component] = []
## Any components you want to add to an entity as it enters the area
@export var body_on_enter : Array[Component] = []
## Any component you want to remove from an entity as it leaves the area
@export var body_on_exit : Array[Component] = []


func _on_area_body_shape_exited(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	# if we hit the parent ignore it
	if body == parent_entity:
		return
	if parent_entity is Entity:
		for component in parent_on_exit:
			parent_entity.remove_component(component)

	if body is Entity:
		for component in body_on_exit:
			body.remove_component(component)
		entity_exited.emit(body, parent_entity)

func _on_area_body_shape_entered(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body == parent_entity:
		return
	if parent_entity is Entity:
		for component in parent_on_enter:
			parent_entity.add_component(component)

	if body is Entity:
		for component in body_on_enter:
			body.add_component(component)
		entity_entered.emit(body, parent_entity)