## Minimal reproduction for gdUnit4 orphan-monitor runaway-loop bug.
##
## See docs/bugs/gdunit4_orphan_monitor_runaway.md for the full bug report.
##
## Trigger: a test-suite member variable holds a reference to a Node that was
## freed via Object.free() directly. The orphan monitor's null-guard at
## addons/gdUnit4/src/monitor/GdUnitOrphanNodesMonitor.gd:130 checks
## `property_instance != null`, which returns true for freed instances
## (freed Objects are "previously freed instance" sentinels, not null), so the
## subsequent `property_instance as Node` cast throws "Invalid cast" and
## enters the debugger — which the runner cannot recover from.
##
## WARNING: running this test with orphan detection enabled (default) can
## cause gdUnit4 to emit millions of repeated log lines. Always run with a
## wall-clock timeout and redirect to a capped log file.
extends GdUnitTestSuite

var _freed_member_ref: Node


func test_reproduces_orphan_monitor_runaway_loop():
	@warning_ignore("unused_variable")
	var leaked := Node.new()

	var to_free := Node.new()
	_freed_member_ref = to_free
	to_free.free()

	assert_bool(true).is_true()
