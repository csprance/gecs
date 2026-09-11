extends Node
## Run with --remote-debug and --gecs-debug. The first hello and overview replies
## are intentionally dropped. Results are written to .godot/debugger_soak.json.
@export var duration_seconds := 300
var world: World
var components: Array = []
var started := 0
var frames := 0
var changes := 0
var next_burst := 0
var next_report := 0
var next_step := 0
var replies := {}
var drops := {"hello": 1, "overview": 1}
var by_second := {}
var total_bytes := 0
var errors: Array = []

class IdleSystem:
	extends System
	func _init() -> void: process_empty = true
	func query() -> QueryBuilder: return q.with_all([C_TestB])
	func process(_entities: Array[Entity], _components: Array, _delta: float) -> void: pass

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--gecs-soak-seconds="):
			duration_seconds = maxi(10, int(argument.get_slice("=", 1)))
	world = World.new()
	world.name = "SoakWorld"
	add_child(world)
	ECS.world = world
	for i in 100:
		var system := IdleSystem.new()
		system.name = "SoakSystem%d" % i
		world.add_system(system)
	for i in 10000:
		var entity := Entity.new()
		entity.name = "SoakEntity%d" % i
		var component := C_TestA.new(i)
		entity.add_component(component)
		world.add_entity(entity, null, false)
		components.append(component)
	started = Time.get_ticks_msec()
	GECSEditorDebuggerMessages._test_sink = _send
	world.debug_explorer()
	print("GECS_SOAK started: 10000 entities, 100 systems, injected hello/overview loss")

func _send(message: String, data: Array) -> void:
	var second := (Time.get_ticks_msec() - started) / 1000
	by_second[second] = int(by_second.get(second, 0)) + 1
	total_bytes += var_to_bytes(data).size()
	if message == "gecs:explorer_response":
		var op: String = data[0].op
		replies[op] = int(replies.get(op, 0)) + 1
		if data[0].result.has("error"): errors.append(data[0].result.error)
		if int(drops.get(op, 0)) > 0:
			drops[op] -= 1
			print("GECS_SOAK intentionally dropped ", op)
			return
	EngineDebugger.send_message(message, data)

func _process(delta: float) -> void:
	if world == null: return
	frames += 1
	for i in 1000:
		var component: C_TestA = components[(frames * 1000 + i) % components.size()]
		component.value += 1
		component.property_changed.emit(component, "value", component.value - 1, component.value)
		changes += 1
	var seconds := (Time.get_ticks_msec() - started) / 1000
	if seconds >= next_burst:
		next_burst = seconds + 2
		for i in 100:
			var entity := Entity.new()
			entity.add_component(C_TestA.new())
			world.add_entity(entity, null, false)
			world.remove_entity(entity)
	if seconds >= next_step:
		next_step = seconds + 30
		world.debug_set_sweep(false)
		world.debug_pause()
		world.process(delta)
		world.debug_step(GECSStepper.Kind.SYSTEM, 100)
		world.process(delta)
		world.debug_resume()
	world.process(delta)
	if seconds >= next_report:
		next_report = seconds + 30
		print("GECS_SOAK seconds=", seconds, " changes=", changes, " replies=", replies)
	if seconds >= duration_seconds:
		var peak := 0
		for count in by_second.values(): peak = maxi(peak, int(count))
		var report := {"seconds": seconds, "frames": frames, "property_changes": changes, "replies": replies, "remaining_drops": drops, "peak_messages_per_second": peak, "bytes": total_bytes, "errors": errors, "queue_limit": ProjectSettings.get_setting("network/limits/debugger/max_queued_messages"), "recovered": replies.get("hello", 0) >= 2 and replies.get("overview", 0) >= 2 and drops.hello == 0 and drops.overview == 0}
		var file := FileAccess.open("res://.godot/debugger_soak.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
		print("GECS_SOAK complete ", JSON.stringify(report))
		GECSEditorDebuggerMessages._test_sink = Callable()
		set_process(false)
		components.clear()
		world.purge()
		await get_tree().process_frame
		get_tree().quit(0 if report.recovered and errors.is_empty() else 1)
