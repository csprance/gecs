# External Integrations

**Analysis Date:** 2026-03-17

## APIs & External Services

**Multiplayer / Networking:**
- Godot built-in ENet — Default transport for peer-to-peer multiplayer
  - SDK/Client: `ENetMultiplayerPeer` (Godot built-in, no install)
  - Auth: Not applicable — direct IP:port connections
  - Implementation: `addons/gecs/network/transports/enet_transport_provider.gd`
  - Default port: 7777, default max players: 4

- GodotSteam (optional) — Steam P2P transport via `SteamMultiplayerPeer`
  - SDK/Client: GodotSteam plugin (external, not bundled)
  - Auth: Steam SDK (handled by GodotSteam, not GECS)
  - Implementation: `addons/gecs/network/transports/steam_transport_provider.gd`
  - Availability check: `ClassDB.class_exists("SteamMultiplayerPeer")` — safe to compile without

**Performance Monitoring (local dev only):**
- InfluxDB 2.7 — Time-series storage for test performance JSONL data
  - Connection: `http://influxdb:8086` (Docker)
  - Token: configured in `tools/grafana/docker-compose.yml`
  - Org/Bucket: `gecs` / `performance`
  - Data source: `reports/perf/*.jsonl`

- Grafana (latest) — Dashboards for performance metrics
  - UI: `http://localhost:3000`
  - Dashboard definitions: `tools/grafana/provisioning/dashboards/`
  - Datasource config: `tools/grafana/provisioning/datasources/influxdb.yml`

## Data Storage

**Databases:**
- None — No runtime database
- Performance data (dev only): InfluxDB via Docker Compose at `tools/grafana/`

**File Storage:**
- Godot `ResourceSaver` / `ResourceLoader` — Entity serialization to local filesystem
  - Text format: `.tres` files
  - Binary format: `.res` files (compressed)
  - Implementation: `addons/gecs/io/io.gd` via `GECSIO.save()` / `GECSIO.deserialize()`

**Caching:**
- In-memory only — World query cache in `addons/gecs/ecs/world.gd`
- No external cache service

## Authentication & Identity

**Auth Provider:**
- None — No external auth
- Network identity managed internally via `CN_NetworkIdentity` component (`addons/gecs/network/components/cn_network_identity.gd`) using Godot peer IDs
- Entity UUIDs generated locally via `GECSIO.uuid()` in `addons/gecs/io/io.gd`

## Monitoring & Observability

**Error Tracking:**
- None (no Sentry, Rollbar, etc.)
- Godot's built-in `push_error()` / `push_warning()` used throughout

**Logs:**
- Custom `GECSLogger` in `addons/gecs/lib/logger.gd`
- Log levels: TRACE, DEBUG, INFO, WARNING, ERROR
- Controlled via `gecs/settings/log_level` ProjectSetting
- Logger is globally disabled in production (`const disabled := true` in `logger.gd`)
- Output: `print()` to Godot console / stdout

**Performance Metrics:**
- Test output: JSONL files written to `reports/perf/` (one entry per test run)
- Format: `{"timestamp":"...","test":"...","scale":N,"time_ms":N,"godot_version":"..."}`
- Analysis tool: `tools/analyze_perf.py`
- Optional visualization: InfluxDB + Grafana Docker stack (`tools/grafana/`)

## CI/CD & Deployment

**Hosting:**
- GitHub — Source code and releases
- Godot Asset Library — Plugin distribution (submitted via `godot-asset-library-vX.Y.Z` branches)

**CI Pipeline:**
- GitHub Actions
  - Test workflow: `.github/workflows/test.yml` — runs gdUnit4 tests on `ubuntu-22.04` with Godot 4.5 (triggers on push to `main`)
  - Build/release workflow: `.github/workflows/build.yml` — creates release branches on `v*` tags; produces `release-vX.Y.Z` (submodule) and `godot-asset-library-vX.Y.Z` (Asset Library) branches
  - Shared setup action: `.github/actions/setup-release/action.yml`

## Environment Configuration

**Required env vars:**
- `GODOT_BIN` — Path to Godot executable; required only for running tests locally via CLI scripts

**Secrets location:**
- GitHub Actions secrets (not in repo) — used for `godot-asset-library-approval` environment gating in build workflow
- No `.env` files detected

## Webhooks & Callbacks

**Incoming:**
- None — No HTTP webhooks

**Outgoing:**
- None — No HTTP webhooks

**Network RPCs (internal, Godot multiplayer):**
- All RPCs declared on `NetworkSync` node (`addons/gecs/network/network_sync.gd`)
- RPC surface: spawn/despawn/world-state lifecycle, property sync, relationship sync
- Session ID guard on every RPC to reject stale cross-game calls

---

*Integration audit: 2026-03-17*
