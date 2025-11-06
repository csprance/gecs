## TickSource
##
## Base class for custom tick sources that control system execution timing.
##
## Tick sources determine when systems run and what delta value they receive.
## The base implementation passes through the frame delta (default behavior).
## Override [method update] to create custom timing behaviors.
##
## [b]Example (Custom tick source):[/b]
## [codeblock]
## class_name RandomTickSource extends TickSource
##
## var probability: float = 0.5
##
## func update(delta: float) -> float:
##     if randf() < probability:
##         last_delta = delta
##     else:
##         last_delta = 0.0  # Skip this frame
##     return last_delta
## [/codeblock]
class_name TickSource
extends Resource

## The delta value from the last update (0.0 = didn't tick this frame)
var last_delta: float = 0.0


## Called every frame by World.process()
## Must set last_delta and return it
## [param delta] The frame delta time
## [return] The delta value to pass to systems (0.0 to skip this frame)
func update(delta: float) -> float:
	last_delta = delta  # Pass through - override in subclasses
	return last_delta


## Reset tick source state
## Override this to reset custom state variables
func reset() -> void:
	last_delta = 0.0
