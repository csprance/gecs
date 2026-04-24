## Sheep entity — the "glue" layer between Godot's scene tree and the ECS world.
##
## Entity subclasses are the right home for scene-structure handles that don't
## belong in components. Rule of thumb for what lives here vs. in a C_* component:
##
##   Put it on the entity (glue) when:
##     • it's a reference to your OWN scene's structural child (NavigationAgent3D,
##       CollisionShape3D, AnimationPlayer, camera anchor)
##     • it never changes at runtime — no system ever adds/removes it
##     • no system queries by it (no with_all([C_NavAgent]) ever needed)
##     • a Resource can't serialize it anyway (Node references aren't data)
##
##   Put it in a component instead when:
##     • multiple entity types share the concept and should be queried uniformly
##     • a system filters by presence/absence of it
##     • it can appear, disappear, or swap at runtime
##     • it's pure data (numbers, vectors, enums, arrays)
##
## Everything on this class is glue; everything gameplay-relevant is a C_* component
## returned by define_components().
@tool
class_name Sheep
extends Entity

## Cached handle to this sheep's NavigationAgent3D child — resolved once at
## _ready so WanderSystem avoids a scene-tree walk per sheep per frame. Null
## on sheep scenes without a nav agent; systems handle that.
@onready var nav_agent: NavigationAgent3D = get_node_or_null(^"NavigationAgent3D")


func define_components() -> Array:
	return [
		C_Sheep.new(),
		C_SheepMovement.new(),
		C_SheepThreat.new(),
		C_Flocking.new(),
		C_Wander.new(),
		C_Velocity.new(),
	]
