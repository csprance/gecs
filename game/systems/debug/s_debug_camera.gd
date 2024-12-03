class_name DebugCameraSystem
extends System


func query() -> QueryBuilder:
	# process_empty = false # Do we want this to run every frame even with no entities?
	return q.with_all([C_Camera, C_DebugCamera]) # return the query here
	

func process(entity: Entity, delta: float) -> void:
	if Input.is_action_just_pressed('debug_camera_toggle'):
		print('Debug Camera Toggle')
		