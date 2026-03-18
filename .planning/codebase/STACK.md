# Technology Stack

**Analysis Date:** 2026-03-17

## Languages

**Primary:**
- GDScript - All game framework code, systems, components, entities, tests
- Python 3.x - Performance tooling (`tools/analyze_perf.py`, data loader scripts)

**Secondary:**
- YAML - GitHub Actions CI/CD workflows (`.github/workflows/`)
- JSON - VSCode config, Grafana dashboard provisioning

## Runtime

**Environment:**
- Godot Engine 4.5 (targeted in CI; also runs on 4.6 per dev environment)

**Dev Godot Binary:**
- `D:\Godot\Godot_v4.6\Godot_v4.6-stable_win64.exe` (Windows)
- Shell path: `/d/Godot/Godot_v4.6/Godot_v4.6-stable_win64.exe`

**Package Manager:**
- None — Godot projects do not use a package manager
- Lockfile: Not applicable

## Frameworks

**Core:**
- Godot 4.x engine — Runtime, scene tree, Node/Resource base classes, built-in multiplayer (ENet via `ENetMultiplayerPeer`, `MultiplayerAPI`)
- GECS (`addons/gecs/`, version 7.0.1) — ECS framework built on top of Godot; auto-loaded as `ECS` singleton

**Testing:**
- gdUnit4 (`addons/gdUnit4/`, version 6.1.1) — Unit testing framework for GDScript; runs via `addons/gdUnit4/runtest.cmd` / `runtest.sh`
- godot-gdunit-labs/gdUnit4-action v1.3.0 — GitHub Actions runner for CI tests

**Build/Dev:**
- GitHub Actions — CI pipeline (`.github/workflows/test.yml`, `.github/workflows/build.yml`)
- Docker Compose — Optional local performance monitoring stack (`tools/grafana/docker-compose.yml`)

## Key Dependencies

**Critical:**
- Godot 4.x `ENetMultiplayerPeer` — Default transport for GECS Network; built into the engine, no install required
- Godot 4.x `MultiplayerAPI` — All RPC and peer management; accessed via `NetAdapter` abstraction
- Godot 4.x `ResourceSaver` / `ResourceLoader` — GECS IO serialization to `.tres` (text) and `.res` (binary) formats

**Optional / Conditional:**
- GodotSteam (`SteamMultiplayerPeer`) — Optional Steam transport; loaded dynamically via `ClassDB.class_exists("SteamMultiplayerPeer")` in `addons/gecs/network/transports/steam_transport_provider.gd`; project compiles and runs without it
- InfluxDB 2.7 — Performance data storage (optional, local dev only, `tools/grafana/`)
- Grafana (latest) — Performance dashboards (optional, local dev only, `tools/grafana/`)

**Dev Tools:**
- debug_menu addon (`addons/debug_menu/`) — In-editor debug overlay
- godot-plugin-refresher addon (`addons/godot-plugin-refresher/`) — Editor plugin reload utility

## Configuration

**Environment:**
- Configured via Godot `ProjectSettings` (stored in `project.godot`)
- GECS settings namespace: `gecs/settings/log_level`, `gecs/settings/debug_mode`
- GECS Network settings namespace: `gecs/network/sync/high_hz` (default 20), `gecs/network/sync/medium_hz` (default 10), `gecs/network/sync/low_hz` (default 2), `gecs/network/sync/reconciliation_interval` (default 30.0)
- Settings constants defined in `addons/gecs/lib/gecs_settings.gd` and `addons/gecs/network/gecs_network_settings.gd`
- Settings registered at editor startup by `addons/gecs/plugin.gd`

**Build:**
- No build system; Godot exports via `export_presets.cfg`
- Release automation via `.github/workflows/build.yml` (triggered on `v*` tags)

## Platform Requirements

**Development:**
- Godot 4.5+ (4.6 used locally)
- `GODOT_BIN` environment variable must be set for running tests via CLI
- Windows: `REG ADD HKCU\CONSOLE /f /v VirtualTerminalLevel /t REG_DWORD /d 1` for colored output

**Production:**
- Godot game runtime (desktop/mobile/web depending on export preset)
- No server-side backend required — peer-to-peer via ENet or Steam
- Optional: Docker for local performance monitoring stack

---

*Stack analysis: 2026-03-17*
