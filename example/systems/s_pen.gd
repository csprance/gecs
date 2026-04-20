## Marks sheep as penned once they enter the pen's radius. Adds both a C_Penned
## tag and a Relationship(C_PennedIn, <pen entity>) so later queries can either
## filter by tag or ask "which pen is this sheep in?".
class_name PenSystem
extends System


func query() -> QueryBuilder:
	return q.with_all([C_Sheep]).with_none([C_Penned])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	var pen := ECS.world.query.with_all([C_Pen]).execute_one()
	if pen == null:
		return

	var pen_comp := pen.get_component(C_Pen) as C_Pen
	var pen_pos := (pen as Node3D).global_position

	for entity in entities:
		var dist := (entity as Node3D).global_position.distance_to(pen_pos)
		if dist < pen_comp.radius:
			cmd.add_component(entity, C_Penned.new())
			cmd.add_relationship(entity, Relationship.new(C_PennedIn.new(), pen))
