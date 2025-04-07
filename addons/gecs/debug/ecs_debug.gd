class_name ECSDebug
extends CanvasLayer


@onready var query_line_edit: LineEdit = %QueryLineEdit

@onready var tree: Tree = %Tree
var root: TreeItem

# Variables to store references
var entities_item
var systems_item
var components_item
var entity_items = {}
var system_items = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tree.columns = 1
	root = tree.create_item()
	tree.hide_root = true
	# Create main categories
	entities_item = tree.create_item(root)
	entities_item.set_text(0, "Entities")
	systems_item = tree.create_item(root)
	systems_item.set_text(0, "Systems")
	components_item = tree.create_item(root)
	components_item.set_text(0, "Components")
	_setup_signals()

func _setup_signals():
	# We listen to the signals from the world to update/remove tree items from the list
	# Entities
	ECS.world.entity_added.connect(_add_entity)
	ECS.world.entity_removed.connect(_remove_entity)
	# Components
	ECS.world.component_added.connect(_add_component)
	ECS.world.component_removed.connect(_remove_component)
	# System
	ECS.world.system_added.connect(_add_system)
	ECS.world.system_removed.connect(_remove_system)

## Adds and entity and components to the debug list
func _add_entity(entity: Entity):
	var entity_item = tree.create_item(entities_item)
	entity_item.set_text(0, str(entity))
	entity_items[entity] = entity_item
	_update_entity_components(entity)

func _remove_entity(entity: Entity):
	if entity_items.has(entity):
		tree.remove_item(entity_items[entity])
		entity_items.erase(entity)

func _update_entity_components(entity: Entity):
	if not entity_items.has(entity):
		return  # Entity not tracked, so we can't update it
	var entity_item = entity_items[entity]
	# Remove all child items
	var child = entity_item.get_first_child()
	while child:
		var next = child.get_next()
		entity_item.remove_child(child)
		child = next
	for component in entity.components.values():
		var component_item = tree.create_item(entity_item)
		component_item.set_text(0, component.get_script().get_class())
		# Add properties under each component
		for property in component.get_property_list():
			var property_item = tree.create_item(component_item)
			property_item.set_text(0, "%s: %s" % [property.name, str(component.get(property.name))])


## Adds and entity and components to the debug list
func _add_system(system: System):
	var system_item = tree.create_item(systems_item)
	system_item.set_text(0, system.get_script().get_class())
	system_items[system] = system_item
	# Add system details
	var group_item = tree.create_item(system_item)
	group_item.set_text(0, "Group: %s" % system.group)
	var active_item = tree.create_item(system_item)
	active_item.set_text(0, "Active: %s" % str(system.active))

func _remove_system(system: System):
	if system_items.has(system):
		#tree.remove_item(system_items[system])
		system_items.erase(system)

func _remove_component(entity: Entity, component):
	_update_entity_components(entity)

func _add_component(entity: Entity, component):
	_update_entity_components(entity)


func _on_window_close_requested() -> void:
	queue_free()
