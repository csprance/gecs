class_name Pickup
extends Entity

# Remember Entities are just containers and glue code
var item = Item.new()

func on_ready() -> void:
	# we probably want to sync the component transform to the node transform
	Utils.sync_transform(self)
	var c_item = get_component(C_Item) as C_Item
	item.add_component(c_item.duplicate())
	var visuals = c_item.visuals.instantiate()
	add_child(visuals)


func _on_area_3d_body_shape_entered(body_rid:RID, body:Node3D, body_shape_index:int, local_shape_index:int) -> void:
	if body is Player:
		item.add_component(C_Player.new())
		ECS.world.add_entity(item)
		ECS.world.remove_entity(self)
