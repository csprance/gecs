# GECS Networking v2

## What This Is

A complete overhaul of GECS networking that replaces the current complex middleware system with a simple, config-driven approach. Components declare their sync behavior, systems can override when needed, and the framework handles all the networking complexity automatically.

## Core Value

Developers should be able to add multiplayer to their ECS game by simply marking components as networked - no manual RPC calls, serialization code, or complex networking logic required.

## Requirements

### Validated

- ✓ Entity Component System core functionality — existing
- ✓ Query-based entity filtering — existing  
- ✓ System processing with groups — existing
- ✓ CommandBuffer for safe structural changes — existing

### Active

- [ ] Component-level network configuration (sync rules, authority, rate limiting)
- [ ] Automatic entity lifecycle sync (spawn/despawn without manual RPCs)
- [ ] System-level networking overrides for complex behaviors
- [ ] Fallback to manual networking for edge cases
- [ ] Clean separation between local and networked entities
- [ ] Robust error handling and connection management

### Out of Scope

- Client prediction/lag compensation — defer to v3
- P2P networking — server-client only for now
- Network topology changes — assume fixed server/client roles
- Backwards compatibility with current networking — clean break

## Context

Current GECS networking uses NetworkMiddleware with manual RPC registration and complex serialization. While functional, it requires developers to write significant boilerplate and is prone to sync bugs (entities don't despawn on clients, components get out of sync). The layered approach makes debugging difficult and small changes often break networking in unexpected ways.

The ECS pattern is perfect for automatic networking - components are pure data that can be synced, and systems naturally define when changes should propagate. Most multiplayer games follow predictable patterns that can be handled declaratively.

## Constraints

- **Tech stack**: GDScript only — maintain GECS's simplicity
- **Godot version**: Must work with Godot 4.x multiplayer APIs
- **Performance**: Zero networking overhead for single-player games
- **Migration**: New branch, no backwards compatibility required
- **Architecture**: Build on existing GECS core, replace only networking layer

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Component-first configuration | ECS components are natural sync units, cleaner than system-based | — Pending |
| Replace rather than extend | Current approach is fundamentally complex, clean slate needed | — Pending |
| New branch development | Allows complete redesign without breaking existing users | — Pending |

## Current Milestone: v1.0 GECS Networking v2

**Goal:** Replace the current NetworkMiddleware system with a declarative, component-driven networking layer that requires zero manual RPC code.

**Target features:**
- Component-level network configuration (sync rules, authority, rate limiting)
- Automatic entity lifecycle sync (spawn/despawn without manual RPCs)
- System-level networking overrides for complex behaviors
- Fallback to manual networking for edge cases
- Clean separation between local and networked entities
- Robust error handling and connection management

---
*Last updated: 2026-03-07 after milestone v1.0 started*