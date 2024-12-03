## A Component serves as a data container within the [_ECS] ([Entity] [Component] [System]) framework.
##
## A [Component] holds specific data related to an [Entity] but does not contain any behavior or logic.[br]
## Components are designed to be lightweight and easily attachable to [Entity]s to define their properties.[br]
##[br]
## [b]Example:[/b]
##[codeblock]
##  ## Velocity Component.
##  ##
##  ## Holds the velocity data for an entity.
##  class_name VelocityComponent
##  extends Node2D
##
##  @export var velocity: Vector2 = Vector2.ZERO
##[/codeblock]    
@icon('res://addons/gecs/assets/component.svg')
class_name Component
extends Resource

## Checks if this component equals another, including data
func equals(other: Component) -> bool:
	if self.get_script().resource_path != other.get_script().resource_path:
		return false
	for prop in self.get_property_list():
		var prop_name = prop.name
		if self.get(prop_name) != other.get(prop_name):
			return false
	return true
