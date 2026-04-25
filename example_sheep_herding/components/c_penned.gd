## Terminal marker — C_Penned is never removed once added.
## Added when a sheep enters a pen's trigger volume. Its presence flips
## WanderSystem's goal-picker so new wander targets are sampled inside the pen
## (instead of around the sheep), and excludes the sheep from FleeSystem so
## the shepherd can't scare it back out. The sheep keeps its normal wander /
## flock loop — it just has a smaller, on-pen sandbox to roam in.
class_name C_Penned
extends Component

## Pen center in world space. Wander targets are picked around this point.
@export var center: Vector3 = Vector3.ZERO
## Horizontal radius of the pen. Wander targets stay inside this radius
## (with a small inset to avoid the boundary).
@export var radius: float = 0.0
