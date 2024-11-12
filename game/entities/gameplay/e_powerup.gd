class_name Powerup
extends Entity

@export var type: C_Powerup.PowerupType = C_Powerup.PowerupType.CAPTURE
@export var time: float = 10.0

func on_ready():
    Utils.sync_transform(self)

func _on_area_2d_body_entered(body:Node2D) -> void:
    # Only paddles can pickup powerup
    if body is Paddle:
        var powerup = C_Powerup.new()
        powerup.type = type
        powerup.time = time

        body.add_component(powerup)
        ## Remove the component
        ECS.world.remove_entity(self)
