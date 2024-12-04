## ComponentArea3D manages the addition and removal of components for entities 
## or a parent entity entering or exiting the area.
class_name ComponentArea3D
extends Area3D

## When an entity enters the area
signal entity_entered(entity:Entity, parent:Entity)
## When an entity exits the area
signal entity_exited(entity:Entity, parent:Entity)

## What entity this component area belongs to
@export var parent: Entity

## Do we need to match the query to run the actions? Defaults to false because actions can handle the query as well if needed. This makes it easier.
@export var query_match_to_run_actions = false
## Actions to run when an entity enters or exits the area (that isn't the parent entering/exiting itself?)
@export var actions: Array[ComponentAreaAction]


@export_group("Query")
## This component area is triggered by entities that match all the components here
@export var query_with_all: Array[Component] = []
## This component area is triggered by entities that match any of the components here
@export var query_with_any: Array[Component] = []
## This component area is triggered by entities that match none of the components here
@export var query_with_none: Array[Component] = []

@export_group("Components")
## Do we need to match the query to add/remove components? Default is true
@export var query_match_for_components = true
@export_subgroup("Parent Components")
# What components should we add/remove to the PARENT Entity on Entering the Line of Sight
@export_subgroup("On Enter")
@export var parent_add_on_entered: Array[Component] = []
@export var parent_remove_on_entered: Array[Component] = []
@export_subgroup("On Exit")
@export var parent_add_on_exit: Array[Component] = []
@export var parent_remove_on_exit: Array[Component] = []

@export_subgroup("Body Components")
# What components should we add/remove to the BODY Entity on Entering the Line of Sight
@export_subgroup("On Enter")
@export var body_add_on_entered: Array[Component] = []
@export var body_remove_on_entered: Array[Component] = []
@export_subgroup("On Exit")
@export var body_add_on_exit: Array[Component] = []
@export var body_remove_on_exit: Array[Component] = []


## Override this function to check if the body should be added. This is helpful for things that extend from
## ComponentArea3D and want to add additional checks like [LineOfSight3D]
func enter_check(_body_rid:RID, _body, _body_shape_index:int, _local_shape_index:int) -> bool:
	return true

## Override this function to check if the body should be removed
func exit_check(_body_rid:RID, _body, _body_shape_index:int, _local_shape_index:int) -> bool:
	return true

func _ready() -> void:
	body_shape_entered.connect(_on_area_entered)
	body_shape_exited.connect(_on_area_exited)

func _on_area_entered(body_rid:RID, body, body_shape_index:int, local_shape_index:int) -> void:
	# We're only interested in entities and not if it's the parent and if it passes the enter check
	if body == parent or not body is Entity:
		return
	if not enter_check(body_rid, body, body_shape_index, local_shape_index):
		return
	_run_on_enter(body, body_rid, body_shape_index, local_shape_index)

func _run_on_enter(body: Entity, body_rid: RID, body_shape_index: int, local_shape_index: int) -> void:
	# Add components to the body and parent and emit the signal
	entity_entered.emit(body, parent)
	body.add_components(body_add_on_entered.map(func(x): return x.duplicate()))
	body.remove_components(body_remove_on_entered.map(func(x): return x.get_script()))
	parent.add_components(parent_add_on_entered.map(func(x): return x.duplicate()))
	parent.remove_components(parent_remove_on_entered.map(func(x): return x.get_script()))

	for action in actions:
		action._run_on_(true, parent, body, body_rid, body_shape_index, local_shape_index)

func _on_area_exited(body_rid:RID, body, body_shape_index:int, local_shape_index:int) -> void:
	# We're only interested in entities and not if it's the parent and if it passes the exit check
	if body == parent or not body is Entity:
		return
	if not exit_check(body_rid, body, body_shape_index, local_shape_index):
		return
	_run_on_exit(body, body_rid, body_shape_index, local_shape_index)

func _run_on_exit(body: Entity, body_rid: RID, body_shape_index: int, local_shape_index: int) -> void:
	entity_exited.emit(body, parent)
	body.add_components(body_add_on_exit.map(func(x): return x.duplicate()))
	body.remove_components(body_remove_on_exit.map(func(x): return x.get_script()))
	parent.add_components(parent_add_on_exit.map(func(x): return x.duplicate()))
	parent.remove_components(parent_remove_on_exit.map(func(x): return x.get_script()))
	
	for action in actions:
		action._run_on_(false, parent, body, body_rid, body_shape_index, local_shape_index)
