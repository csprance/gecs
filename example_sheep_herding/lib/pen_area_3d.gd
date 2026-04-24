## Attached to the Area3D child of a pen Entity. When a body (sheep) enters
## the area, emits the &"sheep_entered_pen" ECS event so the
## O_SheepEnteredPen observer can tag the sheep with C_Penned.
##
## No body_exited handler — penning is terminal (one-way) by design.
class_name PenArea3D
extends Area3D

## Cached owning pen entity (walked up the scene tree in _ready).
var _owner_entity: Entity


func _ready() -> void:
	_owner_entity = _find_owner_entity()
	body_entered.connect(_on_body_entered)


func _find_owner_entity() -> Entity:
	var node: Node = get_parent()
	while node != null and not (node is Entity):
		node = node.get_parent()
	return node as Entity


func _on_body_entered(body: Node) -> void:
	if _owner_entity == null:
		return
	var sheep_entity := _find_entity_for_body(body)
	if sheep_entity == null:
		return
	if not sheep_entity.has_component(C_Sheep):
		return
	if sheep_entity.has_component(C_Penned):
		return
	ECS.world.emit_event(&"sheep_entered_pen", sheep_entity, _owner_entity)


func _find_entity_for_body(body: Node) -> Entity:
	var node: Node = body
	while node != null and not (node is Entity):
		node = node.get_parent()
	return node as Entity
