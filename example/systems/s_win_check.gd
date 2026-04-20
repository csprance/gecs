## Updates a UI label each frame with "<penned>/<total>" and shows a win banner
## when every sheep has been penned.
class_name WinCheckSystem
extends System

@export var counter_label_path: NodePath
@export var win_label_path: NodePath

var _counter_label: Label
var _win_label: Label


func setup() -> void:
	if counter_label_path != NodePath():
		_counter_label = get_node_or_null(counter_label_path) as Label
	if win_label_path != NodePath():
		_win_label = get_node_or_null(win_label_path) as Label


func query() -> QueryBuilder:
	# We only need to run every frame; the actual counts come from two sub-queries below.
	return q.with_all([C_Sheep])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	var total := entities.size()
	var penned := ECS.world.query.with_all([C_Sheep, C_Penned]).execute().size()

	if _counter_label != null:
		_counter_label.text = "Penned: %d / %d" % [penned, total]

	if _win_label != null:
		_win_label.visible = total > 0 and penned == total
