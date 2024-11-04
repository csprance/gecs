## A Bounce component is modified when an Entity enters a bounce area
## When it enters a collision area so it makes it bounce the other way
class_name Bounce
extends Component

## What what is the surface normal of the bounce
@export var normal := Vector2.ZERO
## Should we bounce?
@export var should_bounce := true
