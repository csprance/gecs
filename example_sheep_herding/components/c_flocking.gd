## Flocking-behavior tuning (separation / alignment / cohesion weights).
## Reusable across any herd animal — not sheep-specific.
## Perception radius itself is driven by the FlockArea Area3D on the entity's scene.
class_name C_Flocking
extends Component

@export_group("Separation")
## Inside this distance flockmates push each other apart.
@export var separation_distance: float = 1.1
## Weight of the separation steering component.
@export var separation_weight: float = 1.6

@export_group("Alignment & Cohesion")
## Weight of the heading-alignment steering component.
@export var alignment_weight: float = 0.6
## Weight of the pull-toward-flock-center steering component.
@export var cohesion_weight: float = 0.5

@export_group("Blend")
## How strongly flocking bends the intended (wander/flee) direction (0..1-ish).
@export var flock_influence: float = 0.6
