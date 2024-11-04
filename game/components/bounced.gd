## The Bounced component is added to something when it bounced
## It is then removed in the bounce system and represents a single bounce
extends Component
class_name Bounced

##  What surface normal did we just bounce off
@export var normal := Vector2.AXIS_Y
