## ComponentAreaAction are like Actions but they are meant to be used with ComponentArea. They are meant to be used with the on_enter and on_exit functions.
class_name ComponentAreaAction
extends Action

## Override this function with your on enter action
func _on_enter(parent: Entity, body: Entity, body_rid: RID, body_shape_index: int, local_shape_index: int) -> void:
	print('on_enter: ', [ parent, body, body_rid, body_shape_index, local_shape_index])
   

## Override this function with your on exit action
func _on_exit(parent: Entity, body: Entity, body_rid: RID, body_shape_index: int, local_shape_index: int) -> void:
	print('on_exit: ', [ parent, body, body_rid, body_shape_index, local_shape_index])


## Helper function to run on exit or enter and handle the query matching and running the action
func run_on_(enter:bool, parent: Entity, body: Entity, body_rid: RID, body_shape_index: int, local_shape_index: int) -> void:
	var _body = query().matches([body])
	if _body.is_empty():
		return
	if enter:
		_on_enter(parent, _body[0], body_rid, body_shape_index, local_shape_index)
	else:
		_on_exit(parent, _body[0], body_rid, body_shape_index, local_shape_index)


func run_action(_e=[], _m=[]) -> void:
	assert(false, 'You should instead run the on_enter or on_exit functions for a ComponentAreaAction')
