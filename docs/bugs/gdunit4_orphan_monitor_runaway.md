# gdUnit4 Orphan Monitor — crashes / infinite debugger loop on freed Node references

## Summary

`GdUnitOrphanNodesMonitor` crashes the Godot engine (or enters an unrecoverable
infinite debugger-break loop) during post-test "garbage-collection inspection"
when a test suite holds a script-member or local-variable reference to a `Node`
that was freed via `Object.free()` directly (rather than `queue_free()` /
`auto_free()`).

The same code path has **two observable failure modes**, both originating in
`addons/gdUnit4/src/monitor/GdUnitOrphanNodesMonitor.gd`:

| Mode | Environment | Signature | Outcome |
| --- | --- | --- | --- |
| A. Runaway debug-break loop | GUI (non-headless) + debug | `Debugger Break, Reason: 'Invalid cast: can't convert a non-object value to an object type.'` on `GdUnitOrphanNodesMonitor.gd:130 _find_orphan_at_node` | Process never exits; fills **terabytes** of log data in stdout *and* `editor.log`. Must be killed via Task Manager / `pkill`. |
| B. Hard SIGSEGV crash | `--headless` + debug | `ERROR: Parameter "_fp" is null. at: _ref (core/variant/array.cpp:59)` followed by `CrashHandlerException: Program crashed with signal 11` at `_find_orphan_on_backtraces (GdUnitOrphanNodesMonitor.gd:168)` | Exits non-zero with a C++ stack dump. |

Mode A is the severe one because it's silent and disk-filling. This report
provides a reliable reproduction for mode B (headless) with strong evidence the
root cause is shared.

## Environment

- **gdUnit4:** 6.1.2 (`addons/gdUnit4/plugin.cfg`)
- **Godot:** 4.7.dev5 (official, `a8643700c`) — also reproduced historically on 4.5
- **OS:** Windows 11 (also reproduced on MINGW/Git Bash shell)
- **Orphan detection:** default-enabled (`REPORT_ORPHANS = true` in `GdUnitSettings`)

## Reproduction

### Minimal test

```gdscript
# res://addons/gecs/tests/_bug_repros/test_gdunit_orphan_monitor_runaway.gd
extends GdUnitTestSuite

var _freed_member_ref: Node

func test_reproduces_orphan_monitor_runaway_loop():
    @warning_ignore("unused_variable")
    var leaked := Node.new()      # actual orphan — gives the monitor something to trace

    var to_free := Node.new()
    _freed_member_ref = to_free
    to_free.free()                # freed instance retained on the suite
    # `_freed_member_ref` is now a freed instance: not strictly null,
    # not `is_instance_valid()`, but `!= null` returns true.

    assert_bool(true).is_true()
```

### Command (mode B — SIGSEGV, safe to automate)

```bash
# Cap stdout at 20 MB, wall-clock timeout 60s
timeout 60 "$GODOT_BIN" --path . --headless -s -d \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  -a "res://addons/gecs/tests/_bug_repros/test_gdunit_orphan_monitor_runaway.gd" \
  2>&1 | head -c 20971520 > /tmp/gecs_runaway.log
```

Observed in ~5 seconds: test PASSES, then suite-teardown `gc()` crashes.
Full sanitized log saved at `artifacts/gdunit4_orphan_monitor_crash_2026-04-22.log`.

### Command (mode A — DANGEROUS runaway)

Run the same test **without `--headless`** in debug mode via the normal
`runtest.cmd` wrapper. The debugger enters a break loop from which gdUnit4
cannot recover. **Do not run this unattended** — `editor.log` grew multiple GB
before we could kill it in prior occurrences.

## Crash path

```
gc                              addons/gdUnit4/src/core/execution/GdUnitExecutionContext.gd:247
collect                         addons/gdUnit4/src/monitor/GdUnitOrphanNodesMonitor.gd:84
_collect_orphan_info            addons/gdUnit4/src/monitor/GdUnitOrphanNodesMonitor.gd:91
_find_orphan_on_backtraces      addons/gdUnit4/src/monitor/GdUnitOrphanNodesMonitor.gd:168   <-- SIGSEGV (mode B)
_find_orphan_at_node            addons/gdUnit4/src/monitor/GdUnitOrphanNodesMonitor.gd:130   <-- Invalid cast (mode A)
```

## Root cause

The monitor performs unsafe casts on values that may be freed Object instances.
In GDScript a freed `Object` is a "previously freed instance" sentinel that
is **not strictly null** — `freed_ref != null` returns `true`, and `as Node`
then throws `Invalid cast: can't convert a non-object value to an object type`.

### Line 130 — `_find_orphan_at_node` (mode A trigger)

```gdscript
var property_instance: Variant = node.get(property_name)
@warning_ignore("unsafe_cast")
var property_as_node := property_instance as Node if property_instance != null else null
#                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#                                                    freed instances are NOT null — guard fails
```

When the orphan monitor walks the test suite's (or scene runner's) script
properties looking for who owns the orphan node, it reaches `_freed_member_ref`,
the `!= null` guard passes, and `as Node` throws `Invalid cast`. In GUI debug
mode the engine halts in the script debugger, gdUnit4's runner re-enters the
break every frame, and the log floods indefinitely.

### Line 168 — `_find_orphan_on_backtraces` (mode B trigger)

```gdscript
func _find_orphan_on_backtraces(orphan_to_find: Object) -> GdUnitOrphanNodeInfo:
    for script_backtrace in Engine.capture_script_backtraces(true):
```

Under `--headless`, iteration of `Engine.capture_script_backtraces(true)` emits
`ERROR: Parameter "_fp" is null. at: _ref (core/variant/array.cpp:59)` three
times (non-fatal) and then SIGSEGVs during the final suite `gc()` call. The
null callback pointer suggests one of the `ScriptBacktrace` frames references a
freed object whose callable has been invalidated. The deeper script scans at
lines 180 and 202 have the same unsafe-cast pattern as line 130.

The `Engine.capture_script_backtraces(true)` failure may itself be a Godot 4.7
engine regression, but gdUnit4's use of it remains unguarded: one bad frame
terminates the entire orphan-collection pass.

## Suggested fix

Use `is_instance_valid()` instead of `!= null` before every `as Node` cast in
this file, and wrap `Engine.capture_script_backtraces(true)` iteration in a
defensive skip. Three locations:

```gdscript
# Line 130 — _find_orphan_at_node
var property_instance: Variant = node.get(property_name)
var property_as_node: Node = null
if is_instance_valid(property_instance) and property_instance is Node:
    property_as_node = property_instance
if property_as_node == null:
    continue
```

```gdscript
# Lines 180 and 202 — _find_orphan_on_backtraces (local + member scan)
var variable_instance: Variant = script_backtrace.get_local_variable_value(frame, l_index)
if not is_instance_valid(variable_instance) or variable_instance is not Node:
    continue
var node: Node = variable_instance
```

Additionally, skip frames whose backtrace capture fails rather than letting an
engine-level error tear down the whole suite:

```gdscript
func _find_orphan_on_backtraces(orphan_to_find: Object) -> GdUnitOrphanNodeInfo:
    var backtraces := Engine.capture_script_backtraces(true)
    if backtraces == null:
        return null
    for script_backtrace in backtraces:
        if script_backtrace == null or not is_instance_valid(script_backtrace):
            continue
        ...
```

## Why this matters

- **Silent disk fill.** Mode A can fill 1+ GB of `editor.log` in under a minute
  with no visible output to the caller — a CI run or automated headless agent
  discovers this only after the disk fills.
- **Correct user behavior still triggers it.** Holding a freed Node reference
  as a script member is a legitimate (if questionable) pattern; the framework
  should surface the leak as a diagnostic, not crash the process.
- **Fail-safe violation.** The orphan monitor is an observability tool. It
  should never be able to take down the test runner, regardless of what state
  user code is in.

## Mitigation for downstream users (until fixed)

See `gecs-test-writer.md` § "gdUnit4 runaway-loop guard":

- Always redirect gdUnit4 output to a capped log file (`head -c 20M`).
- Always wrap runs with a wall-clock `timeout`.
- Never run gdUnit4 with raw stdout piped into a long-running agent context.
- Truncate `%APPDATA%\Godot\...\logs\*.log` if they grow >100 MB.

## Attachments

- `artifacts/gdunit4_orphan_monitor_crash_2026-04-22.log` — full sanitized
  stdout of the mode-B reproduction (214 lines).
- Repro test: `addons/gecs/tests/_bug_repros/test_gdunit_orphan_monitor_runaway.gd`.
