# Explorer debugger transport

Explorer is the entity/system inspection surface. The compact GECS debugger tab retains stepping, breakpoints, logs, and **Show Explorer**. The old entity/system trees and capture-category controls have been retired.

## Refresh and recovery

Visible systems, entity lists, watches, and live relationship graphs refresh at up to 2 Hz. The overview retains its own refresh setting (1 second by default). Detached visible views count as consumers. Closing or hiding views stops their automatic reads; watch charts retain their last 600 samples and show gaps when sampling resumes. Arbitrary query expressions remain one-shot unless explicitly watched.

Each session permits four outstanding automatic reads, with one per polling key. The scheduler serves overdue views fairly. It runs from the editor plugin independently of the debugger dock and window focus, sending a state/health read every 2 seconds even when Explorer is hidden. Open native windows keep polling their displayed content when focus returns to the game; hidden tabs and closed windows generate no automatic data reads. Godot script breaks suspend automatic requests and timeout accounting; ECS-only pauses still allow reads.

Requests time out after 3 seconds. Automatic reads resume through the scheduler, and attachment retries back off from 1 to 5 seconds. Late replies are ignored. Mutations are never retried automatically: a lost edit, restore, scratchpad, or command reply can mean the action executed, so the UI reports an unknown outcome and refreshes current state. Do not infer that a timed-out action failed to execute.

## Protocol v2

Editor and runtime must use the same addon version. An incompatible response stops polling and displays an update message. The existing `gecs:explorer_request` / `gecs:explorer_response` envelope retains its request ID, operation, world, epoch, and args/result fields; `version` is now **2**.

| Operation | Request arguments | Result |
| --- | --- | --- |
| `systems` | None | Authoritative system-ID dictionary with status, order, script, and cached timing aggregates |
| `sample` | Watch `keys` | Requested snapshots, sample time, and step number |
| `graph` | Graph `id` | Graph ID, step number, nodes and edges |
| `debugger_state` | Last consumed log ID as `after` | Step/run state, log page, next `after`, `more`, history `gap`, and oversized `omitted` IDs |

Sample, state, and capture requests include the editor's complete `watch_definitions` set. This reconciles lost watch/unwatch commands without sampling hidden watches. Existing entity queries remain paged at 100 rows.

Runtime requests are serviced at ECS boundaries, with at most four queued requests handled per pump. Responses retain the 8 MiB limit. Step-log pages contain at most 32 entries and 1 MiB of encoded logs, drawn from the existing 64-entry stepper history. Expired history and oversized entries are reported explicitly.

Subscription attaches the transport without a world replay. Routine lifecycle/property/telemetry messages are no longer sent. Small world/control events remain, and step-state change notices are coalesced to at most two per second. The heartbeat recovers missed notices. Deprecated push sender methods remain inert compatibility shims; their arguments are not serialized. Timing collection, ECS signals, change tracking, and breakpoint hooks remain independent of transport.

## Validation and repeatable soak

Run the debugger and core suites from Git Bash:

```sh
tools/run_tests.sh -t 600 res://addons/gecs/tests/debug res://addons/gecs/tests/core
```

For a five-minute transport soak, start a separate editor using an unused debugger port, then launch the fixture against it (replace `godot` with your engine executable):

```sh
godot --headless --editor --path . --debug-server tcp://127.0.0.1:6017 --ignore-error-breaks
godot --headless --path . res://tools/debugger_soak.tscn --remote-debug tcp://127.0.0.1:6017 --ignore-error-breaks --max-fps 60 -- --gecs-debug
```

Run these commands in separate terminals. Omit `--headless` on the editor to inspect the UI visually. The fixture creates 10,000 entities and 100 systems, emits continuous property changes, spawns/removes bursts, and performs 100-step commands. It deliberately drops the first hello and overview replies, then checks that subsequent replies arrive. It leaves the Godot queue limit unchanged.

The fixture writes `.godot/debugger_soak.json` with elapsed time, property-change count, responses by operation, peak GECS messages per second, payload bytes, queue limit, and recovery status. Also check both editor and game logs for script errors and `TOO_MANY_MESSAGES`; the runtime report alone cannot detect editor-side rendering errors. Stop the separate editor after the fixture exits.
