class_name C_Projectile
extends Component

## When this flys through the air what visual scene does it use
@export var visuals: C_Visuals
## When this hits something what component does it add to the hit entity
@export var damage_component: Component
## How big the collision sphere is
@export var collision_scale:= Vector3.ONE
## How fast this moves
@export var speed:= 10.0
## How many hitboxes can we go through
@export var pass_through_hitboxes:= 1

var cur_pass_through_hitboxes:= 0