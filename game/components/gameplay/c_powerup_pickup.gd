## The component attached to an entity to indicate it is a power 
## up that can be picked up but has not yet
class_name C_PowerupPickup
extends Component

## What powerup pickup does this component contain
@export var type: C_Powerup.PowerupType
## How long does the powerup last when picked up
@export var time: float = 5.0
