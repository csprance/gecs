# Phase 8: Foundation Docs - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Rewrite and verify the three "first-touch" docs a new GECS developer reads:
- `addons/gecs/docs/GETTING_STARTED.md`
- `addons/gecs/docs/CORE_CONCEPTS.md`
- `addons/gecs/docs/SERIALIZATION.md`

Goal: every code example compiles against GECS v6.8.1, every API reference is real. No other docs are in scope for this phase.

</domain>

<decisions>
## Implementation Decisions

### Rewrite depth
- Use per-doc judgment: light edit where API is mostly accurate, full rewrite where structure is fundamentally broken
- Rewrites may add new sections/concepts if they close clear gaps (e.g., CommandBuffer wasn't in GETTING_STARTED but is needed)
- Prefer **minimal code examples** — just enough to show the API signature works, not full tutorial patterns
- CORE_CONCEPTS: keep ECS philosophy framing but trim if bloated; it's not just a reference, it's an intro

### Tone & style
- Strip all emojis from headers and body text
- No lengthy intro paragraphs — lead with content immediately
- No version stamp at the top (no "Verified against GECS v6.8.1" line)
- Keep blockquote callout boxes (`> **Note:** ...`), but no emoji in them
- No trailing "By the end of this guide..." preamble

### Serialization
- Full accurate API doc — the system is real (ECS.serialize/save/deserialize, GECSSerializeConfig, GecsData all verified in source)
- Document both save formats: text .tres and binary .res (binary: bool param is real)
- Cover GECSSerializeConfig — it's an @export on Entity and World, devs will hit it

### GETTING_STARTED scope
- Keep both entity paths: scene-based (spatial) and code-based (pure data)
- Terminal state: dev has built the minimal complete ECS loop — entity + component + system + ECS.process()
- Mention CommandBuffer briefly with a link to CORE_CONCEPTS — do not teach it in GETTING_STARTED
- Installation: brief (2-3 lines) — copy to addons/, enable plugin, verify ECS autoload — link to README for detail

### Claude's Discretion
- Exact structure and section ordering within each doc
- Whether CORE_CONCEPTS gets a brief "why ECS" intro or cuts straight to class-by-class reference
- Which specific examples to use in minimal code samples (just make them accurate)
- Cross-linking strategy between the three docs

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `addons/gecs/ecs/ecs.gd` — ECS singleton: process(), serialize(), save(), deserialize(), get_components()
- `addons/gecs/ecs/entity.gd` — Entity: add_component(), remove_component(), get_component(), has_component(), add_relationship(), remove_relationship(), serialize_config @export
- `addons/gecs/ecs/world.gd` — World: default_serialize_config @export
- `addons/gecs/io/io.gd` (GECSIO) — actual serialize/deserialize implementation
- `addons/gecs/io/serialize_config.gd` — GECSSerializeConfig class
- `addons/gecs/io/gecs_data.gd` — GecsData class
- `addons/gecs/io/gecs_entity_data.gd` — GecsEntityData class

### Established Patterns
- Entity API uses Resource-typed component args (e.g., `get_component(C_Transform)` returns Component)
- ECS.process(delta, group) — second arg is optional group string
- ECS.serialize(query, config=null) — config is optional GECSSerializeConfig
- ECS.save(data, filepath, binary=false) — binary flag is real

### Integration Points
- GETTING_STARTED → CORE_CONCEPTS (link at end)
- CORE_CONCEPTS → SERIALIZATION (link for persistence topics)
- All three docs are in `addons/gecs/docs/` — relative linking works

</code_context>

<specifics>
## Specific Ideas

No specific "I want it like X" references came up — open to standard approaches within the decisions captured above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 08-foundation-docs*
*Context gathered: 2026-03-13*
