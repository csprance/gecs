## Added to an Entity when they are using items
class_name C_UsingItems
extends Component

@export var items: Array[C_Item]

func _init(_items: Array[C_Item]):
    items = _items