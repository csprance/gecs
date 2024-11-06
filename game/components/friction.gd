## Friction Component.[br]
## Represents friction applied to an entity, slowing it down over time.
## The [FrictionSystem] uses this component to reduce the entity's speed each frame.
class_name Friction
extends Component

## How much per frame is this thing slowed by
@export var coefficient := 0.998
