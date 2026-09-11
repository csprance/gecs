---
name: gecs-tests
description: Run the GECS GdUnit4 test suite without hanging, spawning windows, or flooding the context. Use whenever a task involves running, writing, or debugging GECS tests, verifying a fix with a red/green check, or interpreting a test failure. Covers the hang-safe runner, why runtest.sh/.cmd must never be used directly, where tests live, known flaky tests, and the stash-based regression-verification workflow.
---

# Running GECS tests

## The one rule

**Always use `tools/run_tests.sh`, from `D:\Code\Gecs`, in Git Bash.** Never invoke
`addons/gdUnit4/runtest.sh`, `runtest.cmd`, or `GdUnitCmdTool.gd` yourself.

`D:\Code\GecsEngine` is a directory junction to the same repo, so either path
works. It exists only so ZAMN's `project.godot` has the shorter path and wins
godot-tools' project glob; see the comment in `ZAMN.code-workspace`.

```bash
tools/run_tests.sh [-t seconds] <res://path> [<res://path> ...]
```

```bash
tools/run_tests.sh -t 900 res://addons/gecs/tests                       # whole suite (~870 cases)
tools/run_tests.sh res://addons/gecs/tests/core/test_world.gd           # one file
tools/run_tests.sh res://addons/gecs/tests/core res://addons/gecs/tests/network
```

Default timeout is **300s**. The full suite takes about **410s**, so it does not fit
and will report a false hang. **Always pass `-t 900` for a full-suite run.** Single
files and small directories finish in seconds and need no `-t`.

A full-suite run that reports `RESULT: TIMEOUT after 300s` is almost always just
this, not a real hang. Re-run with `-t 900` before investigating.

Exit codes: `0` all passed, `1` failures, `124` timeout/hang, `2` usage error or
broken run (no summary produced).

Output is already compact: the summary line, failed test names, capped assertion
detail, and a `Full log:` path. Do not pipe it through `grep`/`tail`; that is what
the wrapper is for, and the raw log it points at is tens of MB.

## Why the stock runners are banned

- **`runtest.cmd` / `runtest.sh` pass `-d`.** On a dev Godot build, `-d` turns every
  script error into an interactive `debug>` "Debugger Break" prompt and waits
  forever. A run against deliberately-broken code (see the red/green workflow below)
  will hang until something kills it. `tools/run_tests.sh` omits `-d`, so errors
  print and the run continues.
- **`runtest.sh` does not pass `--headless`.** Line 55 launches a windowed Godot, so
  test windows pop up on screen. (Only its trailing log-copy step is headless.)
- **Raw output is enormous.** A failing run emits thousands of stack-trace lines.
  One no-fix verification produced 31MB.

## Headless

gdUnit4 refuses to run headless unless you also pass `--ignoreHeadlessMode`.
Without it you get `Headless mode is not supported!` and `Abnormal exit with 103`.
`tools/run_tests.sh` already passes `--headless --ignoreHeadlessMode`, so headless
is the default and no windows appear. The check exists because Godot does not
deliver `InputEvent`s in headless mode; only UI-interaction tests are affected, and
GECS has none.

## Where things live

- Tests live **only** in `addons/gecs/tests/`. Do not create test files anywhere else.
- `tests/core/`, `tests/network/`, `tests/debug/`, plus `tests/components/` and
  `tests/entities/` for the `C_TestA`-style fixtures the suites share.
- Standard harness, two flavors, both in use:
  ```gdscript
  # Scene-runner style (most serialization/relationship suites)
  runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
  world = runner.get_property("world")
  ECS.world = world

  # Bare-world style (test_debug_tracking.gd, test_tracker.gd)
  world = World.new()
  Engine.get_main_loop().root.add_child(world)
  ECS.world = world
  ```
  Tear down in `after_test()`: `world.purge(false)` or `ECS.world = null` plus
  `world.queue_free()`. If a test installs global/static state (for example
  `Entity.set_read_tracker`), clear it in `after_test()` so a failure cannot leak
  into the rest of the suite.

## GODOT_BIN

The runner defaults to `D:\Godot\4.7-dev5\Godot_v4.7-dev5_win64_console.exe`, which
exists on this machine, so no setup is needed. Override only to pin a version:

```bash
export GODOT_BIN="/d/Godot/Godot_v4.7-stable_win64/Godot_v4.7-stable_win64.exe"
```

`EXTRA_GODOT_ARGS` passes engine-level flags through, e.g.
`EXTRA_GODOT_ARGS=--no-gecs-debug` for release-path benchmark numbers, since
`ECS.debug` adds roughly 20ms/frame.

## You cannot run these from ZAMN

`d:\code\zamn` has **no `addons/gdUnit4`**. GECS tests only run from `D:\Code\Gecs`.
When a ZAMN bug turns out to live in the GECS addon, fix and test it in the dev repo
and then release/re-pin (see the `gecs-sync` skill). Do not try to `cd` into
`zamn/addons/gecs` and run tests there.

## Red/green: proving a regression test actually catches the bug

A new test that passes proves nothing on its own. Verify it fails without the fix:

```bash
git stash push -- <fixed files>
tools/run_tests.sh -t 180 res://addons/gecs/tests/core/test_the_thing.gd
git stash pop
```

**Hazard:** if the run outlives the Bash tool's timeout, the harness kills the
command and `git stash pop` never executes, leaving the fix stashed and the tree
silently broken. Two guards:

1. Always set `-t` **well below** the tool call's timeout so the runner returns 124
   on its own rather than being killed from outside.
2. After any stash-based run, confirm with `git stash list` and `git status` that
   the tree is restored before doing anything else.

Also check that the **pre-existing** tests still pass without the fix. If they do,
that confirms the old suite genuinely had no coverage of the bug, which is worth
saying in the changelog.

## Known flaky

- `tests/core/test_debug_tracking.gd > test_debug_tracking_process_mode` asserts
  wall-clock timing (e.g. `0.1125 < 0.124`) and fails intermittently under full-suite
  load. Before blaming a change, re-run that file alone; it passes standalone and on
  a clean tree.

Treat any single failure in a large run as suspect until re-run in isolation.

## Interpreting a hang

Exit 124 means the runner timed out. It kills **only** the Godot processes it
spawned, never a pre-existing editor, then prints the first parse/script errors it
found in the log. Work through it in this order:

1. **Was it a full-suite run without `-t 900`?** Then it is just the 300s default
   being too small. Re-run with `-t 900`.
2. **Did you run against deliberately-broken code** (a stash-based red/green check)?
   Then errors are expected; check the tree got restored.
3. Only then treat it as a real parse error.

Note the printed "first hits" are a plain grep over the log for
`Parser Error|SCRIPT ERROR|Compile Error`, so it can surface a **pre-existing,
unrelated** error from suite scanning rather than the actual cause. Confirm the file
it names is one you touched before chasing it.
