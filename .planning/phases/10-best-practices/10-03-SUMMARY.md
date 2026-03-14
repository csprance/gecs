---
phase: 10-best-practices
plan: "03"
subsystem: docs
tags: [troubleshooting, gecs, gdscript, ecs]

requires:
  - phase: 09-advanced-core-docs
    provides: accurate API surface confirmed via source review

provides:
  - TROUBLESHOOTING.md free of fabricated APIs and emoji
  - Real ECS.world.entities.size(), ECS.world.get_cache_stats() usage examples
  - Accurate debug logging guidance via project settings

affects: [10-best-practices, 12-readmes]

tech-stack:
  added: []
  patterns:
    - "API calls in docs verified against world.gd source before inclusion"
    - "Debug guidance references Godot project settings, not invented ECS methods"

key-files:
  created: []
  modified:
    - addons/gecs/docs/TROUBLESHOOTING.md

key-decisions:
  - "Removed ECS.world.get_system_count() with no replacement — the method does not exist"
  - "Debug logging note now points to gecs.log_level project setting rather than a fabricated ECS.set_debug_level API"

patterns-established:
  - "Pattern: inline Problem/Solution comment labels replace emoji check/cross markers in code examples"

requirements-completed: [BEST-03]

duration: 5min
completed: 2026-03-14
---

# Phase 10 Plan 03: Fix TROUBLESHOOTING.md Summary

**TROUBLESHOOTING.md scrubbed of all emoji and fabricated API calls — entity count, profiling, debug logging, and entity inspector examples now use real ECS.world properties**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-14
- **Completed:** 2026-03-14
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Stripped emoji from all eight section headers and all inline code comments
- Replaced fabricated `ECS.world.enable_profiling`, `ECS.world.entity_count`, and `ECS.world.get_system_count()` with real APIs
- Replaced fabricated `ECS.set_debug_level(ECS.DEBUG_VERBOSE)` block with accurate project-settings note
- Replaced `ECS.world.get_all_entities()` with `ECS.world.entities.values()`
- Removed trailing inspirational-quote footer

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix TROUBLESHOOTING.md** - `00afd23` (docs)

## Files Created/Modified

- `addons/gecs/docs/TROUBLESHOOTING.md` - Emoji stripped, fabricated API calls replaced with real equivalents, footer removed

## Decisions Made

- `ECS.world.get_system_count()` removed with no replacement because no equivalent exists in the GECS source
- Debug logging guidance replaced with project-settings prose because `ECS.set_debug_level` is entirely fabricated

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- TROUBLESHOOTING.md is accurate and emoji-free, ready for final README pass in Phase 12
- No blockers

---
*Phase: 10-best-practices*
*Completed: 2026-03-14*
