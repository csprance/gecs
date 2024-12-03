# We attach this and other components to an entity to handle events
# This way we can create systems that listen for these events and react to them in a single place
class_name C_Event
extends Component

## Each Event should have a new Enum created for it 
enum EventType {
    GENERIC = 0
}

## The Event Type Enum
@export var type: EventType = EventType.GENERIC
## The metadata about the event
@export var meta: Dictionary = {}