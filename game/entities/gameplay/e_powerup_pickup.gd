## The Powerup Pickup falls downward and when it hits the paddle it adds components
class_name PowerupPickup
extends Entity

## This should be an array of Power up Components
@export var powerups: Array[Component]

func on_ready():
	Utils.sync_transform(self)

## 
func _on_area_2d_body_entered(body: Node2D) -> void:
	# Only paddles can pickup powerups
	if body is Paddle:
		# Get a random powerup from the list of powerups and add it to the entity
		var powerup = powerups[randi_range(0, powerups.size()-1)].duplicate()
		Loggie.debug('Adding powerup %s' % powerup.get_script().resource_path)
		
		# Create an event entity to handle the logic of pickup
		Utils.create_ecs_event([C_PowerupPickedUp.new(powerup)])

		# Remove the powerup pickup entity
		ECS.world.remove_entity(self)
