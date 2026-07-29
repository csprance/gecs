## A tick source that controls when systems execute.
##
## Systems with a [member System.tick_source] only run when the timer's [member ticked]
## flag is true. Multiple systems can share the same [SystemTimer] instance to guarantee
## they execute on the exact same frame.
##
## [b]Example — interval timer:[/b]
## [codeblock]
## var timer = SystemTimer.new()
## timer.interval = 0.5  # tick every 500ms
## system_a.tick_source = timer
## system_b.tick_source = timer  # synchronized with system_a
## [/codeblock]
##
## [b]Example — one-shot timeout:[/b]
## [codeblock]
## var timer = SystemTimer.new()
## timer.interval = 3.0
## timer.single_shot = true  # fires once, then deactivates
## intro_system.tick_source = timer
## [/codeblock]
class_name SystemTimer
extends RefCounted

## Seconds between ticks (must be > 0).
var interval: float = 1.0
## If true, the timer fires once and then sets [member active] to false.
var single_shot: bool = false
## Whether this timer is running. Inactive timers never tick.
var active: bool = true
## Accumulated time since the last tick (carries overshoot to prevent drift).
var time_elapsed: float = 0.0
## True only during the frame in which this timer ticked. Reset at the start of [method advance].
var ticked: bool = false
## Total number of times this timer has ticked since creation or last [method reset].
var tick_count: int = 0


## Advance the timer by [param delta] seconds.[br]
## Called once per group by [World] before systems are processed.
## Sets [member ticked] to true if the interval has elapsed.
func advance(delta: float) -> void:
	ticked = false
	if not active:
		return
	time_elapsed += delta
	if time_elapsed >= interval:
		ticked = true
		tick_count += 1
		time_elapsed = time_elapsed - interval
		if single_shot:
			active = false


## Reset the timer to its initial state (active, zero elapsed, zero ticks).
func reset() -> void:
	time_elapsed = 0.0
	tick_count = 0
	ticked = false
	active = true
