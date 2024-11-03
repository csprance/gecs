class_name Bumper
extends Entity2D


func on_start() -> void:
	Utils.sync_transform_2d(self)

func _on_area_2d_body_entered(body: Node2D) -> void:
	print(body)


func _on_area_2d_area_entered(area: Area2D) -> void:
	print(area) # Replace with function body.


func _on_area_2d_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	print('') # Replace with function body.


func _on_area_2d_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	print('') # Replace with function body.
