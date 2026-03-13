# Milestones

## v0.1 GECS Networking v2 (Shipped: 2026-03-13)

**Phases completed:** 7 phases, 26 plans, 5 tasks

**Key accomplishments:**
- Automatic entity lifecycle sync — spawn/despawn replicated to all peers with zero manual RPCs; late-join receives full world state snapshot
- Declarative component sync — `CN_NetSync` + `@export_group` drives priority-tiered batched RPCs (REALTIME/HIGH/MEDIUM/LOW) with dirty-only bandwidth
- Authority model — `CN_LocalAuthority`/`CN_ServerAuthority` marker components; native `MultiplayerSynchronizer` for smooth transform interpolation
- Relationship sync — entity-to-entity relationships replicated with deferred resolution for non-deterministic spawn ordering
- Reconciliation + custom handlers — periodic full-state broadcast corrects drift; `register_send/receive_handler` API enables client-side prediction patterns
- `NetworkSession` node — `session.host()` / `session.join()` reduces multiplayer setup to 3 lines; lifecycle events surface as ECS components
- Full v2 docs + migration guide — all 8 docs rewritten, README v2 Quick Start, CHANGELOG [2.0.0], v1→v2 migration guide

---

