## The base Item component
class_name C_Item
extends Component

## The icon that is displayed in the HUD
@export var icon :CompressedTexture2D
## The name of the item
@export var name:= '|EMPTY|'
## The Description of the item
@export var description:= '|EMPTY|'
## THe visuals for the item as it exist as a pickup
@export var visuals: PackedScene
## THe visuals for the item as it exist as a pickup
@export var action: Action
