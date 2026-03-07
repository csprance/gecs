---
phase: 1
slug: foundation-and-entity-lifecycle
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-07
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | GdUnit4 (addons/gdUnit4) |
| **Config file** | addons/gdUnit4/GdUnitRunner.cfg |
| **Quick run command** | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"` |
| **Full suite command** | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -a "res://addons/gecs_network/tests"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"`
- **After every plan wave:** Run `addons/gdUnit4/runtest.cmd -a "res://addons/gecs/tests" -a "res://addons/gecs_network/tests"`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | 01 | 0 | FOUND-01 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_cn_network_identity.gd"` | ✅ existing (update) | ⬜ pending |
| TBD | 01 | 0 | FOUND-02 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd::test_rejects_stale_session_id"` | ❌ Wave 0 | ⬜ pending |
| TBD | 01 | 0 | FOUND-03 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_net_adapter.gd"` | ✅ existing | ⬜ pending |
| TBD | 01 | 0 | FOUND-04 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_net_adapter.gd"` | ✅ existing | ⬜ pending |
| TBD | 02 | 1 | LIFE-01 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd::test_deferred_broadcast_on_entity_added"` | ❌ Wave 0 | ⬜ pending |
| TBD | 02 | 1 | LIFE-02 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd::test_broadcast_pending_cancellation"` | ❌ Wave 0 | ⬜ pending |
| TBD | 02 | 1 | LIFE-03 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd::test_serialize_world_state"` | ❌ Wave 0 | ⬜ pending |
| TBD | 02 | 1 | LIFE-04 | unit | `addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_spawn_manager.gd::test_peer_disconnect_cleanup"` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `addons/gecs_network/tests/test_spawn_manager.gd` — stubs for LIFE-01, LIFE-02, LIFE-03, LIFE-04, FOUND-02 (port from `test_sync_spawn_handler.gd`, remove SyncConfig dependency from MockNetworkSync)
- [ ] Update `addons/gecs_network/tests/test_cn_network_identity.gd` — add test asserting `is_server_owned()` returns false for peer_id=1

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | — | — | — |

*All phase behaviors have automated verification via GdUnit4.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
