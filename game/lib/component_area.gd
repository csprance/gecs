## ComponentArea3D manages the addition and removal of components for entities 
## or a parent entity entering or exiting the area.
class_name ComponentArea3D
extends Area3D

## When an entity enters the area
signal entity_entered(entity:Entity, parent:Entity)
## When an entity exits the area
signal entity_exited(entity:Entity, parent:Entity)

@export_group("Parent")
## What entity this hitbox belongs to
@export var parent: Entity

@export_group("Parent Components")
# What components should we add/remove to the PARENT Entity on Entering the Line of Sight
@export_subgroup("On Enter")
@export var parent_add_on_entered: Array[Component] = []
@export var parent_remove_on_entered: Array[Component] = []
@export_subgroup("On Exit")
@export var parent_add_on_exit: Array[Component] = []
@export var parent_remove_on_exit: Array[Component] = []

@export_group("Body Components")
# What components should we add/remove to the BODY Entity on Entering the Line of Sight
@export_subgroup("On Enter")
@export var body_add_on_entered: Array[Component] = []
@export var body_remove_on_entered: Array[Component] = []
@export_subgroup("On Exit")
@export var body_add_on_exit: Array[Component] = []
@export var body_remove_on_exit: Array[Component] = []


## Override this function to check if the body should be added
func enter_check(_body_rid:RID, _body, _body_shape_index:int, _local_shape_index:int) -> bool:
	return true

## Override this function to check if the body should be removed
func exit_check(_body_rid:RID, _body, _body_shape_index:int, _local_shape_index:int) -> bool:
	return true

func _ready() -> void:
	body_shape_entered.connect(_on_area_entered)
	body_shape_exited.connect(_on_area_exited)

func _on_area_entered(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body == parent:
		return
	if body is Entity and enter_check(_body_rid, body, _body_shape_index, _local_shape_index):
		# Body is within angle and has line of sight
		entity_entered.emit(body, parent)
		body.add_components(body_add_on_entered)
		body.remove_components(body_remove_on_entered)
		parent.add_components(parent_add_on_entered)
		parent.remove_components(parent_remove_on_entered)


func _on_area_exited(_body_rid:RID, body, _body_shape_index:int, _local_shape_index:int) -> void:
	if body == parent:
		return
	if body is Entity and exit_check(_body_rid, body, _body_shape_index, _local_shape_index):
		entity_exited.emit(body, parent)
		body.add_components(body_add_on_exit)
		body.remove_components(body_remove_on_exit)
		parent.add_components(parent_add_on_exit)
		parent.remove_components(parent_remove_on_exit)


