## Bounced [Component][br]
## Added to an entity when it has just bounced off a surface.
## Stores information about the bounce, such as the surface normal.
## The [BounceSystem] processes entities with this component and removes it after handling the bounce.
class_name C_Bounced
extends Component

##  What surface normal did we just bounce off
@export var normal := Vector2.UP