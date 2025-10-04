extends Component
class_name C_Persistent

@export var player_name: String = "Player1"
@export var level: int = 1
@export var health: float = 100.0
@export var position: Vector2 = Vector2.ZERO
@export var inventory: Array[String] = []

func _init(
	_player_name: String = "Player1",
	_level: int = 1,
	_health: float = 100.0,
	_position: Vector2 = Vector2.ZERO,
	_inventory: Array[String] = []
):
	player_name = _player_name
	level = _level
	health = _health
	position = _position
	inventory = _inventory
