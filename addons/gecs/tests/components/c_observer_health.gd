## Test health component for observer tests with proper property_changed signal emission
class_name C_ObserverHealth
extends Component

@export var health: int = 100 : set = set_health
@export var max_health: int = 100 : set = set_max_health

func set_health(new_health: int):
	var old_health = health
	health = new_health
	# Emit signal for observers to detect the change
	property_changed.emit(self, "health", old_health, new_health)

func set_max_health(new_max: int):
	var old_max = max_health
	max_health = new_max
	# Emit signal for observers to detect the change
	property_changed.emit(self, "max_health", old_max, new_max)

func _init(_health: int = 100, _max_health: int = 100):
	health = _health
	max_health = _max_health
