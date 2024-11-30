class_name WeaponUtils

## Gets the projectile component from the entity.
static func get_projectile_component(entity: Entity) -> C_Projectile:
	var c_weapon = entity.get_component(C_Weapon) as C_Weapon
	var c_projectile = c_weapon.projectile
	return c_projectile


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

	# Create our visuals component for the projectile entity.
	var c_projectile_visuals = C_Visuals.new(c_projectile.visuals.packed_scene)
	
	# Add initial components to the projectile entity.
	e_projectile.add_components([c_trs, c_projectile, c_projectile_visuals])

	# Add the projectile entity to the ECS world.
	ECS.world.add_entity(e_projectile)

	# Set up the velocity component for the projectile.
	var c_velocity = C_Velocity.new()
	c_velocity.speed = c_projectile.speed
	c_velocity.direction = -transform.basis.z

	# Add remaining components after adding to the world.
	e_projectile.add_components([c_velocity])

	return e_projectile

