## Threat-response tuning for a sheep.
## Hysteresis: sheep starts fleeing inside flee_radius, calms down outside safe_radius.
## safe_radius must be greater than flee_radius to avoid flicker at the boundary.
class_name C_SheepThreat
extends Component

## Distance at which a sheep starts fleeing from a shepherd.
@export var flee_radius: float = 5.0
## Distance at which a fleeing sheep calms down. Must be > flee_radius.
@export var safe_radius: float = 8.0


func _init() -> void:
	# Invariant: hysteresis requires safe_radius > flee_radius.
	if safe_radius <= flee_radius:
		push_warning("C_SheepThreat: safe_radius (%s) must be > flee_radius (%s)" % [safe_radius, flee_radius])
