## Damage Component.
##
## Represents damage to be applied to an entity.
## This component is added when an entity takes damage and is processed by the `DamageSystem`.
## After processing, the component is removed.
class_name Damage
extends Component

@export var amount := 1

