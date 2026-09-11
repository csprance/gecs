extends GdUnitTestSuite
## Session scheduler tests use fake time and transport, never wall-clock sleeps.
var now := 0
var model: GECSExplorerModel
var sent: Array = []
var finished: Array = []

func before_test() -> void:
	now = 0
	sent = []
	finished = []
	model = GECSExplorerModel.new()
	model.clock = func(): return now
	model.connected = true
	model.world_id = 10
	model.epoch = 1
	model.sender = func(message, data): sent.append({"message": message, "data": data}); return true
	model.request_finished.connect(func(op, result, context): finished.append({"op": op, "result": result, "context": context}))

func _reply(id: int, result: Dictionary = {}, world := 10, epoch := 1) -> void:
	model.accept({"version": 2, "request_id": id, "world": world, "epoch": epoch, "result": result})

func test_loss_releases_slot_and_late_reply_is_ignored() -> void:
	model.poll_provider = func(): return [{"op": "overview"}]
	model.tick()
	var id: int = model._latest["overview:overview"]
	for i in 10:
		now += 100
		model.tick()
	assert_int(sent.size()).is_equal(2) # overview + heartbeat, both pending
	now = 3000
	model.tick()
	assert_bool(finished.any(func(item): return item.op == "overview" and item.result.has("error"))).is_true()
	assert_bool(model.has_pending("overview")).is_true() # replacement was scheduled
	var count := finished.size()
	_reply(id)
	assert_int(finished.size()).is_equal(count)

func test_four_request_bound_and_fairness_under_slow_responses() -> void:
	model.poll_provider = func():
		var polls: Array = []
		for i in 20: polls.append({"op": "graph", "args": {"id": i}, "context": {"key": str(i)}})
		return polls
	var seen := {}
	for turn in 30:
		now += 500
		model.tick()
		assert_int(model._pending.size()).is_less_equal(4)
		for id in model._pending.keys():
			seen[model._pending[id].key] = true
			_reply(id)
	assert_int(seen.size()).is_equal(21)

func test_lost_hello_retries_attachment_without_building_a_backlog() -> void:
	model.world_id = 0
	model.tick()
	assert_int(sent.size()).is_equal(2)
	now = 2999
	model.tick()
	assert_int(sent.size()).is_equal(2)
	now = 3000
	model.tick()
	assert_int(sent.size()).is_equal(4)
	assert_int(model._pending.size()).is_equal(1)
	var id: int = model._pending.keys()[0]
	_reply(id, {"step_state": {"paused": true}})
	assert_int(model.world_id).is_equal(10)
	assert_bool(model.step_state.paused).is_true()

func test_mutation_timeout_is_not_replayed_and_reports_unknown_outcome() -> void:
	var id := model.request("apply", {}, {"key": "entity:1"})
	now = 3000
	model.tick()
	assert_bool(finished[0].result.outcome_unknown).is_true()
	assert_str(finished[0].result.error).contains("outcome unknown")
	_reply(id, {"applied": 1})
	assert_int(sent.filter(func(item): return item.data[0].get("op") == "apply").size()).is_equal(1)

func test_godot_break_suspends_deadlines_and_resume_refreshes() -> void:
	var id := model.request("inspect")
	model.tick()
	now = 500
	model.script_breaked = true
	model.tick()
	now = 20000
	model.tick()
	assert_bool(model._pending.has(id)).is_true()
	model.script_breaked = false
	model.tick()
	now += 1000
	model.tick()
	assert_bool(model._pending.has(id)).is_true()

func test_world_swap_cancels_busy_consumers_and_rejects_old_replies() -> void:
	var edit := model.request("apply")
	var read := model.request("overview")
	_reply(read, {"error": "World changed", "code": "world_changed"}, 20, 2)
	assert_int(model.world_id).is_equal(0)
	assert_bool(finished.any(func(item): return item.op == "apply" and item.result.has("error"))).is_true()
	_reply(edit, {"applied": 1})
	assert_int(model.world_id).is_equal(0)
	model.tick()
	assert_bool(model.has_pending("hello")).is_true()

func test_protocol_mismatch_stops_retries_and_explains_incompatibility() -> void:
	var id := model.request("hello")
	model.accept({"version": 1, "request_id": id, "result": {}})
	assert_str(model.protocol_error).contains("update the editor and game together")
	var count := sent.size()
	now = 10000
	model.tick()
	assert_int(sent.size()).is_equal(count)

func test_hidden_session_still_polls_health_and_times_out_requests() -> void:
	model.tick()
	assert_str(sent[0].data[0].op).is_equal("debugger_state")
	now = 3000
	model.tick()
	assert_bool(finished[0].result.has("error")).is_true()

func test_chart_gaps_and_shared_watch_registration_are_bounded() -> void:
	model.watch({"world": 10, "epoch": 1, "iid": 5}, "x")
	model.watch({"world": 10, "epoch": 1, "iid": 5}, "x")
	assert_int(sent.size()).is_equal(1)
	model._accept_sample({"samples": {"x": {}}, "time": 0, "step": 0})
	model._accept_sample({"samples": {"x": {}}, "time": 5000, "step": 1})
	assert_int(model.series.x.size()).is_equal(3)
	assert_dict(model.series.x[1].data).is_empty()
	model.unwatch("x")
	assert_bool(model.watches.has("x")).is_true()

func test_expired_reply_cannot_win_before_the_next_timer_tick() -> void:
	var id := model.request("overview")
	now = 3001
	_reply(id, {"entities": 5})
	assert_int(finished.size()).is_equal(1)
	assert_bool(finished[0].result.has("error")).is_true()

func test_reads_include_authoritative_watch_definitions_for_loss_recovery() -> void:
	model.watches["x"] = {"key": "x", "entity": {"iid": 1}}
	model.request("sample", {"keys": ["x"]})
	assert_int(sent.back().data[0].args.watch_definitions.size()).is_equal(1)
	model.watches.clear()
	model.request("debugger_state")
	assert_array(sent.back().data[0].args.watch_definitions).is_empty()

func test_superseded_read_timeout_does_not_replace_newer_success() -> void:
	model.request("query", {}, {"key": "results"})
	var latest := model.request("query", {}, {"key": "results"})
	_reply(latest, {"rows": []})
	now = 3001
	model.tick()
	assert_int(finished.size()).is_equal(1)
	assert_bool(finished[0].result.has("error")).is_false()
