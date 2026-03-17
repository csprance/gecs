class_name C_LifecycleTest
extends Component

## Test component for COMP-01 / COMP-03 lifecycle regression tests.
##
## Exposes one @export property (preserved by duplicate(true)) and one
## plain var (reset to script default by duplicate(true)), so the two
## test cases can assert both sides of the bug independently.

@export var exported_value: int = 0
var non_exported_value: int = 0


func _init(_exported: int = 0, _non_exported: int = 0) -> void:
	exported_value = _exported
	non_exported_value = _non_exported
