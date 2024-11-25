class_name DebugLabel3DSystem
extends System

var debug_labels = {}
@export var debug_label_scene : PackedScene

func query():
    return q.with_all([C_DebugLabel, C_Transform])

func process(entity, _delta):
    var c_debug_label = entity.get_component(C_DebugLabel) as C_DebugLabel
    if debug_labels.has(entity):
        var label = debug_labels[entity]
        label.text = c_debug_label.text
        label.global_transform.origin = entity.get_component(C_Transform).transform.origin + c_debug_label.offset
    else:
        var label = create_label(c_debug_label)
        add_child(label)
        debug_labels[entity] = label

func create_label(c_debug_label: C_DebugLabel):
    var label = debug_label_scene.instantiate() as DebugLabel
    label.text = c_debug_label.text
    return label