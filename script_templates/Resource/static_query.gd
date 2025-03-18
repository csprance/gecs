class_name _CLASS_
extends StaticQuery

## This is a static query, it is used to query the world for entities that match a certain criteria
## It can be passed around in the UI and should be reusable an simple.
func query():
	return ECS.world.query.with_all([]) # Create and return your query here but don't execute it yet.