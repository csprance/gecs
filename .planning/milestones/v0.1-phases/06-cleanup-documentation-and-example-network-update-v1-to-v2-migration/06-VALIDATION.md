---
phase: 6
slug: cleanup-documentation-and-example-network-update-v1-to-v2-migration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | GdUnit4 (bundled at `addons/gdUnit4/`) |
| **Config file** | `addons/gdUnit4/GdUnitRunner.cfg` |
| **Quick run command** | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests"` |
| **Full suite command** | `GODOT_BIN="/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe" addons/gdUnit4/runtest.cmd -a "res://addons/gecs_network/tests" -c` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 6-01-01 | 01 | 1 | Dead code deleted | manual | `find addons/gecs_network -name "sync_spawn_handler.gd"` returns empty | ✅ | ⬜ pending |
| 6-01-02 | 01 | 1 | No dangling refs | automated | Full suite run after deletions | ✅ | ⬜ pending |
| 6-02-01 | 02 | 1 | Example compiles | manual | `$GODOT_BIN --headless --import --quit-after 5` | ✅ | ⬜ pending |
| 6-02-02 | 02 | 1 | v2 API used correctly | manual | Code review of example_network/ | ✅ | ⬜ pending |
| 6-03-01 | 03 | 2 | README accurate | manual | Review README references to v2 classes only | ✅ | ⬜ pending |
| 6-03-02 | 03 | 2 | Docs complete | manual | Review all docs/*.md for v1 references | ✅ | ⬜ pending |
| 6-03-03 | 03 | 2 | Migration guide exists | manual | `test -f docs/migration-v1-to-v2.md` | ✅ | ⬜ pending |
| 6-04-01 | 04 | 2 | CHANGELOG updated | manual | Review CHANGELOG.md for [2.0.0] entry | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

Phase 6 has no new functional code — cleanup and documentation only. GdUnit4 is already installed and all verification is:
1. Full test suite run confirming no regressions after deletions
2. Godot headless import confirming example_network scripts parse cleanly
3. Manual doc review

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Dead v1 files deleted | Cleanup | File absence check | `find addons/gecs_network -name "sync_spawn_handler.gd" -o -name "sync_property_handler.gd" -o -name "sync_state_handler.gd" -o -name "sync_config.gd" -o -name "cn_sync_entity.gd" -o -name "cn_server_owned.gd"` — must return empty |
| Example network compiles | Example rewrite | Requires Godot headless run | `$GODOT_BIN --headless --import --quit-after 5` — no GDScript parse errors |
| No v1 API references in docs | Documentation | Text review | `grep -r "SyncConfig\|CN_SyncEntity\|NetworkMiddleware\|SyncPriority" addons/gecs_network/docs/` — must return empty |
| Migration guide is accurate | Documentation | Content verification | Read docs/migration-v1-to-v2.md, verify all v1→v2 mappings are correct |
| Example showcases all 4 v2 features | Example completeness | Code review | CN_NetSync, CN_NativeSync, custom handler, reconciliation all present in example |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
