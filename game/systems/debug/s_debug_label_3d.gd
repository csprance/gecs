class_name DebugLabel3DSystem
extends System

var debug_labels = {}
@export var debug_label_scene : PackedScene


func setup() -> void:
    ECS.world.entity_removed.connect(_cleanup_labels)


func query():
    return q.with_all([C_DebugLabel, C_Transform])


func process(entity, _delta):
    var c_debug_label = entity.get_component(C_DebugLabel) as C_DebugLabel
    if debug_labels.has(entity):
        var label = debug_labels.get(entity)
        if not label:
            debug_labels.erase(entity)
            return
        label.text = c_debug_label.text
        label.global_transform.origin = entity.get_component(C_Transform).transform.origin + c_debug_label.offset
    else:
        var label = create_label(c_debug_label)
        entity.add_child(label)
        debug_labels[entity] = label


func create_label(c_debug_label: C_DebugLabel):
    var label = debug_label_scene.instantiate() as DebugLabel
    label.text = c_debug_label.text
    return label


func _cleanup_labels(entity):
    print('Cleaning up labels')
     # Clean it up if it's dead
    if debug_labels.has(entity):
        var label = debug_labels[entity]
        label.queue_free()
        debug_labels.erase(entity)