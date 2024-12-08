class_name ActionPickerAreaAction
extends ComponentAreaAction

## The actions to pick from on exit
@export var exit_actions: ActionPicker
## The actions to pick from on enter
@export var enter_actions: ActionPicker


# Start attacking the body if we get in the attack area
func _on_enter(victim: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	if not enter_actions:
		return
	for action in enter_actions.pick_action():
		await action.run_on_(true, victim, body, _body_rid, _body_shape_index, _local_shape_index)		


# Stop attacking the body if we get out of the attack area
func _on_exit(parent: Entity, body: Entity, _body_rid: RID, _body_shape_index: int, _local_shape_index: int) -> void:
	if not exit_actions:
		return
	for action in exit_actions.pick_action():
		await action.run_on_(false, parent, body, _body_rid, _body_shape_index, _local_shape_index)
