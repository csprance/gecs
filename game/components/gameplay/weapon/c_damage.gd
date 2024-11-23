## Damage Component.[br]
## Represents damage to be applied to an entity.[br]
## This component is added when an entity affects the [Health] and is processed by the [DamageSystem].
## After processing, the component is removed.
class_name C_Damage
extends Component

## How much Damage was just done
@export var amount := 1

