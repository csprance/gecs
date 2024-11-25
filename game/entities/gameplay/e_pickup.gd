@tool
class_name Pickup
extends Entity

## Everything needs an item
@export var item_resource: C_Item
## IF it's a weapon it also gets a weapon resource
@export var weapon_resource: C_Weapon
## How many of the item are there
@export var quantity: int = 1

@onready var spawn_cone: MeshInstance3D = $SpawnCone

func on_ready() -> void:
	_show_visuals()
	# we probably want to sync the component transform to the node transform
	Utils.sync_transform(self)

func _show_visuals():
	if item_resource:
		# Remove spawn cone
		spawn_cone.visible = false
		var visuals = item_resource.visuals.instantiate()
		add_child(visuals)

func _on_area_3d_body_shape_entered(body_rid:RID, body, body_shape_index:int, local_shape_index:int) -> void:
	if body is Player:
		add_component(C_PickedUp.new())

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_show_visuals()
