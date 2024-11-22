@tool
class_name Pickup
extends Entity

@export var item_resource: C_Item

@onready var spawn_cone: MeshInstance3D = $SpawnCone

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		show_visuals()

func on_ready() -> void:
	show_visuals()
	# we probably want to sync the component transform to the node transform
	Utils.sync_transform(self)
	
func show_visuals():
	if item_resource:
		# Remove spawn cone
		spawn_cone.visible = false
		var visuals = item_resource.visuals.instantiate()
		add_child(visuals)


func _on_area_3d_body_shape_entered(body_rid:RID, body, body_shape_index:int, local_shape_index:int) -> void:
	if body is Player:
		add_component(C_PickedUp.new())
