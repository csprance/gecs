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
##[br]
## [b]Component Queries:[/b][br]
## Use component query dictionaries to match components by specific property criteria in queries and relationships:[br]
##[codeblock]
##  # Query entities with health >= 50
##  var entities = ECS.world.query.with_all([{C_Health: {'amount': {"_gte": 50}}}]).execute()
##
##  # Query relationships with specific damage values
##  var entities = ECS.world.query.with_relationship([
##      Relationship.new({C_Damage: {'amount': {"_eq": 100}}}, target)
##  ]).execute()
##[/codeblock]
@icon("res://addons/gecs/assets/component.svg")
class_name Component
extends Resource

## Emitted when a property of this component changes. This is slightly different from the property_changed signal
signal property_changed(component: Resource, property_name: String, old_value: Variant, new_value: Variant)

## Reference to the parent entity that owns this component
var parent: Entity

## Used to serialize the component to a dictionary with only the export variables
## This is used for the debugger to send the data to the editor
func serialize() -> Dictionary:
	var data: Dictionary = {}
	for prop_info in get_script().get_script_property_list():
		# Only include properties that are exported (@export variables)
		if prop_info.usage & PROPERTY_USAGE_EDITOR:
			var prop_name: String = prop_info.name
			var prop_val = get(prop_name)
			data[prop_name] = prop_val
	return data
