## Example: Tick Source Setup
##
## This script demonstrates how to set up tick sources for your GECS world.
## Place this in your World node's _ready() method or in an autoload script.

extends Node


func _ready():
	# Wait for world to be ready
	await get_tree().process_frame

	# Example 1: Simple interval tick source
	# Creates a tick source that ticks every 2 seconds
	ECS.world.create_interval_tick_source(2.0, 'spawner-tick')

	# Example 2: Fast physics tick
	# Creates a tick source for high-frequency updates (50 Hz)
	ECS.world.create_interval_tick_source(0.02, 'physics-tick')

	# Example 3: Hierarchical timing
	# Create a chain of tick sources for time-based systems
	ECS.world.create_interval_tick_source(1.0, 'second')        # Every second
	ECS.world.create_rate_filter(60, 'second', 'minute')        # Every 60 seconds
	ECS.world.create_rate_filter(60, 'minute', 'hour')          # Every 60 minutes
	ECS.world.create_rate_filter(24, 'hour', 'day')             # Every 24 hours

	# Example 4: Manual tick source registration
	var custom_tick = AccumulatedTickSource.new()
	custom_tick.interval = 0.5
	ECS.world.register_tick_source(custom_tick, 'custom-tick')

	print("Tick sources registered:")
	print("  - spawner-tick: 2.0s interval")
	print("  - physics-tick: 0.02s interval")
	print("  - second: 1.0s interval")
	print("  - minute: 60 second ticks")
	print("  - hour: 60 minute ticks")
	print("  - day: 24 hour ticks")
	print("  - custom-tick: 0.5s accumulated")


## Example system using tick sources
class ExampleTimedSystem:
	extends System

	func tick() -> TickSource:
		# Return the tick source you want this system to use
		return ECS.world.get_tick_source('spawner-tick')

	func process(entities: Array[Entity], components: Array, delta: float) -> void:
		# This will only run when 'spawner-tick' ticks (every 2 seconds)
		# delta will be 2.0 for IntervalTickSource
		print("Timed system running with delta: ", delta)


## Example: Multiple systems sharing the same tick source
class PhysicsSystemA:
	extends System

	func tick() -> TickSource:
		return ECS.world.get_tick_source('physics-tick')

	func process(entities: Array[Entity], components: Array, delta: float) -> void:
		# Runs every 0.02 seconds
		pass


class PhysicsSystemB:
	extends System

	func tick() -> TickSource:
		return ECS.world.get_tick_source('physics-tick')

	func process(entities: Array[Entity], components: Array, delta: float) -> void:
		# Also runs every 0.02 seconds, SYNCHRONIZED with PhysicsSystemA
		pass


## Example: Daily event system
class DailyRewardSystem:
	extends System

	func tick() -> TickSource:
		return ECS.world.get_tick_source('day')

	func process(entities: Array[Entity], components: Array, delta: float) -> void:
		# This only runs once per 24 in-game hours
		grant_daily_rewards()

	func grant_daily_rewards():
		print("Granting daily rewards!")
