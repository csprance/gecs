# Codebase Structure

**Analysis Date:** 2026-03-17

## Directory Layout

```
gecs/                                   # Project root
├── addons/
│   ├── gecs/                           # Core GECS addon (installable)
│   │   ├── ecs/                        # Core ECS classes
│   │   ├── network/                    # Network sync extension
│   │   ├── io/                         # Serialization utilities
│   │   ├── debug/                      # Editor debugger plugin
│   │   ├── lib/                        # Shared utilities (logger, Set, etc.)
│   │   ├── assets/                     # SVG icons for editor
│   │   ├── tests/                      # All unit and integration tests
│   │   │   ├── core/                   # Core ECS tests
│   │   │   ├── components/             # Test component fixtures
│   │   │   ├── systems/                # Test system fixtures
│   │   │   ├── network/                # Network-specific tests
│   │   │   └── performance/            # Performance benchmarks
│   │   ├── plugin.cfg                  # Godot plugin manifest
│   │   ├── plugin.gd                   # Plugin entry point
│   │   ├── README.md
│   │   └── LICENSE
│   └── gdUnit4/                        # gdUnit4 test framework (external)
├── example_network/                    # Multiplayer example game
│   ├── components/                     # Example game components
│   ├── entities/                       # Example entity scenes
│   ├── systems/                        # Example systems
│   ├── main.gd / main.tscn             # Example scene entry
│   └── core/                          # Example core logic
├── script_templates/                   # Godot script templates
│   ├── Node/                           # Templates for Node-derived classes
│   │   ├── entity.gd                   # Entity boilerplate
│   │   ├── system.gd                   # System boilerplate
│   │   └── observer.gd                 # Observer boilerplate
│   └── Resource/                       # Templates for Resource-derived classes
│       └── component.gd                # Component boilerplate
├── .github/                            # CI/CD workflows and actions
├── .planning/                          # GSD planning state (never committed)
├── reports/                            # Performance test output (JSONL)
├── project.godot                       # Godot project settings
└── CLAUDE.md                           # Claude AI project guidance
```

## Directory Purposes

**`addons/gecs/ecs/`:**
- Purpose: The six core ECS classes plus supporting types
- Contains: `ecs.gd` (singleton), `world.gd`, `entity.gd`, `component.gd`, `system.gd`, `observer.gd`, `query_builder.gd`, `archetype.gd`, `command_buffer.gd`, `relationship.gd`, `query_cache_key.gd`
- Key files: `addons/gecs/ecs/world.gd`, `addons/gecs/ecs/system.gd`, `addons/gecs/ecs/archetype.gd`

**`addons/gecs/network/`:**
- Purpose: Multiplayer synchronization layer (optional, attaches to a World)
- Contains: `network_sync.gd` (RPC surface), `spawn_manager.gd`, `sync_sender.gd`, `sync_receiver.gd`, `native_sync_handler.gd`, `sync_relationship_handler.gd`, `sync_reconciliation_handler.gd`, `net_adapter.gd`, `transport_provider.gd`, `network_session.gd`, `gecs_network_settings.gd`
- Contains subdirs: `components/` (network-specific components: `cn_network_identity.gd`, `cn_net_sync.gd`, `cn_local_authority.gd`, etc.), `transports/` (`enet_transport_provider.gd`, `steam_transport_provider.gd`)
- Key files: `addons/gecs/network/network_sync.gd`, `addons/gecs/network/net_adapter.gd`

**`addons/gecs/io/`:**
- Purpose: Serialize/deserialize world state to/from disk (binary or text JSON)
- Contains: `io.gd`, `gecs_data.gd`, `gecs_entity_data.gd`, `gecs_relationship_data.gd`, `serialize_config.gd`

**`addons/gecs/debug/`:**
- Purpose: Editor debugger plugin; sends ECS state to Godot's debugger tab
- Contains: `gecs_editor_debugger.gd`, `gecs_editor_debugger_messages.gd`, `gecs_editor_debugger_tab.gd`, `gecs_editor_debugger_tab.tscn`

**`addons/gecs/lib/`:**
- Purpose: Shared utilities used across the addon
- Contains: `logger.gd` (GECSLogger), `set.gd` (Set data structure), `array_extensions.gd`, `component_query_matcher.gd`, `gecs_settings.gd`, `system_group.gd`
- Key files: `addons/gecs/lib/system_group.gd` (scene-tree organizer for Systems), `addons/gecs/lib/component_query_matcher.gd`

**`addons/gecs/tests/`:**
- Purpose: All tests; no tests exist outside this directory
- Contains: `core/` (entity, world, system, observer, query, archetype, command buffer, relationship, serialization tests), `components/` (fixture components prefixed `c_`), `systems/` (fixture systems prefixed `s_`, observers prefixed `o_`), `network/`, `performance/`

**`example_network/`:**
- Purpose: Fully working multiplayer demo using GECS + GECS Network
- Contains real component/entity/system patterns showing idiomatic usage
- Key files: `example_network/main.gd`, `example_network/entities/e_player.gd`, `example_network/systems/s_movement.gd`

**`script_templates/`:**
- Purpose: Godot editor script templates; appear in the "New Script" dialog under template names
- Node templates: `entity.gd`, `system.gd`, `observer.gd`
- Resource templates: `component.gd`

## Key File Locations

**Entry Points:**
- `addons/gecs/plugin.gd`: Addon activation; registers ECS autoload + project settings
- `addons/gecs/ecs/ecs.gd`: ECS singleton (`autoload "ECS"`)
- `addons/gecs/ecs/world.gd`: World node placed in scene tree

**Core ECS:**
- `addons/gecs/ecs/entity.gd`: Entity base class
- `addons/gecs/ecs/component.gd`: Component base class
- `addons/gecs/ecs/system.gd`: System base class
- `addons/gecs/ecs/observer.gd`: Observer base class
- `addons/gecs/ecs/archetype.gd`: Archetype storage
- `addons/gecs/ecs/query_builder.gd`: Query fluent API
- `addons/gecs/ecs/command_buffer.gd`: Deferred mutation buffer
- `addons/gecs/ecs/relationship.gd`: Entity relationships

**Network:**
- `addons/gecs/network/network_sync.gd`: Attach point; all `@rpc` methods
- `addons/gecs/network/net_adapter.gd`: Multiplayer abstraction layer
- `addons/gecs/network/spawn_manager.gd`: Entity lifecycle broadcast/receive
- `addons/gecs/network/sync_sender.gd`: Per-tick property diff + send
- `addons/gecs/network/sync_receiver.gd`: Apply received component data
- `addons/gecs/network/gecs_network_settings.gd`: ProjectSettings constants

**Utilities:**
- `addons/gecs/lib/system_group.gd`: SystemGroup scene-tree organizer
- `addons/gecs/lib/logger.gd`: GECSLogger domain logger
- `addons/gecs/lib/component_query_matcher.gd`: Property query evaluation
- `addons/gecs/lib/set.gd`: Set operations used in group queries

**Testing:**
- `addons/gecs/tests/core/`: Core unit and integration tests
- `addons/gecs/tests/performance/`: Parameterized benchmark tests
- `addons/gdUnit4/`: gdUnit4 test runner

## Naming Conventions

**Files:**
- Components: `c_` prefix — e.g., `c_velocity.gd`, `c_net_sync.gd`
- Entities: `e_` prefix — e.g., `e_player.gd`, `e_projectile.gd`
- Systems: `s_` prefix — e.g., `s_movement.gd`, `s_player_init.gd`
- Observers: `o_` prefix — e.g., `o_health_observer.gd`
- Network components: `cn_` prefix — e.g., `cn_network_identity.gd`, `cn_local_authority.gd`
- Test fixtures follow same prefix conventions inside `addons/gecs/tests/`
- Scene files: same base name as the primary script — e.g., `e_player.tscn`

**Classes (`class_name`):**
- Components: `C_` prefix — e.g., `C_Velocity`, `C_NetSync`
- Entities: `E_` prefix — e.g., `E_Player`
- Systems: `S_` prefix — e.g., `S_Movement`
- Network components: `CN_` prefix — e.g., `CN_NetworkIdentity`, `CN_LocalAuthority`
- Core framework classes: PascalCase without prefix — `World`, `Entity`, `Component`, `System`, `Observer`, `Relationship`, `QueryBuilder`, `CommandBuffer`, `Archetype`
- ECS singleton: `_ECS` (class_name), accessed as `ECS` (autoload node name)

**Directories:**
- Lowercase snake_case for all directories — e.g., `example_network/`, `script_templates/`
- Test fixtures are co-located in subdirs of `addons/gecs/tests/` (`components/`, `systems/`) rather than alongside source files

## Where to Add New Code

**New Component:**
- Implementation: `addons/gecs/network/components/cn_my_component.gd` (if network-specific) or in game project as `c_my_component.gd`
- Class name: `CN_MyComponent` / `C_MyComponent` extending `Component`
- Test fixtures: `addons/gecs/tests/components/c_my_test_component.gd`

**New System:**
- Implementation: Game project as `s_my_system.gd`, extending `System`
- Scene: Add as a child of a `SystemGroup` node or directly under `system_nodes_root`
- Tests: `addons/gecs/tests/systems/s_my_test_system.gd`

**New Observer:**
- Implementation: Game project as `o_my_observer.gd`, extending `Observer`
- Placement: Scene tree under `system_nodes_root` alongside systems

**New Core Framework Test:**
- Location: `addons/gecs/tests/core/test_my_feature.gd` (only location — see CLAUDE.md)
- Fixtures: components in `addons/gecs/tests/components/`, systems in `addons/gecs/tests/systems/`

**New Network Handler:**
- Location: `addons/gecs/network/my_handler.gd`
- Pattern: Pass `NetworkSync` reference to constructor; delegate from `NetworkSync._ready()`

**New Utility:**
- Shared addon utilities: `addons/gecs/lib/my_util.gd`

## Special Directories

**`.planning/`:**
- Purpose: GSD planning state files (STATE.md, phases, codebase docs)
- Generated: Yes, by GSD commands
- Committed: No — never commit `.planning/` files

**`reports/perf/`:**
- Purpose: Performance test JSONL output from benchmark tests
- Generated: Yes, by running `addons/gecs/tests/performance/` tests
- Committed: Optional (tracks performance over time)

**`.godot/`:**
- Purpose: Godot engine cache (imported assets, shader cache, editor state)
- Generated: Yes, by Godot engine
- Committed: Partially (`.uid` files are committed; shader cache is not)

**`addons/gdUnit4/`:**
- Purpose: gdUnit4 testing framework (external dependency, included in repo)
- Generated: No (vendored)
- Committed: Yes

---

*Structure analysis: 2026-03-17*
