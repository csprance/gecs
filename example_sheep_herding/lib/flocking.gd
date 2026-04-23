## Relationship-driven flocking helper.
## Neighbors are discovered via C_Flockmate relationships populated by FlockArea
## signals — no per-frame O(N^2) distance scan. Steering blends separation,
## alignment, and cohesion on the XZ plane.
class_name Flocking


## Cached "any flockmate" relationship pattern — wildcard target, passed to
## [method Entity.get_relationships] so it matches every C_Flockmate
## relationship on the entity regardless of which sheep it points to.
## Naming: R_* prefix marks a pre-built Relationship instance, mirroring
## the C_* convention for components.
## Saves a Relationship + Component allocation per sheep per frame.
static var R_AnyFlockmate: Relationship = Relationship.new(C_Flockmate.new(), null)


## [param self_node] The sheep asking for steering.
## [param self_entity] The sheep Entity — used to look up C_Flockmate relationships.
## [param c_flocking] The sheep's C_Flocking tuning (weights / separation distance).
## Returns: an XZ steering direction, magnitude ~ [0, 1+]. Vector3.ZERO when alone.
static func compute(self_node: Node3D, self_entity: Entity, c_flocking: C_Flocking) -> Vector3:
	var rels := self_entity.get_relationships(R_AnyFlockmate)
	if rels.is_empty():
		return Vector3.ZERO

	var separation := Vector3.ZERO
	var alignment := Vector3.ZERO
	var cohesion_center := Vector3.ZERO
	var count := 0
	var sep_count := 0
	var sep_sq := c_flocking.separation_distance * c_flocking.separation_distance
	var self_pos := self_node.global_position

	for rel in rels:
		var other_entity := rel.target as Entity
		if other_entity == null or not is_instance_valid(other_entity):
			continue
		var other_node := (other_entity as Node) as Node3D
		if other_node == null:
			continue

		var to_other := other_node.global_position - self_pos
		to_other.y = 0.0
		var dist_sq := to_other.length_squared()
		if dist_sq == 0.0:
			continue

		count += 1
		cohesion_center += other_node.global_position

		var other_forward := -other_node.global_transform.basis.z
		other_forward.y = 0.0
		alignment += other_forward

		if dist_sq < sep_sq:
			separation -= to_other / dist_sq
			sep_count += 1

	if count == 0:
		return Vector3.ZERO

	if sep_count > 0 and not separation.is_zero_approx():
		separation = separation.normalized()
	if not alignment.is_zero_approx():
		alignment = (alignment / float(count)).normalized()

	var to_center := cohesion_center / float(count) - self_pos
	to_center.y = 0.0
	var cohesion := Vector3.ZERO
	if not to_center.is_zero_approx():
		cohesion = to_center.normalized()

	var steering := (
		separation * c_flocking.separation_weight
		+ alignment * c_flocking.alignment_weight
		+ cohesion * c_flocking.cohesion_weight
	)
	steering.y = 0.0
	return steering
