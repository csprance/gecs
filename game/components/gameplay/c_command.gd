## This component is used to handle commands
class_name C_Command
extends Component

## The name of the command to be executed (Or just 'generic command' if it's a generic command)
@export var name: String = 'generic command'
## the metadata about the command
@export var meta: Dictionary
## The callable function that will be executed when the system processes the entity
@export var command: Callable

