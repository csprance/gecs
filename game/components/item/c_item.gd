## The base Item component
class_name C_Item
extends Component

## The icon that is displayed in the HUD
@export var icon :CompressedTexture2D
## The name of the item
@export var name:= '|EMPTY|'
## The Description of the item
@export var description:= '|EMPTY|'
## The visuals for the item as it exists in the world (not just on ground)
@export var visuals: C_Visuals
## The inventory action that is called when the item is used
@export var action: InventoryAction
## The action that is called when the item is picked up
@export var pickup_action: Action
## The action that is called when the item is dropped
@export var drop_action: Action
## Marks this item as hidden. Which means it will not be displayed in the inventory
@export var hidden:= false

## Creates a barebones entity with the item component and returns it
func make_entity(qty: int, extra_components= [C_InInventory.new()]) -> Entity:
	var entity = Entity.new()
	entity.name = '-'.join([name, entity.get_instance_id()])
	entity.add_components([self, C_Quantity.new(qty)])
	entity.add_components(extra_components)
	if hidden:
		entity.add_component(C_HideInQuickBar.new())
	
	return entity
