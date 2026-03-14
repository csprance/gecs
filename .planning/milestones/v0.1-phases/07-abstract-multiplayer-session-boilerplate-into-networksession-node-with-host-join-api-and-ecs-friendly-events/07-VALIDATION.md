---
phase: 7
slug: abstract-multiplayer-session-boilerplate-into-networksession-node-with-host-join-api-and-ecs-friendly-events
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | GdUnit4 (present in `addons/gdUnit4/`) |
| **Config file** | `GdUnitRunner.cfg` (update when adding new test files) |
| **Quick run command** | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests/test_network_session.gd"` |
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
| 7-01-01 | 01 | 0 | event components | unit | `test_network_session.gd` stubs | ❌ W0 | ⬜ pending |
| 7-01-02 | 01 | 0 | CN_SessionState | unit | `test_network_session.gd` stubs | ❌ W0 | ⬜ pending |
| 7-02-01 | 02 | 1 | host() returns OK | unit | `test_network_session.gd::test_host_returns_ok` | ❌ W0 | ⬜ pending |
| 7-02-02 | 02 | 1 | host() error on null peer | unit | `test_network_session.gd::test_host_returns_error_on_null_peer` | ❌ W0 | ⬜ pending |
| 7-02-03 | 02 | 1 | join() returns OK | unit | `test_network_session.gd::test_join_returns_ok` | ❌ W0 | ⬜ pending |
| 7-02-04 | 02 | 1 | on_before_host hook fires | unit | `test_network_session.gd::test_on_before_host_fires` | ❌ W0 | ⬜ pending |
| 7-02-05 | 02 | 1 | on_host_success hook fires | unit | `test_network_session.gd::test_on_host_success_fires` | ❌ W0 | ⬜ pending |
| 7-02-06 | 02 | 1 | on_peer_connected hook fires | unit | `test_network_session.gd::test_on_peer_connected_fires_with_id` | ❌ W0 | ⬜ pending |
| 7-02-07 | 02 | 1 | on_peer_disconnected hook fires | unit | `test_network_session.gd::test_on_peer_disconnected_fires_with_id` | ❌ W0 | ⬜ pending |
| 7-02-08 | 02 | 1 | on_session_ended hook fires | unit | `test_network_session.gd::test_on_session_ended_fires` | ❌ W0 | ⬜ pending |
| 7-02-09 | 02 | 1 | empty hooks no crash | unit | `test_network_session.gd::test_empty_hooks_no_crash` | ❌ W0 | ⬜ pending |
| 7-03-01 | 03 | 1 | CN_PeerJoined added on connect | unit | `test_network_session.gd::test_cn_peer_joined_added` | ❌ W0 | ⬜ pending |
| 7-03-02 | 03 | 1 | CN_PeerLeft added on disconnect | unit | `test_network_session.gd::test_cn_peer_left_added` | ❌ W0 | ⬜ pending |
| 7-03-03 | 03 | 1 | CN_SessionStarted on host() | unit | `test_network_session.gd::test_cn_session_started_on_host` | ❌ W0 | ⬜ pending |
| 7-03-04 | 03 | 1 | CN_SessionEnded on disconnect | unit | `test_network_session.gd::test_cn_session_ended_on_disconnect` | ❌ W0 | ⬜ pending |
| 7-03-05 | 03 | 1 | CN_SessionState connected state | unit | `test_network_session.gd::test_cn_session_state_connected` | ❌ W0 | ⬜ pending |
| 7-03-06 | 03 | 1 | CN_SessionState disconnected state | unit | `test_network_session.gd::test_cn_session_state_disconnected` | ❌ W0 | ⬜ pending |
| 7-03-07 | 03 | 1 | Transient events cleared after one frame | unit | `test_network_session.gd::test_transient_events_cleared` | ❌ W0 | ⬜ pending |
| 7-03-08 | 03 | 1 | Session entity has no CN_NetworkIdentity | unit | `test_network_session.gd::test_session_entity_not_networked` | ❌ W0 | ⬜ pending |
| 7-03-09 | 03 | 1 | network_sync property exposed | unit | `test_network_session.gd::test_network_sync_property` | ❌ W0 | ⬜ pending |
| 7-04-01 | 04 | 2 | example_network refactored | smoke | manual / visual test in editor | manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `addons/gecs_network/tests/test_network_session.gd` — new test suite with all unit test stubs
- [ ] `addons/gecs_network/network_session.gd` — new class under test (skeleton)
- [ ] `addons/gecs_network/components/cn_peer_joined.gd` — transient event component
- [ ] `addons/gecs_network/components/cn_peer_left.gd` — transient event component
- [ ] `addons/gecs_network/components/cn_session_started.gd` — transient event component
- [ ] `addons/gecs_network/components/cn_session_ended.gd` — transient event component
- [ ] `addons/gecs_network/components/cn_session_state.gd` — permanent state component
- [ ] Update `GdUnitRunner.cfg` to include `test_network_session.gd`
- [ ] Run `$GODOT_BIN --headless --import --quit-after 5` to generate `.uid` files for all new `class_name` GDScript files

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| example_network/main.gd refactored to use NetworkSession | Phase 7 scope | Requires visual editor and live multiplayer test | Open Godot editor, run host and client instances, verify session connect/disconnect/peer events work as before |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
