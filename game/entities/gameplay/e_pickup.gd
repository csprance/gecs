class_name Pickup
extends Entity

@export var item_resource: C_Item

func on_ready() -> void:
	# we probably want to sync the component transform to the node transform
	Utils.sync_transform(self)
	
func show_visuals():
	var visuals = item_resource.visuals.instantiate()
	add_child(visuals)


func _on_area_3d_body_shape_entered(body_rid:RID, body:Node3D, body_shape_index:int, local_shape_index:int) -> void:
	if body is Player:
		var new_item = Item.new()
		new_item.item_resource = item_resource
		ECS.world.add_entity(new_item)
		ECS.world.remove_entity(self)
