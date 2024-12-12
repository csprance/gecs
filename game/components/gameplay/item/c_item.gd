## The base Item component
class_name C_Item
extends Component

## The icon that is displayed in the HUD
@export var icon :CompressedTexture2D
## The name of the item
@export var name:= '|EMPTY|'
## The Description of the item
@export var description:= '|EMPTY|'
## The visuals for the item as it exists in the world
@export var visuals: C_Visuals
## The action that is called when the item is used
@export var action: Action = Action.new()
## The action that is called when the item is picked up
@export var pickup_action: Action = Action.new()
## The action that is called when the item is dropped
@export var drop_action: Action = Action.new()
