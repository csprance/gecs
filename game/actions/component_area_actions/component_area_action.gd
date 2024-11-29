class_name ComponentAreaAction
extends Action


func execute() -> void:
    assert(false, 'You should instead run the on_enter or on_exit functions for a ComponentAreaAction')


func on_enter(parent: Entity, body: Entity, body_rid: RID, body_shape_index: int, local_shape_index: int) -> void:
    pass


func on_exit(parent: Entity, body: Entity, body_rid: RID, body_shape_index: int, local_shape_index: int) -> void:
    pass