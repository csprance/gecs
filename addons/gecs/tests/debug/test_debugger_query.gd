extends GdUnitTestSuite
## Game-side ad-hoc query runner: World._run_debugger_query() evaluates a typed
## QueryBuilder expression via Godot's Expression and replies with matching entity
## ids. Exercised through the test sink so no live editor session is needed.

var runner: GdUnitSceneRunner
var world: World

var _saved_attached: bool
var _saved_cache: int
var _saved_sink: Callable
var _captured: Array = []


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func before_test():
	_saved_attached = GECSEditorDebuggerMessages.attached
	_saved_cache = GECSEditorDebuggerMessages._attached_cache
	_saved_sink = GECSEditorDebuggerMessages._test_sink
	_captured = []
	GECSEditorDebuggerMessages._test_sink = func(m, d): _captured.append([m, d])
	GECSEditorDebuggerMessages.refresh_attached()


func after_test():
	GECSEditorDebuggerMessages._test_sink = _saved_sink
	GECSEditorDebuggerMessages._attached_cache = _saved_cache
	GECSEditorDebuggerMessages.attached = _saved_attached
	if world:
		world.purge(false)


## Return the payload [ids, error] of the most recent ENTITY_QUERY_RESULT send.
var _result: Dictionary = {}
func _query(text: String) -> void:
	_result = world.debug_explorer().query({"text": text})

func _last_result() -> Array:
	return [_result.get("ids", []), _result.get("error", "")]


func _spawn(components: Array) -> Entity:
	var e := Entity.new()
	for c in components:
		e.add_component(c)
	world.add_entity(e, null, false)
	return e


func test_with_all_returns_only_matching() -> void:
	var a := _spawn([C_TestA.new()])
	var b := _spawn([C_TestB.new()])
	_query("q.with_all([C_TestA])")
	var res := _last_result()
	assert_bool(res.is_empty()).is_false()
	assert_str(res[1]).is_equal("")
	var ids: Array = res[0]
	assert_bool(ids.has(a.get_instance_id())).is_true()
	assert_bool(ids.has(b.get_instance_id())).is_false()


func test_with_none_excludes() -> void:
	var only_a := _spawn([C_TestA.new()])
	var a_and_b := _spawn([C_TestA.new(), C_TestB.new()])
	_query("q.with_all([C_TestA]).with_none([C_TestB])")
	var ids: Array = _last_result()[0]
	assert_bool(ids.has(only_a.get_instance_id())).is_true()
	assert_bool(ids.has(a_and_b.get_instance_id())).is_false()


func test_trailing_execute_is_accepted() -> void:
	var a := _spawn([C_TestA.new()])
	_query("q.with_all([C_TestA]).execute()")
	var res := _last_result()
	assert_str(res[1]).is_equal("")
	assert_bool((res[0] as Array).has(a.get_instance_id())).is_true()


func test_parse_error_is_reported() -> void:
	_query("q.with_all([C_TestA]")  # missing bracket + paren
	var res := _last_result()
	assert_str(res[1]).is_not_equal("")
	assert_bool((res[0] as Array).is_empty()).is_true()


func test_empty_query_reports_error() -> void:
	_query("   ")
	var res := _last_result()
	assert_str(res[1]).is_not_equal("")
	assert_bool((res[0] as Array).is_empty()).is_true()
