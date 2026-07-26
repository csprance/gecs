## GecsRelationshipData
## Resource class for serializing relationship data in GECS
##
## This class stores all the necessary information to recreate a [Relationship]
## during deserialization, including the relation component and target information.
class_name GecsRelationshipData
extends Resource

## The relation component data (duplicated for serialization)
@export var relation_data: Component

## The type of target this relationship points to
## Valid values: "Entity", "Component", "Script"
@export var target_type: String = ""

## The id of the target entity (used when target_type is "Entity").
## v9+ saves store the int [member Entity.id] handle. Legacy (pre-v9) saves
## stored a String UUID — @export_storage keeps this untyped so both load
## verbatim and resolve through the load-time id → entity mapping.
@export_storage var target_entity_id = 0

## The target component data (used when target_type is "Component")
@export var target_component_data: Component

## The resource path of the target script (used when target_type is "Script")
@export var target_script_path: String = ""


## Constructor to create relationship data from a Relationship instance
func _init(
	_relation_data: Component = null,
	_target_type: String = "",
	_target_entity_id: int = 0,
	_target_component_data: Component = null,
	_target_script_path: String = "",
):
	relation_data = _relation_data
	target_type = _target_type
	target_entity_id = _target_entity_id
	target_component_data = _target_component_data
	target_script_path = _target_script_path


## Creates GecsRelationshipData from a Relationship instance.
## Returns null for relationships whose target was freed (dangling relationships
## are inert and are dropped from saves).
static func from_relationship(relationship: Relationship) -> GecsRelationshipData:
	# Freed target (Entity freed outside remove_entity): checked before the
	# `is` chain below, which hard-errors on a freed operand.
	var rel_target = relationship.target
	if typeof(rel_target) == TYPE_OBJECT and not is_instance_valid(rel_target):
		return null

	var data = GecsRelationshipData.new()

	# Store relation component (duplicate to avoid reference issues)
	if relationship.relation:
		data.relation_data = relationship.relation.duplicate(true)

	# Determine target type and store appropriate data
	if relationship.target == null:
		data.target_type = "null"
	elif relationship.target is Entity:
		data.target_type = "Entity"
		data.target_entity_id = relationship.target.id
	elif relationship.target is Component:
		data.target_type = "Component"
		data.target_component_data = relationship.target.duplicate(true)
	elif relationship.target is Script:
		data.target_type = "Script"
		data.target_script_path = relationship.target.resource_path
	else:
		push_warning(
			(
				"GecsRelationshipData: Unknown target type: "
				+ str(type_string(typeof(relationship.target)))
			)
		)
		data.target_type = "unknown"

	return data


## Recreates a Relationship from this data (requires entity mapping for Entity targets)
func to_relationship(entity_mapping: Dictionary = {}) -> Relationship:
	var relationship = Relationship.new()

	# Restore relation component
	if relation_data:
		relationship.relation = relation_data.duplicate(true)

	# Restore target based on type
	match target_type:
		"null":
			relationship.target = null
		"Entity":
			# entity_mapping is keyed by the ORIGINAL saved id — int handles from
			# v9+ saves and legacy String UUIDs coexist during a single load.
			if target_entity_id in entity_mapping:
				relationship.target = entity_mapping[target_entity_id]
			else:
				push_warning(
					(
						"GecsRelationshipData: Could not resolve entity with ID: "
						+ str(target_entity_id)
					)
				)
				return null
		"Component":
			if target_component_data:
				relationship.target = target_component_data.duplicate(true)
		"Script":
			if target_script_path != "":
				relationship.target = load(target_script_path)
		_:
			push_warning(
				"GecsRelationshipData: Unknown target type during deserialization: " + target_type
			)
			return null

	return relationship
