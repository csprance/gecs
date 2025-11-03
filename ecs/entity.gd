## Entity[br]
##
## Represents an entity within the [_ECS] framework.[br]
## An entity is a container that can hold multiple [Component]s.
##
## Entities serve as the fundamental building block for game objects, allowing for flexible and modular design.[br]
##[br]
## Entities can have [Component]s added or removed dynamically, enabling the behavior and properties of game objects to change at runtime.[br]
## Entities can have [Relationship]s added or removed dynamically, allowing for a deep hierarchical query system.[br]
##[br]
## Example:
##[codeblock]
##     var entity = Entity.new()
##     var transform = Transform.new()
##     entity.add_component(transform)
##     entity.component_added.connect(_on_component_added)
##
##     func _on_component_added(entity: Entity, component_key: String) -> void:
##         print("Component added:", component_key)
##[/codeblock]
@icon("res://addons/gecs/assets/entity.svg")
@tool
class_name Entity
extends Node

#region Signals
## Emitted when a [Component] is added to the entity.
signal component_added(entity: Entity, component: Resource)
## Emitted when a [Component] is removed from the entity.
signal component_removed(entity: Entity, component: Resource)
## Emitted when a [Component] property is changed.
signal component_property_changed(
	entity: Entity,
	component: Resource,
	property_name: String,
	old_value: Variant,
	new_value: Variant
)
## Emit when a [Relationship] is added to the [Entity]
signal relationship_added(entity: Entity, relationship: Relationship)
## Emit when a [Relationship] is removed from the [Entity]
signal relationship_removed(entity: Entity, relationship: Relationship)

#endregion Signals

#region Exported Variables
## The id of the entity either UUID or custom string.
## This must be unique within a [World]. If left blank, a UUID will be generated when the entity is added to a world.
@export var id: String
## Is this entity active? (Will show up in queries)
@export var enabled: bool = true:
	set(value):
		if enabled != value:
			var old_enabled = enabled
			enabled = value
			# Notify world to move entity between enabled/disabled archetypes
			_on_enabled_changed(old_enabled, value)
## [Component]s to be attached to the entity set in the editor. These will be loaded for you and added to the [Entity]
@export var component_resources: Array[Component] = []
## Serialization config override for this specific entity (optional)
@export var serialize_config: GECSSerializeConfig

#endregion Exported Variables

#region Public Variables
## [Component]s attached to the [Entity] in the form of Dict[resource_path:String, Component]
var components: Dictionary = {}

## Relationships attached to the entity
var relationships: Array[Relationship] = []

## Cache for component resource paths to avoid repeated .get_script().resource_path calls
var _component_path_cache: Dictionary = {}

## Logger for entities to only log to a specific domain
var _entityLogger = GECSLogger.new().domain("Entity")

## We can store ephemeral state on the entity
var _state = {}

#endregion Public Variables

#region Built-in Virtual Methods


## Called to initialize the entity and its components.
## This is called automatically by [method World.add_entity][br]
func _initialize(_components: Array = []) -> void:
	_entityLogger.trace("Entity Initializing Components: ", self.name)

	# because components can be added before the entity is added to the world
	# replay adding components here so signals pick them up and the index is updated
	var temp_comps = components.values().duplicate_deep()
	components.clear()
	for comp in temp_comps:
		add_component(comp)

	# Add components defined in code to comp resources
	component_resources.append_array(define_components())

	# remove any component_resources that are already defined in components
	# This is useful for when you instantiate an entity from a scene and want to overide components
	component_resources = component_resources.filter(func(comp): return not has_component(comp.get_script()))

	# Add components passed in directly to the _initialize method to override everything else
	component_resources.append_array(_components)

	# Initialize components
	for res in component_resources:
		add_component(res.duplicate(true))

	# Call the lifecycle method on_ready
	on_ready()

#endregion Built-in Virtual Methods


## Get the effective serialization config for this entity
## Returns entity-specific config if set, otherwise falls back to world default
func get_effective_serialize_config() -> GECSSerializeConfig:
	if serialize_config != null:
		return serialize_config
	if ECS.world != null and ECS.world.default_serialize_config != null:
		return ECS.world.default_serialize_config
	# Fallback if no world or no default config
	var fallback = GECSSerializeConfig.new()
	return fallback

#region Components


## Adds a single component to the entity.[br]
## [param component] The subclass of [Component] to add.[br]
## [b]Example[/b]:
## [codeblock]entity.add_component(HealthComponent)[/codeblock]
func add_component(component: Resource) -> void:
	# Cache the resource path to avoid repeated calls
	var resource_path = component.get_script().resource_path

	# If a component of this type already exists, remove it first
	if components.has(resource_path):
		var existing_component = components[resource_path]
		remove_component(existing_component)

	_component_path_cache[component] = resource_path
	components[resource_path] = component
	component.parent = self
	if not component.property_changed.is_connected(_on_component_property_changed):
		component.property_changed.connect(_on_component_property_changed)
	## Adding components happens through a signal
	component_added.emit(self , component)
	_entityLogger.trace("Added Component: ", resource_path)


func _on_component_property_changed(
	component: Resource, property_name: String, old_value: Variant, new_value: Variant
) -> void:
	# Pass this signal on to the world
	component_property_changed.emit(self , component, property_name, old_value, new_value)


## Adds multiple components to the entity.[br]
## [param _components] An [Array] of [Component]s to add.[br]
## [b]Example:[/b]
##     [codeblock]entity.add_components([TransformComponent, VelocityComponent])[/codeblock]
func add_components(_components: Array):
	# OPTIMIZATION: Batch component additions to avoid multiple archetype transitions
	# Instead of moving archetype once per component, calculate the final archetype once
	if _components.is_empty():
		return

	# Add all components to local storage first (no signals yet)
	var added_components = []
	for component in _components:
		if component == null:
			continue
		var component_path = component.get_script().resource_path
		if not components.has(component_path):
			components[component_path] = component
			added_components.append(component)

	# If no new components were actually added, return early
	if added_components.is_empty():
		return

	# OPTIMIZATION: Move to final archetype only once, after all components are added
	if ECS.world and ECS.world.entity_to_archetype.has(self ):
		var old_archetype = ECS.world.entity_to_archetype[ self ]
		var new_signature = ECS.world._calculate_entity_signature(self )
		var comp_types = components.keys()
		var new_archetype = ECS.world._get_or_create_archetype(new_signature, comp_types)

		# Only move if we actually need a different archetype
		if old_archetype != new_archetype:
			# Remove from old archetype
			old_archetype.remove_entity(self )
			# Add to new archetype
			new_archetype.add_entity(self )
			ECS.world.entity_to_archetype[ self ] = new_archetype

			# Clean up empty old archetype
			if old_archetype.is_empty():
				old_archetype.add_edges.clear()
				old_archetype.remove_edges.clear()
				ECS.world.archetypes.erase(old_archetype.signature)
		else:
			# Same archetype - just update the column data for new components
			for component in added_components:
				var comp_path = component.get_script().resource_path
				var entity_index = old_archetype.entity_to_index[ self ]
				old_archetype.columns[comp_path][entity_index] = component

	# Emit signals for all added components
	for component in added_components:
		component_added.emit(self , component)


## Removes a single component from the entity.[br]
## [param component] The [Component] subclass to remove.[br]
## [b]Example:[/b]
##     [codeblock]entity.remove_component(HealthComponent)[/codeblock]
func remove_component(component: Resource) -> void:
	# Use cached path if available, otherwise get it from the component class
	var resource_path: String
	if _component_path_cache.has(component):
		resource_path = _component_path_cache[component]
		_component_path_cache.erase(component)
	else:
		# Component parameter should be a class/script, consistent with has_component
		resource_path = component.resource_path

	if components.has(resource_path):
		var component_instance = components[resource_path]
		components.erase(resource_path)

		# Clean up cache entry for the component instance
		_component_path_cache.erase(component_instance)

		component_removed.emit(self , component_instance)
		# ARCHETYPE: Signal handler (_on_entity_component_removed) handles archetype update
		_entityLogger.trace("Removed Component: ", resource_path)


func deferred_remove_component(component: Resource) -> void:
	call_deferred_thread_group("remove_component", component)


## Removes multiple components from the entity.[br]
## [param _components] An array of components to remove.[br]
##
## [b]Example:[/b]
##     [codeblock]entity.remove_components([transform_component, velocity_component])[/codeblock]
func remove_components(_components: Array):
	# OPTIMIZATION: Batch component removals to avoid multiple archetype transitions
	# Instead of moving archetype once per component, calculate the final archetype once
	if _components.is_empty():
		return

	# Remove all components from local storage first (no signals yet)
	var removed_components = []
	for _component in _components:
		if _component == null:
			continue
		var comp_to_remove: Resource = null

		# Handle both Scripts and Resource instances
		# NOTE: Check Script first since Script inherits from Resource
		if _component is Script:
			comp_to_remove = get_component(_component)
		elif _component is Resource:
			comp_to_remove = _component

		if comp_to_remove:
			var component_path = comp_to_remove.get_script().resource_path
			if components.has(component_path):
				components.erase(component_path)
				removed_components.append(comp_to_remove)

	# If no components were actually removed, return early
	if removed_components.is_empty():
		return

	# OPTIMIZATION: Move to final archetype only once, after all components are removed
	if ECS.world and ECS.world.entity_to_archetype.has(self ):
		var old_archetype = ECS.world.entity_to_archetype[ self ]
		var new_signature = ECS.world._calculate_entity_signature(self )
		var comp_types = components.keys()
		var new_archetype = ECS.world._get_or_create_archetype(new_signature, comp_types)

		# Only move if we actually need a different archetype
		if old_archetype != new_archetype:
			# Remove from old archetype
			old_archetype.remove_entity(self )
			# Add to new archetype
			new_archetype.add_entity(self )
			ECS.world.entity_to_archetype[ self ] = new_archetype

			# Clean up empty old archetype
			if old_archetype.is_empty():
				old_archetype.add_edges.clear()
				old_archetype.remove_edges.clear()
				ECS.world.archetypes.erase(old_archetype.signature)

	# Emit signals for all removed components
	for component in removed_components:
		component_removed.emit(self , component)


##  Removes all components from the entity.[br]
## [b]Example:[/b]
##     [codeblock]entity.remove_all_components()[/codeblock]
func remove_all_components() -> void:
	for component in components.values():
		remove_component(component)


## Retrieves a specific [Component] from the entity.[br]
## [param component] The [Component] class to retrieve.[br]
## Returns the requested [Component] if it exists, otherwise `null`.[br]
## [b]Example:[/b]
##     [codeblock]var transform = entity.get_component(Transform)[/codeblock]
func get_component(component: Resource) -> Component:
	return components.get(component.resource_path, null)


## Check to see if an entity has a  specific component on it.[br]
## This is useful when you're checking to see if it has a component and not going to use the component itself.[br]
## If you plan on getting and using the component, use [method get_component] instead.
func has_component(component: Resource) -> bool:
	return components.has(component.resource_path)

#endregion Components

#region Relationships


## Adds a relationship to this entity.[br]
## [param relationship] The [Relationship] to add.
func add_relationship(relationship: Relationship) -> void:
	assert(
		not relationship._is_query_relationship,
		"Cannot add query relationships to entities. Query relationships (created with dictionaries) are for matching only, not for storage."
	)
	relationship.source = self
	relationships.append(relationship)
	relationship_added.emit(self , relationship)


func add_relationships(_relationships: Array):
	for relationship in _relationships:
		add_relationship(relationship)


## Removes a relationship from the entity.[br]
## [param relationship] The [Relationship] to remove.[br]
## [param limit] Maximum number of relationships to remove. -1 = all (default), 0 = none, >0 = up to that many.[br]
## [br]
## [b]Examples:[/b]
## [codeblock]
## # Remove all matching relationships (default behavior)
## entity.remove_relationship(Relationship.new(C_Damage.new(), target))
##
## # Remove only one matching relationship
## entity.remove_relationship(Relationship.new(C_Damage.new(), target), 1)
##
## # Remove up to 3 matching relationships
## entity.remove_relationship(Relationship.new(C_Damage.new(), target), 3)
##
## # Remove no relationships (useful for testing/debugging)
## entity.remove_relationship(Relationship.new(C_Damage.new(), target), 0)
## [/codeblock]
func remove_relationship(relationship: Relationship, limit: int = -1) -> void:
	if limit == 0:
		return

	var to_remove = []
	var removed_count = 0

	var pattern_remove = true
	if relationships.has(relationship):
		to_remove.append(relationship)
		pattern_remove = false

	if pattern_remove:
		for rel in relationships:
			if rel.matches(relationship):
				to_remove.append(rel)
				removed_count += 1
				# If limit is positive and we've reached it, stop collecting
				if limit > 0 and removed_count >= limit:
					break

	for rel in to_remove:
		relationships.erase(rel)
		relationship_removed.emit(self , rel)


## Removes multiple relationships from the entity.[br]
## [param _relationships] Array of [Relationship]s to remove.[br]
## [param limit] Maximum number of relationships to remove per relationship type. -1 = all (default), 0 = none, >0 = up to that many.
func remove_relationships(_relationships: Array, limit: int = -1):
	for relationship in _relationships:
		remove_relationship(relationship, limit)


## Removes all relationships from the entity.
func remove_all_relationships() -> void:
	var to_remove = relationships.duplicate()
	for rel in to_remove:
		relationships.erase(rel)
		relationship_removed.emit(self , rel)


## Retrieves a specific [Relationship] from the entity.
## [param relationship] The [Relationship] to retrieve.
## [return] The first matching [Relationship] if it exists, otherwise `null`
func get_relationship(relationship: Relationship) -> Relationship:
	var to_remove = []
	for rel in relationships:
		# Check if the relationship is valid
		if not rel.valid():
			to_remove.append(rel)
			continue
		if rel.matches(relationship):
			# Remove invalid relationships before returning
			for invalid_rel in to_remove:
				relationships.erase(invalid_rel)
				relationship_removed.emit(self , invalid_rel)
			return rel
	# Remove invalid relationships
	for rel in to_remove:
		relationships.erase(rel)
		relationship_removed.emit(self , rel)
	return null


## Retrieves [Relationship]s from the entity.
## [param relationship] The [Relationship]s to retrieve.
## [return] Array of all matching [Relationship]s (empty array if none found).
func get_relationships(relationship: Relationship) -> Array[Relationship]:
	var results: Array[Relationship] = []
	var to_remove = []
	for rel in relationships:
		# Check if the relationship is valid
		if not rel.valid():
			to_remove.append(rel)
			continue
		if rel.matches(relationship):
			results.append(rel)
	# Remove invalid relationships
	for rel in to_remove:
		relationships.erase(rel)
		relationship_removed.emit(self , rel)
	return results


## Checks if the entity has a specific relationship.[br]
## [param relationship] The [Relationship] to check for.
func has_relationship(relationship: Relationship) -> bool:
	return get_relationship(relationship) != null

#endregion Relationships

#region Lifecycle Methods


## Called after the entity is fully initialized and ready.[br]
## Override this method to perform additional setup after all components have been added.
func on_ready() -> void:
	pass


## Called right before the entity is freed from memory.[br]
## Override this method to perform any necessary cleanup before the entity is destroyed.
func on_destroy() -> void:
	pass


## Called when the entity is disabled.[br]
func on_disable() -> void:
	pass


## Called when the entity is enabled.[br]
func on_enable() -> void:
	pass


## Define the default components in code to use (Instead of in the editor)[br]
## This should return a list of components to add by default when the entity is created
func define_components() -> Array:
	return []


## INTERNAL: Called when entity.enabled changes to move entity between archetypes
func _on_enabled_changed(old_value: bool, new_value: bool) -> void:
	# Only handle if entity is already in a world
	if not ECS.world or not ECS.world.entity_to_archetype.has(self ):
		return

	# OPTIMIZATION: Update bitset instead of moving between archetypes
	# This eliminates the need for separate enabled/disabled archetypes
	var archetype = ECS.world.entity_to_archetype[ self ]
	archetype.update_entity_enabled_state(self , new_value)

	# Invalidate query cache since archetypes changed
	ECS.world.cache_invalidated.emit()

#endregion Lifecycle Methods
