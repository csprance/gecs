---
phase: 5
slug: reconciliation-and-custom-sync
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-11
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | GdUnit4 (project-installed, `addons/gdUnit4/`) |
| **Config file** | `addons/gdUnit4/GdUnitRunner.cfg` |
| **Quick run command** | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd" -c` |
| **Full suite command** | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 5-01-01 | 01 | 0 | ADV-02 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd"` | ❌ W0 | ⬜ pending |
| 5-01-02 | 01 | 0 | ADV-03 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_custom_sync_handlers.gd"` | ❌ W0 | ⬜ pending |
| 5-02-01 | 02 | 1 | ADV-02 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd::test_reconciliation_fires_at_interval"` | ❌ W0 | ⬜ pending |
| 5-02-02 | 02 | 1 | ADV-02 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd::test_broadcast_full_state_serializes_networked_entities"` | ❌ W0 | ⬜ pending |
| 5-02-03 | 02 | 1 | ADV-02 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd::test_handle_full_state_applies_component_data"` | ❌ W0 | ⬜ pending |
| 5-02-04 | 02 | 1 | ADV-02 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd::test_handle_full_state_skips_local_entities"` | ❌ W0 | ⬜ pending |
| 5-02-05 | 02 | 1 | ADV-02 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd::test_handle_full_state_removes_ghost_entities"` | ❌ W0 | ⬜ pending |
| 5-02-06 | 02 | 1 | ADV-02 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_reconciliation.gd::test_reconciliation_interval_project_setting"` | ❌ W0 | ⬜ pending |
| 5-03-01 | 03 | 2 | ADV-03 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_custom_sync_handlers.gd::test_custom_send_handler_replaces_default"` | ❌ W0 | ⬜ pending |
| 5-03-02 | 03 | 2 | ADV-03 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_custom_sync_handlers.gd::test_custom_send_handler_suppress"` | ❌ W0 | ⬜ pending |
| 5-03-03 | 03 | 2 | ADV-03 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_custom_sync_handlers.gd::test_custom_receive_handler_replaces_default"` | ❌ W0 | ⬜ pending |
| 5-03-04 | 03 | 2 | ADV-03 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_custom_sync_handlers.gd::test_custom_receive_handler_still_updates_cache"` | ❌ W0 | ⬜ pending |
| 5-03-05 | 03 | 2 | ADV-03 | unit | `runtest.cmd -a "res://addons/gecs_network/tests/test_custom_sync_handlers.gd::test_custom_receive_handler_fallthrough"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `addons/gecs_network/tests/test_reconciliation.gd` — stubs for ADV-02 (6 test methods)
- [ ] `addons/gecs_network/tests/test_custom_sync_handlers.gd` — stubs for ADV-03 (5 test methods)
- [ ] `addons/gecs_network/sync_reconciliation_handler.gd` — core ADV-02 implementation file skeleton

*Framework already present — no install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| No visible pop or desync during reconciliation | ADV-02 | Requires live multiplayer session to observe visual smoothness | Run host+client for 30s, verify no snap on reconciliation broadcast |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
