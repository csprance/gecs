---
phase: 3
slug: authority-model-and-native-transform-sync
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-09
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | GdUnit4 |
| **Config file** | `GdUnitRunner.cfg` |
| **Quick run command** | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests" -c` |
| **Full suite command** | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -a "res://addons/gecs_network/tests" -c` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests" -c`
- **After every plan wave:** Run `addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -a "res://addons/gecs_network/tests" -c`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 3-W0-01 | Wave 0 | 0 | LIFE-05 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_authority_markers.gd"` | ❌ W0 | ⬜ pending |
| 3-W0-02 | Wave 0 | 0 | SYNC-04 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_native_sync_handler.gd"` | ❌ W0 | ⬜ pending |
| 3-01-01 | 01 | 1 | LIFE-05 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_authority_markers.gd"` | ❌ W0 | ⬜ pending |
| 3-01-02 | 01 | 1 | LIFE-05 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_authority_markers.gd"` | ❌ W0 | ⬜ pending |
| 3-01-03 | 01 | 1 | LIFE-05 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_authority_markers.gd"` | ❌ W0 | ⬜ pending |
| 3-02-01 | 02 | 1 | SYNC-04 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_native_sync_handler.gd"` | ❌ W0 | ⬜ pending |
| 3-02-02 | 02 | 1 | SYNC-04 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_native_sync_handler.gd"` | ❌ W0 | ⬜ pending |
| 3-02-03 | 02 | 1 | SYNC-04 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_native_sync_handler.gd"` | ❌ W0 | ⬜ pending |
| 3-03-01 | 03 | 2 | SYNC-04 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_cn_net_sync.gd"` | ✅ (add case) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `addons/gecs_network/tests/test_authority_markers.gd` — 5 test stubs for LIFE-05
- [ ] `addons/gecs_network/tests/test_native_sync_handler.gd` — 5 test stubs for SYNC-04
- [ ] `godot --headless --import` after creating new `class_name` files: `cn_native_sync.gd`, `native_sync_handler.gd`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| MultiplayerSynchronizer actually interpolates entity position between peers | SYNC-04 | Requires live multiplayer session | Run example_network scene with 2 peers; move a player entity and observe smooth interpolation on the remote peer |
| Late-join client receives correct initial transform snapshot | SYNC-04 | Requires live join-in-progress session | Start server with entities in motion; connect second client mid-session; verify entities appear at correct positions |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
