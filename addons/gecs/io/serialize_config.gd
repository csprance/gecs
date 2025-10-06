## This config defines what to include when serializing
## It can be appled to the world as a whole or to specific entities
## This way you can define project level defaults and override them for specific cases
class_name GECSSerializeConfig
extends Resource

## Include all components (true) or only specific components (false)
@export var include_all_components: bool = true
## Which component types to include in serialization (only used when include_all_components = false)
@export var components: Array = []
## Whether to include relationships in serialization
@export var include_relationships: bool = true
## Whether to include related entities in serialization (Related entities are entities referenced by relationships from the serialized entities)
@export var include_related_entities: bool = true


## Helper method to determine if a component should be included in serialization
func should_include_component(component: Component) -> bool:
	var comp_type = component.get_script()
	return include_all_components or components.any(func(type): return comp_type == type)


## Merge this config with another config, with the other config taking priority
func merge_with(other: GECSSerializeConfig) -> GECSSerializeConfig:
	if other == null:
		return self
	
	var merged = GECSSerializeConfig.new()
	merged.include_all_components = other.include_all_components
	merged.components = other.components.duplicate()
	merged.include_relationships = other.include_relationships
	merged.include_related_entities = other.include_related_entities
	return merged