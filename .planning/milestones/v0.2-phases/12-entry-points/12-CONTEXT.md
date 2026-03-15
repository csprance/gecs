# Phase 12: Entry Points - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Rewrite the root README and both addon READMEs (addons/gecs/README.md, addons/gecs_network/README.md) to be accurate first impressions — correct install steps, real runnable quick-start code, consistent with the rewritten docs from Phases 8–11. No other files are in scope.

</domain>

<decisions>
## Implementation Decisions

### Quick-start code (root README)

- Medium depth (~40 lines): show entity creation, add_component(), relationships, and a full System with process()
- Show **both** component patterns in one snippet: `@export var` with a default AND a custom `_init()` with a parameter — with a comment explaining that every property needs a default or Godot will error
- Include `ECS.process(delta)` in a `_process()` function so the loop is complete
- Code must actually compile and run against GECS v6.8.1 — no illustrative-only snippets

### Feature list (root README)

- Keep emoji in the feature list bullets only (🎯 🚀 etc.) — README landing pages are different from reference docs
- Keep "Battle Tested — Used in games being actively developed." as-is
- Include Debug Viewer in the feature list — it exists in v6.8.1
- GECS Network: reference as a separate optional addon with a link, not a core GECS feature

### Install instructions (root README)

- Cover all three install paths: Godot Asset Library, manual copy, git submodule
- Add a Requirements section stating Godot 4.x minimum
- GECS Network install lives in the network addon's own README only — root README links to it

### Addon README relationship

- Root README and gecs addon README serve the same audience — one is for GitHub visitors, one for in-editor browsing after install. Keep them essentially the same depth and content.
- Emoji policy for READMEs: keep emoji in feature lists and section headers (same as root README) — does NOT apply the strict no-emoji policy from docs Phase 8-11

### GECS addon README

- Keep the Learning Path and topic tables — useful navigation for the in-editor experience
- Transport providers claim ("ENet, Steam, or custom backends") is accurate — both `ENetTransportProvider` and `SteamTransportProvider` exist in source. Keep it.

### GECS Network addon README quick start

- Add Step 4: Start a session with NetworkSession (host/join/end_session API)
- NetworkSession is the primary entry point from Phase 7 and must appear in the quick start
- Steps: 1) declare sync priorities, 2) define_components with CN_NetworkIdentity + CN_NetSync, 3) attach NetworkSync, 4) start session with NetworkSession

### Claude's Discretion

- Exact phrasing of install step text
- Whether to use numbered steps or headings for install paths
- Exact wording of Requirements section
- What code appears in the NetworkSession quick start step (use real API from network_session.gd)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `addons/gecs_network/network_session.gd` (class_name NetworkSession): host(), join(), end_session() API — use real method signatures in step 4
- `addons/gecs_network/transports/enet_transport_provider.gd` (ENetTransportProvider): real class, cite accurately
- `addons/gecs_network/transports/steam_transport_provider.gd` (SteamTransportProvider): real class, cite accurately
- `addons/gecs_network/transport_provider.gd` (TransportProvider): base class for custom backends

### Established Patterns

- Root README currently at `README.md` — needs install section added, emoji cleaned from body text, quick-start code fixed
- gecs addon README at `addons/gecs/README.md` — has full learning path + tables, one 📖 emoji in header (keep)
- Network addon README at `addons/gecs_network/README.md` — 3-step quick start needs step 4 (NetworkSession)

### Integration Points

- Root README links to addons/gecs/README.md and addons/gecs_network/README.md
- Both addon READMEs should be consistent with the docs rewritten in Phases 8–11 — no contradictions

</code_context>

<specifics>
## Specific Ideas

- The quick-start component example should include a comment like `# All properties need a default value or Godot will error` near the @export var pattern
- Both the `@export var` pattern (no constructor needed) and `_init(value)` pattern should appear in the same quick-start so readers see both options
- The install section should have three labeled subsections, not just a flat list

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 12-entry-points*
*Context gathered: 2026-03-14*
