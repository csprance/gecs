## Attached to an Area3D child of a sheep entity. When another FlockArea
## enters / exits this one, it records the relationship so flocking code can
## look up neighbors via [method Entity.get_relationships] instead of doing
## per-frame distance math against every sheep.
class_name FlockArea
extends Area3D

## Reused C_Flockmate component instance for building per-call relationship
## patterns. The full Relationship can't be cached here because the target
## entity differs per signal — but the component side can be shared.
## Safe: has_relationship / remove_relationship / add_relationship only read
## the component's type; the instance is never mutated.
static var _FLOCKMATE_COMPONENT: C_Flockmate = C_Flockmate.new()

var _owner_entity: Entity


func _ready() -> void:
	_owner_entity = _find_owner_entity()
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _find_owner_entity() -> Entity:
	var node: Node = get_parent()
	while node != null and not (node is Entity):
		node = node.get_parent()
	return node as Entity


func _on_area_entered(other: Area3D) -> void:
	if other == self or not (other is FlockArea):
		return
	var other_entity: Entity = (other as FlockArea)._owner_entity
	if _owner_entity == null or other_entity == null or _owner_entity == other_entity:
		return
	# Only add if not already present — area signals can re-fire on physics layer changes.
	var pattern := Relationship.new(_FLOCKMATE_COMPONENT, other_entity)
	if not _owner_entity.has_relationship(pattern):
		_owner_entity.add_relationship(pattern)


func _on_area_exited(other: Area3D) -> void:
	if other == self or not (other is FlockArea):
		return
	var other_entity: Entity = (other as FlockArea)._owner_entity
	if _owner_entity == null or other_entity == null:
		return
	_owner_entity.remove_relationship(Relationship.new(_FLOCKMATE_COMPONENT, other_entity), 1)
