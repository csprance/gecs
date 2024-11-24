## Manages all the C_Timer components
class_name TimersSystem
extends System

func query():
    return q.with_all([C_Timer])

func process(entity, delta):
    var c_timer = entity.get_component(C_Timer) as C_Timer
    # If the timer isn't active, don't do anything
    if not c_timer.active:
        return
    # Count up based on delta
    c_timer.value += delta
    # If we're done, call the callback
    if c_timer.value >= c_timer.duration:
        c_timer.callback.call(entity)
        # If we're repeating, reset the timer
        if c_timer.repeat:
            c_timer.value = 0
        else:
            # Otherwise, remove the timer
            entity.remove_component(C_Timer)