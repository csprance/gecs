class_name ECSDebug
extends CanvasLayer

@onready var tree: Tree = %Tree
var root: TreeItem

# Called when the node enters the scene tree for the first time.
func create_debug_window() -> void:
    tree.columns = 1
    root = tree.create_item()
    tree.hide_root = true
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
    Loggie.debug('Added Entity: ', entity)
    var entity_child = tree.create_item(root)
    entity_child.set_text(0, str(entity))
    var subchild1 = tree.create_item(entity_child)
    subchild1.set_text(0, "Component")

func _remove_entity(entity:Entity):
    Loggie.debug('Removed Entity: ', entity)

## Adds and entity and components to the debug list
func _add_system(system:System):
    Loggie.debug('Added System: ', system)
    var entity_child = tree.create_item(root)
    entity_child.set_text(0, system.get_script().get_class())
    var subchild1 = tree.create_item(entity_child)
    subchild1.set_text(0, "Component")

func _remove_system(system:System):
    Loggie.debug('Removed System: ', system)

func _remove_component(entity: Entity, component):
    Loggie.debug('Removed Component: ', entity, component)

func _add_component(entity: Entity, component):
    Loggie.debug('Added Component: ', entity, component)