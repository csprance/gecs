## Indicates the entity is fatigued and needs to rest
class_name C_Fatigued
extends Component

## The duration of the fatigued state
@export var duration: float = 1.0

## The timer for the fatigued state
var timer: float = 0.0