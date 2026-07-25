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
	new_value: Variant,
)
## Emit when a [Relationship] is added to the [Entity]
signal relationship_added(entity: Entity, relationship: Relationship)
## Emit when a [Relationship] is removed from the [Entity]
signal relationship_removed(entity: Entity, relationship: Relationship)
## Emitted when multiple [Relationship]s are added in a batch via [method add_relationships]
signal relationships_batch_added(entity: Entity, _relationships: Array)
## Emitted when multiple [Relationship]s are removed in a batch via [method remove_relationships]
signal relationships_batch_removed(entity: Entity, _relationships: Array)

#endregion Signals

#region Exported Variables
## Optional human-readable name for this entity, unique within a [World].
## Registered in the world's alias registry at add time — look up with
## [method World.get_entity_by_alias]. An alias is a NAME, not an identity:
## the entity's identity is the int handle [member id].
## (Replaces the v8 pattern of assigning semantic strings to `id`.)
@export var alias: StringName = &""
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
## [Component]s attached to the [Entity] in the form of Dict[int (script_instance_id), Component]
var components: Dictionary = {}

## Relationships attached to the entity
var relationships: Array[Relationship] = []

## Relationship bucket index: relation script instance_id -> Array[Relationship].
## Narrows get/has_relationship scans from O(all rels) to O(rels of that type);
## wildcard probes (relation == null) fall back to the full array.
var _rels_by_relation: Dictionary = {}

## Cache for component keys to avoid repeated .get_script().get_instance_id() calls
var _component_key_cache: Dictionary = {}


## Returns the int key used for component dictionary lookups.
## Accepts either a Script (class reference) or a Component instance.
static func _comp_key(c) -> int:
	if c is Script:
		return c.get_instance_id()
	return c.get_script().get_instance_id()


## Logger for entities to only log to a specific domain
var _entityLogger = GECSLogger.new().domain("Entity")

## We can store ephemeral state on the entity
var _state = {}

## THE entity identity: a 64-bit generational handle assigned by the World —
## low 32 bits = slot index, high 32 bits = generation (bumped when a slot is
## recycled, so stale handles are detected in O(1) via [method World.is_alive]).
## 0 until registered with a World. Replaces BOTH the v8 String UUID `id` and
## the sequential `ecs_id`: relationship pair keys, serialization, and network
## replication all use this single int. Pre-assign a nonzero value before
## [method World.add_entity] (deserialization / network spawn) to keep a
## foreign identity — the world registers it verbatim instead of allocating.
var id: int = 0

## The [World] currently tracking this entity (set by World.add_entity/enable_entity,
## cleared by remove_entity/disable_entity). Structural mutations notify it via
## DIRECT calls instead of signal dispatch — the entity-level signals still emit
## for user code, but the world is no longer a signal subscriber (a signal emit
## costs ~3x a direct call, and connect/disconnect per entity lifecycle is gone).
var _world: World = null

## Position in World.entities — maintained by the world for O(1) swap-removal.
## -1 while not in a world's entity list.
var _entities_index: int = -1

#endregion Public Variables

#region Built-in Virtual Methods


## Called to initialize the entity and its components.
## This is called automatically by [method World.add_entity][br]
func _initialize(_components: Array = []) -> void:
	_entityLogger.trace("Entity Initializing Components: ", self.name)

	# because components can be added before the entity is added to the world
	# replay adding components here so signals pick them up and the index is updated
	# Use a shallow duplicate (same instances) so the caller's reference remains the
	# live instance in entity.components after _initialize. deep-copying here created
	# ghost property_changed connections on the original instances that could never be
	# cleaned up by remove_component() (which only disconnects the stored copy).
	var temp_comps = components.values().duplicate()
	components.clear()
	for comp in temp_comps:
		add_component(comp)

	# Add components defined in code to comp resources
	component_resources.append_array(define_components())

	# remove any component_resources that are already defined in components
	# This is useful for when you instantiate an entity from a scene and want to overide components
	component_resources = component_resources.filter(
		func(comp): return not has_component(comp.get_script())
	)

	# Add components passed in directly to the _initialize method to override everything else
	component_resources.append_array(_components)

	## [b]Note:[/b] Items in [code]component_resources[/code] are shallow-duplicated
	## ([code]duplicate()[/code]) — a new [Resource] object is created and all top-level
	## property values (including non-[code]@export[/code] vars) are copied, but nested
	## sub-resource references are shared between entities.[br]
	## Always return fresh [code].new()[/code] instances from [method define_components]
	## to avoid unintentional state sharing.[br]
	# Initialize components
	# Shallow-copy each component so each entity gets its own Resource instance
	# while preserving ALL top-level property values — including non-@export vars.
	# We cannot use res.duplicate() (only copies @export props) or res.duplicate(true)
	# (deep-copies sub-resources, resetting non-@export vars to script defaults).
	# Instead we create a new instance via the same script and copy every property.
	for res in component_resources:
		var copy: Component = res.get_script().new()
		for prop in res.get_property_list():
			if prop.usage & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE):
				copy.set(prop.name, res.get(prop.name))
		add_component(copy)

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
	# Cache the component key to avoid repeated calls
	var comp_key = _comp_key(component)

	# If a component of this type already exists, remove it first
	if components.has(comp_key):
		var existing_component = components[comp_key]
		remove_component(existing_component)

	_component_key_cache[component] = comp_key
	components[comp_key] = component
	component.parent = self
	if not component.property_changed.is_connected(_on_component_property_changed):
		component.property_changed.connect(_on_component_property_changed)
	# Notify the world directly (archetype move + observer dispatch), then emit
	# the entity-level signal for user code — same order as the old subscription.
	if _world:
		_world._on_entity_component_added(self, component)
	component_added.emit(self, component)
	_entityLogger.trace("Added Component: ", comp_key)


func _on_component_property_changed(
	component: Resource,
	property_name: String,
	old_value: Variant,
	new_value: Variant,
) -> void:
	# Single hop: notify the world directly (observer CHANGED dispatch + monitor
	# eval), then re-emit for user code listening on the entity.
	if _world:
		_world._on_entity_component_property_change(
			self, component, property_name, old_value, new_value
		)
	component_property_changed.emit(self, component, property_name, old_value, new_value)


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
		var comp_key = _comp_key(component)
		if not components.has(comp_key):
			components[comp_key] = component
			added_components.append(component)

	# If no new components were actually added, return early
	if added_components.is_empty():
		return

	# OPTIMIZATION: One archetype transition for the whole batch. The per-component
	# component_added emits below make the world handler queue a deferred move
	# (instead of recomputing the signature per component); closing the window
	# commits a single transition. Nested inside an outer window (CommandBuffer
	# flush), owns=false and the outer window commits instead.
	var owns_deferral := false
	if ECS.world:
		owns_deferral = ECS.world._begin_deferred_moves()
		ECS.world._refresh_entity_archetype(self)

	# Notify world + emit signals for all added components
	for component in added_components:
		if _world:
			_world._on_entity_component_added(self, component)
		component_added.emit(self, component)

	if owns_deferral:
		ECS.world._end_deferred_moves()


## Removes a single component from the entity.[br]
## [param component] The [Component] subclass to remove.[br]
## [b]Example:[/b]
##     [codeblock]entity.remove_component(HealthComponent)[/codeblock]
func remove_component(component: Resource) -> void:
	# Use cached key if available, otherwise derive it
	var comp_key: int
	if _component_key_cache.has(component):
		comp_key = _component_key_cache[component]
		_component_key_cache.erase(component)
	else:
		comp_key = _comp_key(component)

	if components.has(comp_key):
		var component_instance = components[comp_key]
		components.erase(comp_key)

		# Clean up cache entry for the component instance
		_component_key_cache.erase(component_instance)

		# OBS-03: Disconnect property_changed before emitting removal signal.
		# Without this, phantom on_component_changed callbacks arrive whenever
		# the removed component's setters emit property_changed after removal.
		if component_instance.property_changed.is_connected(_on_component_property_changed):
			component_instance.property_changed.disconnect(_on_component_property_changed)

		# Notify the world directly (archetype move + observer REMOVED), then emit
		if _world:
			_world._on_entity_component_removed(self, component_instance)
		component_removed.emit(self, component_instance)
		_entityLogger.trace("Removed Component: ", comp_key)


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
			var comp_key = _comp_key(comp_to_remove)
			if components.has(comp_key):
				components.erase(comp_key)
				# Clean up cache entries for both the class and instance
				_component_key_cache.erase(_component)
				_component_key_cache.erase(comp_to_remove)
				# OBS-03: Disconnect property_changed before emitting removal signal.
				if comp_to_remove.property_changed.is_connected(_on_component_property_changed):
					comp_to_remove.property_changed.disconnect(_on_component_property_changed)
				removed_components.append(comp_to_remove)

	# If no components were actually removed, return early
	if removed_components.is_empty():
		return

	# OPTIMIZATION: One archetype transition for the whole batch (see add_components).
	var owns_deferral := false
	if ECS.world:
		owns_deferral = ECS.world._begin_deferred_moves()
		ECS.world._refresh_entity_archetype(self)

	# Notify world + emit signals for all removed components
	for component in removed_components:
		if _world:
			_world._on_entity_component_removed(self, component)
		component_removed.emit(self, component)

	if owns_deferral:
		ECS.world._end_deferred_moves()


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
	# Inlined key derivation — this is the hottest call in non-iterate() systems,
	# and the _comp_key call itself costs ~0.6us of dispatch overhead.
	return components.get(
		component.get_instance_id() if component is Script else component.get_script().get_instance_id(),
		null
	)


## Check to see if an entity has a  specific component on it.[br]
## This is useful when you're checking to see if it has a component and not going to use the component itself.[br]
## If you plan on getting and using the component, use [method get_component] instead.
func has_component(component: Resource) -> bool:
	# Inlined key derivation — see get_component
	return components.has(
		component.get_instance_id() if component is Script else component.get_script().get_instance_id()
	)


## CHANGE DETECTION: mark a component as written for queries using .changed().
## Components whose setters emit [signal Component.property_changed] are stamped
## automatically — call this only for components mutated directly (no setter).
## [codeblock]
## var pos = entity.get_component(C_Position)
## pos.position.x += 10.0  # direct write, no property_changed emit
## entity.mark_changed(pos)
## [/codeblock]
func mark_changed(component: Resource) -> void:
	if _world:
		_world._mark_component_changed(self, component)


#endregion Components

#region Relationships


## Bucket key for the relationship index (0 = unbucketed/wildcard).
static func _rel_bucket_key(rel: Relationship) -> int:
	if rel == null or rel.relation == null:
		return 0
	var script = rel.relation.get_script()
	return script.get_instance_id() if script else 0


func _rel_index_add(rel: Relationship) -> void:
	var key := _rel_bucket_key(rel)
	if key == 0:
		return
	var bucket: Array = _rels_by_relation.get(key, [])
	if bucket.is_empty():
		_rels_by_relation[key] = bucket
	bucket.append(rel)


func _rel_index_remove(rel: Relationship) -> void:
	var key := _rel_bucket_key(rel)
	if key == 0:
		return
	var bucket = _rels_by_relation.get(key)
	if bucket != null:
		bucket.erase(rel)


## Candidate list for a probe: the type bucket when the probe names a relation,
## the full array for wildcard probes.
func _rel_candidates(probe: Relationship) -> Array:
	if probe == null or probe.relation == null:
		return relationships
	return _rels_by_relation.get(_rel_bucket_key(probe), [])


## Adds a relationship to this entity.[br]
## [param relationship] The [Relationship] to add.
func add_relationship(relationship: Relationship) -> void:
	assert(
		not relationship._is_query_relationship,
		"Cannot add query relationships to entities. Query relationships (created with dictionaries) are for matching only, not for storage.",
	)
	relationship.source = self
	relationships.append(relationship)
	_rel_index_add(relationship)
	if _world:
		_world._on_entity_relationship_added(self, relationship)
	relationship_added.emit(self, relationship)


func add_relationships(_relationships: Array):
	for relationship in _relationships:
		assert(
			not relationship._is_query_relationship,
			"Cannot add query relationships to entities. Query relationships (created with dictionaries) are for matching only, not for storage.",
		)
		relationship.source = self
		relationships.append(relationship)
		_rel_index_add(relationship)
	if _world:
		_world._on_entity_relationships_batch_added(self, _relationships)
	relationships_batch_added.emit(self, _relationships)


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
		for rel in _rel_candidates(relationship):
			if rel.matches(relationship):
				to_remove.append(rel)
				removed_count += 1
				# If limit is positive and we've reached it, stop collecting
				if limit > 0 and removed_count >= limit:
					break

	for rel in to_remove:
		relationships.erase(rel)
		_rel_index_remove(rel)
		if _world:
			_world._on_entity_relationship_removed(self, rel)
		relationship_removed.emit(self, rel)


## Removes multiple relationships from the entity.[br]
## [param _relationships] Array of [Relationship]s to remove.[br]
## [param limit] Maximum number of relationships to remove per relationship type. -1 = all (default), 0 = none, >0 = up to that many.[br]
## Emits [signal relationship_removed] per removed rel as the removal happens, so
## multi-rel observer queries see the entity in its correct pre-removal state for
## each individual removal (rather than all rels gone at once).
func remove_relationships(_relationships: Array, limit: int = -1):
	for relationship in _relationships:
		if limit == 0:
			continue
		var to_remove = []
		var removed_count = 0
		var pattern_remove = true
		if relationships.has(relationship):
			to_remove.append(relationship)
			pattern_remove = false
		if pattern_remove:
			for rel in _rel_candidates(relationship):
				if rel.matches(relationship):
					to_remove.append(rel)
					removed_count += 1
					if limit > 0 and removed_count >= limit:
						break
		for rel in to_remove:
			relationships.erase(rel)
			_rel_index_remove(rel)
			if _world:
				_world._on_entity_relationship_removed(self, rel)
			relationship_removed.emit(self, rel)


## Removes all relationships from the entity.
func remove_all_relationships() -> void:
	var to_remove = relationships.duplicate()
	for rel in to_remove:
		relationships.erase(rel)
		_rel_index_remove(rel)
		if _world:
			_world._on_entity_relationship_removed(self, rel)
		relationship_removed.emit(self, rel)


## Retrieves a specific [Relationship] from the entity.
## [param relationship] The [Relationship] to retrieve.
## [return] The first matching [Relationship] if it exists, otherwise `null`
func get_relationship(relationship: Relationship) -> Relationship:
	var to_remove = []
	for rel in _rel_candidates(relationship):
		# Check if the relationship is valid
		if not rel.valid():
			to_remove.append(rel)
			continue
		if rel.matches(relationship):
			# Remove invalid relationships before returning
			for invalid_rel in to_remove:
				relationships.erase(invalid_rel)
				_rel_index_remove(invalid_rel)
				relationship_removed.emit(self, invalid_rel)
			return rel
	# Remove invalid relationships
	for rel in to_remove:
		relationships.erase(rel)
		_rel_index_remove(rel)
		relationship_removed.emit(self, rel)
	return null


## Retrieves [Relationship]s from the entity.
## [param relationship] The [Relationship]s to retrieve.
## [return] Array of all matching [Relationship]s (empty array if none found).
func get_relationships(relationship: Relationship) -> Array[Relationship]:
	var results: Array[Relationship] = []
	var to_remove = []
	for rel in _rel_candidates(relationship):
		# Check if the relationship is valid
		if not rel.valid():
			to_remove.append(rel)
			continue
		if rel.matches(relationship):
			results.append(rel)
	# Remove invalid relationships
	for rel in to_remove:
		relationships.erase(rel)
		_rel_index_remove(rel)
		relationship_removed.emit(self, rel)
	return results


## Checks if the entity has a specific relationship.[br]
## Fast path — skips validation/cleanup (use get_relationship when you need the value).[br]
## [param relationship] The [Relationship] to check for.
func has_relationship(relationship: Relationship) -> bool:
	for rel in _rel_candidates(relationship):
		if rel.matches(relationship):
			return true
	return false


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
## This should return a list of components to add by default when the entity is created[br]
## [b]Important:[/b] Always return fresh [code].new()[/code] instances from this method.[br]
## Items returned here are shallow-duplicated during [method _initialize] —
## returning a cached/shared instance would cause all entities of this type to
## share the same sub-resource references.[br]
func define_components() -> Array:
	return []


## INTERNAL: Called when entity.enabled changes to move entity between archetypes
func _on_enabled_changed(old_value: bool, new_value: bool) -> void:
	# Only handle if entity is already in a world
	if not ECS.world or not ECS.world.entity_to_archetype.has(self):
		return

	# OPTIMIZATION: Update bitset instead of moving between archetypes
	# This eliminates the need for separate enabled/disabled archetypes
	var archetype = ECS.world.entity_to_archetype[self]
	archetype.update_entity_enabled_state(self, new_value)

	# Membership (as seen through enabled filters) changed — bump so cached
	# execute() results go stale. Routed through _bump_membership so batch
	# suppression (_begin_suppress/_end_suppress) coalesces multiple
	# enable/disable operations into a single bump.
	ECS.world._bump_membership("entity_enabled_changed")

#endregion Lifecycle Methods
