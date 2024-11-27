class_name VisualsSystem
extends System

func query():
    return q.with_all([C_Visuals])

func process(entity, _delta: float):
    var c_visuals = entity.get_component(C_Visuals) as C_Visuals
    entity.add_child(c_visuals.packed_scene.instantiate())
    # Remove the visuals component from the entity. and add a C_HasVisuals component
    entity.remove_component(C_Visuals)
    
    entity.add_component(C_HasVisuals.new())