#
#	Copyright 2018-2023, SpockerDotNet LLC.
#	https://gitlab.com/godot-stuff/gs-ecs/-/blob/master/LICENSE.md
#
#	Class: ECS
#		Framework for Managing a simple Entity Component System
#		with Godot.
#
#	Remarks:
#
#	Installation:
#		Add this Script as an Autoload singleton to your Project.
#

extends Node

# scene entities
var entities = {}
# entities with a component
var component_entities = {}
# a system processes entities with certain components
var systems = {}
# the components filtered in a system
var system_components = {}
# the entities in a given system
var system_entities = {}
# a group represents a collection of systems
var groups = {}
# systems in a group
var group_systems = {}
# a list of entities to remove after group processing is complete
var entity_remove_queue = []

var is_dirty = false
var do_clean = false

var version = "4.0-R2"

# Group: Public Methods

#'''
#	Function: add_component
#
#		Adds a Component to the Framework
#
#	--- Prototype
#	add_component(component: Component): Void
#	---
#
#'''
func add_component(component):
	Logger.trace("[ECS] add_component")
	is_dirty = true
	var _name = str(component.name).to_lower()
	if has_component(_name):
		Logger.warn("- component %s was already registered -- skipping" % [_name])
		return
				
	component_entities[_name] = {}
	Logger.debug("- new component %s was registered" % [_name])


#'''
#	Function: add_entity
#
#		Adds an Entity to the Framework
#
#	--- Prototype
#	add_entity(entity: Entity): Void
#	---
#
#	Remarks:
#
#		The <instance_id: https://docs.godotengine.org/en/3.1/classes/class_object.html?highlight=get_instance_id#class-object-method-get-instance-id> of the Node is used as the
#		Key for the Entity.
#
#'''

func add_entity(entity):
	Logger.trace("[ECS] add_entity")
	is_dirty = true

	var _id = entity.get_instance_id()
	var _name = entity.name

	# warn if trying to use same instance_id and exit
	if has_entity(_id):
		Logger.warn("- entity %s already exists, skipping")
		return

	# turn off normal godot processing

	entity.set_process(false)
	entity.set_physics_process(false)
	entity.set_process_input(false)

	# call on_before_add if available
	if entity.has_method("on_before_add"):
		entity.on_before_add()

	# add the entity node reference using its instance_id as key
	entities[_id] = entity

	Logger.debug("- entity %s:%s has been registered" % [entity, _name])

	# call on_after_add if available
	if entity.has_method("on_after_add"):
		entity.on_after_add()


# add system to the framework
func add_system(system, components = []):
	Logger.trace("[ECS] add_system")
	is_dirty = true

	var _id = str(system.name).to_lower()

	if has_system(_id):
		Logger.warn("- system %s already exists, skipping" % [_id])
		return

	# call on_before_add if available
	if system.has_method("on_before_add"):
		system.on_before_add()

	# add the system and create an empty list of component names
	systems[_id] = system
	system_components[_id] = []

	# add the components to the system
	for _component in components:
		system_components[_id].append(_component.to_lower().strip_edges())

	Logger.debug("- system %s has been registered" % [_id])

	# call on_after_add if available
	if system.has_method("on_after_add"):
		system.on_after_add()


func add_group(group, systems = []):
	Logger.trace("[ECS] add_group")
	is_dirty = true

	var _id = group.name.to_lower()

	if has_group(_id):
		Logger.warn("- group %s already exists, skipping" % [_id])
		return

	groups[_id] = group
	group_systems[_id] = []

	for system in systems:
		group_systems[_id].append(system.to_lower().strip_edges())

	Logger.debug("- group %s has been registered" % [_id])


# remove everything from the framework
func clean():
	
	do_clean = true
	

# add an entity to a component
func entity_add_component(entity, component):
	Logger.trace("[ECS] entity_add_component")
	is_dirty = true

	var _entity_id = entity.get_instance_id()

	if not has_entity(_entity_id):
		Logger.warn("- entity %s:%s not registered " % [entity, entity.name])
		add_entity(entity)
		Logger.debug("- entity was registered")

	var _id = str( component.name ).to_lower()

	# add new component
	if not has_component(_id):
		add_component(component)

	# add entity to the component
	component_entities[_id][_entity_id] = component
	Logger.debug("- registered %s component for entity %s:%s " % [_id, entity, entity.name])

	return


# returns a component for an entity
func entity_get_component(entity_id, component_name):
#	Logger.trace("[ECS] entity_get_component")
	if (component_entities.has(component_name)):
		return component_entities[component_name][entity_id]


# returns true if the entity has the component
func entity_has_component(entity_id, component_name):
	Logger.trace("[ECS] entity_has_component")
	if component_entities.has(component_name):
		if component_entities[component_name].has(entity_id):
			return true
	return false



func entity_remove_component(entity, component_name):
	Logger.trace("[ECS] entity_remove_component")
	is_dirty = true

	var _entity_id = entity.get_instance_id()

	if not has_entity(_entity_id):
		Logger.warn("- entity %s:%s not registered " % [entity, entity.name])
		return

	var _id = component_name.to_lower()

	if not has_component(_id):
		Logger.warn("- component %s not registered " % [_id])
		return

	# remove entity
	component_entities[_id].erase(_entity_id)
	Logger.debug("- removed component %s for entity %s:%s" % [_id, entity, entity.name])

	return



# return component from the framework
func get_component(component_name):
	return component_entities[component_name]


# return all components
func get_all_components():
	return component_entities


# returns true if component already exists in the framework
func has_component(component_name):
	Logger.trace("[ECS] has_component")
	return component_entities.has(component_name)


# returns true if entity already exists
func has_entity(entity_id):
	Logger.trace("[ECS] has_entity")
	if entities.has(entity_id):
		return true

	return false

# returns true if the system already exists
func has_system(system_name):
	Logger.trace("[ECS] has_system")
	if systems.has(system_name):
		return true

	return false


# returns true if the system already exists
func has_group(group_name):
	Logger.trace("[ECS] has_group")
	if groups.has(group_name):
		return true

	return false


# rebuild system entities
#
# we do not force a build or rebuild of the
# system filters, instead we make the developer
# do it
#
# this will improve performance when adding and
# removing entities and components at runtime
#
func rebuild():
	Logger.trace("[ECS] rebuild")
	system_entities.clear()
	for _system in systems:
		if systems[_system].enabled:
			_add_system_entities(_system)

	is_dirty = false


# remove component from the framework
func remove_component(entity, component_name):
	Logger.trace("[ECS] remove_component")
	is_dirty = true

	var _key = component_name.to_lower()

	if has_component(_key):

		var _id = entity.get_instance_id()
		component_entities[_key].erase(_id)

		Logger.debug("- %s component was removed for entity %s:%s" % [_key, entity, entity.name])

	else:

		Logger.warn("Entity %s:%s does not exist" % [entity, entity.name])

	return


# queue an entity for removal in the scene
func remove_entity(entity):
	Logger.trace("[ECS] remove_entity")
	is_dirty = true
	if (entity.has_method("get_instance_id")):
		entity_remove_queue.append(entity.get_instance_id())


func remove_system(system_name):
	
	Logger.trace("[ECS] remove_system")

	var _id = system_name.to_lower()
	var _system = systems[system_name]

	if not has_system(_id):
		Logger.warn("- system %s is not registered, skipping" % [_id])
		return

	is_dirty = true

	# call on_before_remove if available
	if _system.has_method("on_before_remove"):
		_system.on_before_remove()

	# remove the system and create an empty list of component names
	systems.erase(_id)
	system_components.erase(_id)

	# call on_after_remove if available
	if _system.has_method("on_after_remove"):
		_system.on_after_remove()

	Logger.debug("- system %s has been removed" % [_id])


# update the systems, specified by group name (or not)
func update(group = null, delta = null):

	# rebuild if dirty
	if is_dirty:
		Logger.debug("- system is dirty, rebuilding indexes")
		rebuild()

	# if no delta is passed, use the current delta
	if not delta:
		delta = get_process_delta_time()

	var _delta = delta

	# if no group passed, do all systems
	if group == null:
		for _system in systems.values():
			if _system.enabled:
				_system.on_process(system_entities[str(_system.name).to_lower()], _delta)

	# process each system in this group group
	if (group && group_systems.has(group)):
		for _system_name in group_systems[group]:
			var _system = systems[_system_name]
			if _system.enabled:
				_system.on_process(system_entities[_system.name.to_lower()], _delta)

	# clean up entities queued for removal
	if entity_remove_queue.size() > 0:
		is_dirty = true
		for _entity_id in entity_remove_queue:
			if entities.has(_entity_id):
				entities[_entity_id].queue_free()
				entities.erase(_entity_id)

	# and clear the queue
	entity_remove_queue.clear()
	
	# full cleaning requested?
	if (do_clean):
		
		entities.clear()
		component_entities.clear()
		systems.clear()
		system_components.clear()
		system_entities.clear()
		groups.clear()
		group_systems.clear()
		entity_remove_queue.clear()
		do_clean = false

	return


func _add_system_entities(system_name):
	Logger.trace("[ECS] _add_system_entities")

	var _entities = []

	for entity_id in entities:

		if entities[entity_id] == null:
			continue
			
		if not entities[entity_id].enabled:
			continue

		var has_all_components = true
		for component in system_components[system_name]:

			if component.substr(0,1) == "!":
				var _component_id = component.substr(1,999)
				if (has_component(_component_id)):
					if component_entities[_component_id].has(entity_id):
						has_all_components = false
						break
					break
				break

			if not component_entities.has(component):
				has_all_components = false
				break

			if not component_entities[component].has(entity_id):
				has_all_components = false
				break

		if has_all_components:
			_entities.append(entities[entity_id])


	system_entities[system_name] = _entities


# do some cleanup
func _exit_tree():
	Logger.trace("[ECS] _exit_tree")
	clean()


func _init() -> void:
	print(" ")
	print("godot-stuff ECS")
	print("https://gitlab.com/godot-stuff/gs-ecs")
	print("Copyright 2018-2023, SpockerDotNet LLC")
	print("Version " + version)
	print(" ")
