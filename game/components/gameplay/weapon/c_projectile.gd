class_name C_Projectile
extends Component

## When this flys through the air what visual scene does it use
@export var projectile_visuals: PackedScene
## When this hits something what component does it add to the hit entity
@export var damage_component: Component
