## This system is responsible for creating visuals for entities that have a C_Visuals component
## it adds the visuals and then adds the has visuals component to the entity
class_name VisualsSystem
extends System

func query():
    return q.with_all([C_Visuals]).with_none([C_HasVisuals])

func process(entity, _delta: float):
    var c_visuals = entity.get_component(C_Visuals) as C_Visuals
    entity.add_child(c_visuals.packed_scene.instantiate())
    
    entity.add_component(C_HasVisuals.new())