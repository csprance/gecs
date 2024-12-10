# The C_Lifetime component manages the lifespan of an entity.
# It ensures that entities are removed from the game after a specified duration.
# This component is used for entities like projectiles or temporary effects that should not persist indefinitely.
class_name C_Lifetime
extends Component

@export var lifetime: float = 1.0

func _init(_lifetime=1.0) -> void:
    lifetime = _lifetime
