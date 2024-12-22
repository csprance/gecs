## Tag Component that indicates an entity is interactable
## YOu will still need to mark the entity as interactable with C_CanInteractWith to interact with it
class_name C_Interactable
extends Component

## What interaction should we run
@export var action: Interaction
