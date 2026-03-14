# Phase 11: Network Docs - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Verify and fix all 10 docs in `addons/gecs_network/docs/` against the actual gecs_network v1.0.0 GDScript source:

- `architecture.md`
- `authority.md`
- `best-practices.md`
- `components.md`
- `configuration.md`
- `custom-sync-handlers.md`
- `examples.md`
- `migration-v1-to-v2.md`
- `sync-patterns.md`
- `troubleshooting.md`

Goal: every API call, code example, and pattern claim is verifiable against actual source. No other docs in scope.

Note: The roadmap success criteria say "8 docs" — the actual count is 10. Treat all 10 as in scope.

</domain>

<decisions>
## Implementation Decisions

### Tone & style (carried from Phases 8/9/10)

- Strip all emoji from headers and body text
- No version stamps at the top
- No lengthy intro paragraphs — lead with content
- Keep blockquote callout boxes (`> **Note:** ...`), no emoji inside them
- Minimal code examples — just enough to show the API works

### Doc scope

- All 10 docs are in scope
- All 10 are treated as suspect until verified — no doc gets a pass based on assumed accuracy
- Treat all with equal verification depth

### Migration guide (migration-v1-to-v2.md)

- Do NOT deeply verify the content against source
- Add a deprecated notice at the top only (e.g., `> **Note:** This guide covers upgrading from v0.1.x. If you are starting fresh with v1.0.0, ignore this file.`)
- No other changes needed — the minimal intervention is intentional

### Fabricated content resolution

- When content cannot be verified against v1.0.0 source: **remove it entirely**
- Do not add warning callouts ("this pattern is unimplemented") — just cut
- Exception: if a real equivalent exists in source, replace with the real pattern

### Prediction patterns

- `best-practices.md` contains prediction examples using `predicted_position` and `LOCAL` tier framing
- The LOCAL tier itself (`@export_group("LOCAL")`) is real and accurate
- Remove any code or prose that frames LOCAL tier as "client prediction" — that implies a system that doesn't exist
- If the LOCAL tier example is otherwise accurate (never-synced properties), keep the example stripped of the prediction framing

### Plan structure

- Single plan for all 10 docs — one verification pass
- Executor chooses order freely — no prescribed sequence

### Claude's Discretion

- Order in which docs are verified within the single plan
- Whether any sections can be cleanly merged after redundant content is removed
- Cross-link strategy between docs after verification

</decisions>

<code_context>
## Existing Code Insights

### Real API surface (verified from source and prior phases)

**Network components (addons/gecs_network/components/):**
- `CN_NetworkIdentity` — required for all networked entities; `is_server_owned()` true for peer_id==0 ONLY
- `CN_NetSync` — required for property sync; no constructor args; config via `@export_group` on sibling components
- `CN_LocalAuthority`, `CN_ServerAuthority` — marker components (not Godot's `is_multiplayer_authority()`)
- `CN_NativeSync` — wraps MultiplayerSynchronizer for transform sync
- `CN_RemoteEntity` — marks entities owned by remote peers
- `CN_SessionStarted`, `CN_SessionEnded`, `CN_PeerJoined`, `CN_PeerLeft` — transient event components
- `CN_SessionState` — persistent session state component

**NetworkSession API:**
- `host()`, `join()`, `end_session()` — (not `disconnect()` — that's a built-in signal method)

**Priority tiers via @export_group:**
- `"REALTIME"` ~60Hz unreliable, `"HIGH"` 20Hz unreliable, `"MEDIUM"` 5Hz unreliable, `"LOW"` 1Hz reliable
- `"SPAWN_ONLY"` — sent once at spawn, never again
- `"LOCAL"` — never synced

**NetworkSync API:**
- `attach_to_world(world)` — second arg is optional NetAdapter
- `register_send_handler(handler)` / `register_receive_handler(handler)` — custom sync override
- Signals: `entity_spawned`, `local_player_spawned`

**Key architecture decisions (from PROJECT.md):**
- `peer_id=0` = server-owned only (not peer_id=1)
- Transient event components cleared at START of `_process()` — systems see them for a full frame
- `session.network_sync == null` as connection guard
- `TransportProvider extends Resource` (for @export compatibility)

### Integration Points

- All 10 docs in `addons/gecs_network/docs/` — relative links work
- Core GECS docs in `addons/gecs/docs/` — cross-links possible but not required

</code_context>

<specifics>
## Specific Ideas

No specific references or "I want it like X" moments from discussion.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 11-network-docs*
*Context gathered: 2026-03-14*
