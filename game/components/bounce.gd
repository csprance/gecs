## Bounce Component.
##
## Indicates that an entity can bounce off surfaces.
## Used by the `BounceSystem` to determine if the entity should bounce upon collision.
## When an entity with a `Bounce` component enters a collision area, it may reverse its direction.
class_name Bounce
extends Component

## If true, the entity will bounce upon collision.
@export var should_bounce := true
