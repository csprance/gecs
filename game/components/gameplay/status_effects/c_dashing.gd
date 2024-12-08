class_name C_Dashing
extends Component

## How fast the dash happens
@export var duration: float = 1.5
## The cooldown of the dashing (How long between dashes[can Only have one Dash Component at a time])
@export var cooldown: float = 7.0
## Where we're dashing to
@export var start: Vector3
## Where we started dashing from
@export var end: Vector3

## The timer for the dash
var timer: float = 0.0
## How much velocity we need to get to where we're going
var velocity: Vector3

func _init(_start: Vector3, _end:Vector3, _duration: float, _cooldown: float) -> void:
    start= _start
    end= _end
    duration= _duration
    cooldown= _cooldown
    # We know the start and end and how long it should take. SO now we need to calcuate the velocity needed to make that with ease in
    velocity = (end - start) / duration
