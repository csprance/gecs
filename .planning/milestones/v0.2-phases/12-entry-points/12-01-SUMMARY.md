---
phase: 12-entry-points
plan: 01
subsystem: documentation
tags: [readme, quick-start, install, network, godot, gecs]

requires:
  - phase: 11-network-docs
    provides: accurate gecs_network docs for cross-referencing in network README
  - phase: 08-foundation-docs
    provides: accurate GETTING_STARTED and CORE_CONCEPTS for README links

provides:
  - Root README with Requirements section, three-path install section, and verified quick-start
  - addons/gecs/README.md accurate with NetAdapter in networking table, no version stamps
  - addons/gecs_network/README.md with four-step quick start including NetworkSession

affects: [release-tagging, godot-asset-library-submission, new-developer-onboarding]

tech-stack:
  added: []
  patterns:
    - "Both component patterns shown in quick-start: @export var with default AND _init() with parameter"
    - "ECS.process(delta) as canonical call form (not ECS.world.process)"
    - "NetworkSession add_child before host() — node lifecycle pattern"

key-files:
  created: []
  modified:
    - README.md
    - addons/gecs_network/README.md

key-decisions:
  - "addons/gecs/README.md required no changes — NetAdapter and no version stamps already present from prior phase work"
  - "root README quick-start uses entity.get_component() pattern with explicit type cast for clarity"
  - "NetworkSession Step 4 includes world.process() responsibility note matching source behavior"

patterns-established:
  - "READMEs keep emoji in feature bullets and headers; docs/*.md files do not"
  - "Root README links to addons README for full docs — does not duplicate content"

requirements-completed: [READ-01, READ-02]

duration: 2min
completed: 2026-03-15
---

# Phase 12 Plan 01: Entry Points README Overhaul Summary

**Root README rewritten with Requirements section, three-path install guide (Asset Library/Manual/Submodule), and verified quick-start showing both component patterns and ECS.process(delta); gecs_network README gains four-step quick start with real NetworkSession API**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-15T03:32:42Z
- **Completed:** 2026-03-15T03:34:08Z
- **Tasks:** 4 (Tasks 0-3; Task 0 is Wave 0 gate, runs last)
- **Files modified:** 2 (addons/gecs/README.md required no changes)

## Accomplishments

- Root README now has Requirements section, three labeled install subsections, and a ~50-line quick-start with both `@export var` and `_init()` component patterns with explicit default-value comment
- Quick-start uses `ECS.process(delta)` (not `ECS.world.process`), Vector3 for velocity, one relationship example, and `entity.get_component()` pattern
- addons/gecs_network/README.md gains Step 4 showing `NetworkSession` with `add_child` before `host()`, and a note that game code owns `ECS.process(delta)`
- Wave 0 structural gate confirmed all four key strings present across the three READMEs

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite root README.md** - `30aab42` (feat)
2. **Task 2: Fix addons/gecs/README.md** - no commit needed (file already accurate)
3. **Task 3: Fix addons/gecs_network/README.md** - `4e25b19` (feat)
4. **Task 0: Wave 0 verification gate** - verified via grep, no file changes

## Files Created/Modified

- `README.md` - Full rewrite: Requirements, Installation (3 paths), quick-start code (~50 lines), ECS.process(delta)
- `addons/gecs_network/README.md` - Step 4 added: NetworkSession with host()/join() and world.process() note

## Decisions Made

- `addons/gecs/README.md` required no changes — NetAdapter was already correct in the Configuration table and no version stamps existed in the CommandBuffer section. Task 2 verified but made no edits.
- Root README quick-start uses `entity.get_component()` with explicit type cast (`as C_Velocity`) for clarity over the `iterate()` array pattern used in the old snippet.
- NetworkSession Step 4 follows source behavior: `add_child(session)` before `host()` because `_ready()` sets the default ENet transport.

## Deviations from Plan

None - plan executed exactly as written. Task 2 was a no-op because prior phase work had already made the file accurate; this is consistent with the task's own conditional instructions ("If it already reads... leave it unchanged").

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three entry-point READMEs accurate against GECS v6.8.1
- Human review checkpoint pending (Task 4 in plan) — reviewer should check three files against the criteria in the checkpoint task
- After human approval: v0.2 documentation overhaul is complete, ready for `git tag v0.2.0`

---
*Phase: 12-entry-points*
*Completed: 2026-03-15*
