## Health Component.
##
## Represents the health of an entity.
## Stores both the total and current health values.
## Used by systems to determine if an entity should be destroyed when health reaches zero.
class_name Health
extends Component

## How much total health this has
@export var total := 1
## The current health
@export var current := 1
