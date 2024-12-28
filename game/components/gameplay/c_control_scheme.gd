class_name C_ControlScheme
extends Component


enum ControlScheme {
    MOUSE_AND_KEYBOARD,
    CONTROLLER,
}

@export var control_scheme: ControlScheme = ControlScheme.MOUSE_AND_KEYBOARD