# The WeaponUtils class provides utility functions for weapon operations.
# It includes methods to get projectile components, create projectile transforms, and instantiate projectiles.
# This class is used to support weapon functionality like shooting and projectile management.
class_name WeaponUtils

## Gets the projectile component from the entity.
static func get_projectile_component(entity: Entity) -> C_Projectile:
	var c_weapon = entity.get_component(C_Weapon) as C_Weapon
	if c_weapon and c_weapon.projectile:
		return c_weapon.projectile
	else:
		push_error("Entity lacks C_Weapon component or projectile is null.")
		return null


# Creates a transform for the projectile based on the entities position and direction.
static func create_projectile_transform(entity: Entity, direction: Vector3):
	var c_trs = entity.get_component(C_Transform) as C_Transform
	var transform = Transform3D()
	
	# Position the projectile slightly in front of the entity.
	transform.origin = c_trs.transform.origin + direction
	# bring it up off the ground by 1 unit
	transform.origin.y += 1.0
	
	# Orient the projectile to face the shooting direction.
	transform.basis = Basis.looking_at(direction, Vector3.UP)
	return transform


# Instantiates the projectile entity and initializes its components.
static func instantiate_projectile(c_projectile: C_Projectile, transform: Transform3D):
	var e_projectile = Constants.projectile_scene.instantiate() as Projectile
	if not e_projectile:
		assert(false, "Failed to instantiate projectile entity.")
		return

	# Create the transform component for the projectile.
	var c_trs = C_Transform.new(transform)

	# Add a lifetime component to handle the projectile's lifespan.
	var c_lifetime = C_Lifetime.new(c_projectile.lifetime)

	# Create the visuals component for the projectile entity.
	var c_projectile_visuals = C_Visuals.new(c_projectile.visuals.packed_scene)

	# Set up the velocity component using initial_velocity or calculated speed.
	var c_velocity = C_Velocity.new(-transform.basis.z * c_projectile.speed + c_projectile.initial_velocity )

	# Add initial components to the projectile entity.
	e_projectile.add_components([c_trs, c_projectile, c_projectile_visuals, c_velocity, c_lifetime])

	# If the projectile is affected by gravity, add a gravity component.
	if c_projectile.affected_by_gravity:
		var c_gravity = C_Gravity.new()
		e_projectile.add_component(c_gravity)

	# Add the projectile entity to the ECS world.
	ECS.world.add_entity(e_projectile)
	# set the collision shape radius after it's ready (since it's an onready var)
	
	# FIXME: we should move the projectile forward the amount of the radius so we don't hit the player
	e_projectile.collision_shape_3d.shape.radius = c_projectile.collision_radius

	# Set the explosion radius shape radius to the projectile's explosive radius so we can capture anything inside the explosion
	e_projectile.explosion_radius_shape_3d.shape.radius = c_projectile.explosive_radius

	return e_projectile
