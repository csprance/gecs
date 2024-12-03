## This entity adds components to entities that enter its area 
## and removes components when they leave
class_name ComponentArea
extends Entity

## Any components you want to add to an entity as it enters the area
@export var parent_on_enter : Array[Component] = []
## Any component you want to remove from an entity as it leaves the area
@export var parent_on_exit : Array[Component] = []
## Any components you want to add to an entity as it enters the area
@export var body_on_enter : Array[Component] = []
## Any component you want to remove from an entity as it leaves the area
@export var body_on_exit : Array[Component] = []

@onready var component_area: ComponentArea3D = $ComponentArea

func on_ready():
	# Forward the components on to the reusable godot component area 3d
	component_area.body_on_enter = body_on_enter
	component_area.body_on_exit = body_on_exit
	component_area.parent_on_enter = parent_on_enter
	component_area.parent_on_exit = parent_on_exit