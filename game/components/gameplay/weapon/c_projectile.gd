# The C_Projectile component defines the properties and behavior of a projectile.
# It specifies attributes such as visuals, damage, speed, collision scale, and lifetime.
# This component is added to entities to make them function as projectiles in the game.
class_name C_Projectile
extends Component

## When this flys through the air what visual scene does it use
@export var visuals: C_Visuals
## When this hits something what component does it add to the hit entity
@export var damage_component: Component
## How big the collision sphere is
@export var collision_radius:= 0.1
## How fast this moves
@export var speed:= 10.0
## How long this lasts
@export var lifetime: float = 5.0
## Does this projectile get affected by gravity
@export var affected_by_gravity: bool = true
## How wide the radius of the explosion is
@export var explosive_radius: float = 0.0
## Some initial velocity
@export var initial_velocity: Vector3 = Vector3.ZERO
## The impact effect to spawn when this hits something
@export var impact_effect: PackedScene = null