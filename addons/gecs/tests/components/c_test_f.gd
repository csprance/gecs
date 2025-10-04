class_name C_TestF
extends Component

var value: int = 0 # properties with no export annotation

static var init_count: int = 0

func _init(_value: int = 0):
	value = _value
	init_count += 1
	print("Component c_test_f init, value=%d" % value)
