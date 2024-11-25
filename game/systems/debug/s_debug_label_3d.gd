class_name DebugLabel3DSystem
extends System

var debug_labels = {}


func query():
    return q.with_all([C_DebugLabel, C_Transform])

func process(entity, delta):
    if debug_labels.has(entity):
        var label = debug_labels[entity]
        label.text = entity.get_component(C_DebugLabel).value
        label.global_transform.origin = entity.get_component(C_Transform).transform.origin
    else:
        var label = create_label(entity)
        debug_labels[entity] = label

func create_label(entity):
    var label = DebugLabel.new()
    label.text = entity.get_component(C_DebugLabel).value
    return label