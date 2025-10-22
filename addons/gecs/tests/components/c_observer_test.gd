## Test component for observer tests with proper property_changed signal emission
class_name C_ObserverTest
extends Component

@export var value: int = 0 : set = set_value
@export var name_prop: String = "" : set = set_name_prop

func set_value(new_value: int):
	var old_value = value
	value = new_value
	# Emit signal for observers to detect the change
	property_changed.emit(self, "value", old_value, new_value)

func set_name_prop(new_name: String):
	var old_name = name_prop
	name_prop = new_name
	# Emit signal for observers to detect the change
	property_changed.emit(self, "name_prop", old_name, new_name)

func _init(_value: int = 0, _name: String = ""):
	value = _value
	name_prop = _name
