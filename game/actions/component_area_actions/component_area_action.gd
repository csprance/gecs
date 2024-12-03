class_name ComponentAreaAction
extends Action


func execute(_e) -> void:
    assert(false, 'You should instead run the on_enter or on_exit functions for a ComponentAreaAction')

func _run_on_(enter:bool, parent: Entity, body: Entity, body_rid: RID, body_shape_index: int, local_shape_index: int) -> void:
    var _body = query().matches([body])
    if _body.is_empty():
        return
    if enter:
        on_enter(parent, _body[0], body_rid, body_shape_index, local_shape_index)
    else:
        on_exit(parent, _body[0], body_rid, body_shape_index, local_shape_index)

func on_enter(parent: Entity, body: Entity, body_rid: RID, body_shape_index: int, local_shape_index: int) -> void:
    pass


func on_exit(parent: Entity, body: Entity, body_rid: RID, body_shape_index: int, local_shape_index: int) -> void:
    pass