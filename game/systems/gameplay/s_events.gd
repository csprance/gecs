class_name EventSystem
extends System

func query():
    return q.with_all([C_Event])

func process(entity, _delta: float):
    var c_event = entity.get_component(C_Event) as C_Event
    
    # Handle the event based on the type
    match c_event.type:
        C_Event.EventType.GENERIC:
            Loggie.debug('Generic Event', c_event.meta)
        _: # default case
            print('Unknown Event')
    
    # Remove the event component after processing
    entity.remove_component(C_Event)
