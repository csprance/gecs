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
	if item_resource or weapon_resource:
		var resource = item_resource if item_resource else weapon_resource
		if not resource.visuals:
			return
		# Remove spawn cone
		spawn_cone.visible = false
		var visuals = resource.visuals.packed_scene.instantiate()
		# make the visuals on the ground a little bigger than normal
		visuals.scale *= Vector3(2, 2, 2)
		add_child(visuals)

func _on_area_3d_body_shape_entered(body_rid:RID, body, body_shape_index:int, local_shape_index:int) -> void:
	if body is Player:
		add_component(C_PickedUp.new())

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_show_visuals()
