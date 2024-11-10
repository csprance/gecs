## Bounce [Component].[br]
## Indicates that an entity can bounce off surfaces.[br]
## Used by the [BounceSystem] to determine if the [Entity] should bounce upon collision.[br]
## When an entity with a [Bounce] [Component] enters a collision area, it may reverse its direction.[br]
class_name C_Bouncable
extends Component

## If true, the entity will bounce upon collision.
@export var should_bounce := true
## How bouncy is this thing?
@export var bounciness := 1.0  # Increased from 0.1 to 1.0
