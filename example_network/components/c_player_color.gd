class_name C_PlayerColor
extends Component


@export var color: Color = Color.WHITE:
    set(v):
        var old = color
        color = v
        property_changed.emit(self, "color", old, v)


func _init(_color: Color = Color.WHITE) -> void:
    color = _color