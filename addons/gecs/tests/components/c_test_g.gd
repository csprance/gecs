class_name C_TestG
extends Component

@export var value: int = 0

static var init_count: int = 0

func _init(_value: int = 0):
	value = _value
	init_count += 1
	# to test _init() calling problem
	print("Component c_test_g init, value=%d" % value)
