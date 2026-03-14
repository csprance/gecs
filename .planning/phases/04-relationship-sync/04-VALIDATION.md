---
phase: 4
slug: relationship-sync
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-10
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | GdUnit4 |
| **Config file** | `GdUnitRunner.cfg` |
| **Quick run command** | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_sync_relationship_handler.gd"` |
| **Full suite command** | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_sync_relationship_handler.gd"`
- **After every plan wave:** Run `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests" -c`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 4-01-01 | 01 | 0 | ADV-01 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd"` | ❌ W0 | ⬜ pending |
| 4-01-02 | 01 | 0 | ADV-01 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd"` | ❌ W0 | ⬜ pending |
| 4-02-01 | 02 | 1 | ADV-01 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_relationship_handler.gd"` | ✅ | ⬜ pending |
| 4-02-02 | 02 | 1 | ADV-01 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_relationship_handler.gd"` | ✅ | ⬜ pending |
| 4-03-01 | 03 | 1 | ADV-01 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_relationship_handler.gd"` | ✅ | ⬜ pending |
| 4-03-02 | 03 | 1 | ADV-01 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_sync_relationship_handler.gd::test_deferred_resolution_entity_target"` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `addons/gecs_network/tests/test_spawn_manager.gd` — new test: `test_serialize_entity_includes_relationships_key` (ADV-01 late-join serialize coverage)
- [ ] `addons/gecs_network/tests/test_spawn_manager.gd` — new test: `test_handle_spawn_entity_applies_relationships` (ADV-01 receive-side apply coverage)

*All other existing tests in `test_sync_relationship_handler.gd` already cover ADV-01 core behaviors. No new test files needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | — | — | — |

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
