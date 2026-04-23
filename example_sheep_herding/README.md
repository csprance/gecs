# Sheep Herding

A small ECS demo showing reactive observers, relationship-driven flocking, a
CommandBuffer-safe flee/wander state machine, and CharacterBody3D +
NavigationAgent3D movement — all wired on top of GECS.

The shepherd's sheep escaped. Drive the shepherd with WASD (hold Shift to
sprint) and herd every sheep back into the pen.

## Controls

| Key | Action |
| --- | --- |
| W/A/S/D | Move shepherd (camera-relative) |
| Shift | Sprint |

## Entities

### Sheep (`entities/e_sheep.tscn`)
`CharacterBody3D` carrying:
- `C_Sheep` — zero-field species tag used in every sheep query.
- `C_SheepMovement` — walk / run / rotation speed.
- `C_SheepThreat` — flee / safe radii (hysteresis: `safe_radius > flee_radius`).
- `C_Flocking` — separation / alignment / cohesion weights.
- `C_Wander` — random-target state (where to go next, rest timer).
- `C_Velocity` — the shared velocity bus read by the velocity-integration system.

The scene also carries a `NavigationAgent3D` for pathfinding and a `FlockArea3D`
(Area3D trigger) that records flockmate relationships on overlap.

### Shepherd (`entities/e_shepherd.tscn`)
`CharacterBody3D` carrying:
- `C_Shepherd` — move speed, sprint multiplier, rotation speed.
- `C_Velocity` — the shepherd's velocity, written by `ShepherdSystem`.

### Pen (`entities/e_pen.tscn`)
`Node3D` carrying `C_Pen` (radius). Holds a `PenArea3D` (Area3D) child whose
`body_entered` signal emits the `&"sheep_entered_pen"` ECS event.

## Systems (`systems/`, group `sim`, runs in `_physics_process`)

Order matters — steering writes to `C_Velocity`, integration reads it:

1. **ShepherdSystem** — reads WASD, writes camera-relative velocity + rotation,
   follows the main camera.
2. **WanderSystem** — picks random targets, drives each sheep's
   NavigationAgent3D toward them, blends flocking into the path direction,
   writes velocity. Escalates to `C_Flee` when a shepherd enters the
   sheep's flee radius.
3. **FleeSystem** — writes a direct-away velocity at run speed. Strips
   `C_Flee` (via CommandBuffer) when the shepherd leaves the safe radius.
4. **SheepVelocitySystem** — reads `C_Velocity` on every entity, calls
   `CharacterBody3D.move_and_slide` (or falls back to direct position
   integration for non-CharacterBody3D entities).

## Observers (`observers/`)

Reactive — they don't run every frame, only fire on specific events.

- **O_Penned** — `with_all([C_Sheep, C_Penned]).on_added()`. Strips
  `C_Wander`, `C_Flee`, and `C_Velocity` via CommandBuffer when a sheep is
  penned. Terminal transition (C_Penned is never removed).
- **O_SheepEnteredPen** — subscribes to the custom
  `&"sheep_entered_pen"` event emitted by `PenArea3D.body_entered`. Queues
  `C_Penned` on the sheep via CommandBuffer.

## Flocking via Relationships

Each sheep carries a `FlockArea3D` (Area3D trigger). When two sheep overlap,
`FlockArea._on_area_entered` creates a `C_Flockmate` relationship pointing from
self to the other. `Flocking.compute` (in `lib/flocking.gd`) then reads those
relationships via `entity.get_relationships(R_AnyFlockmate)` — no per-frame
O(N²) distance scan. `R_AnyFlockmate` is a module-static relationship pattern
(a wildcard `Relationship(C_Flockmate.new(), null)`) reused across all calls
to avoid per-call allocation.

## File Map

```
example_sheep_herding/
  components/                       # Pure-data Resources
    c_sheep.gd                      # Zero-field species tag
    c_sheep_movement.gd             # Speeds
    c_sheep_threat.gd               # flee / safe radii
    c_flocking.gd                   # Flocking weights
    c_wander.gd                     # Wander-state
    c_flee.gd                       # Pure marker
    c_flockmate.gd                  # Pure marker (relationship payload)
    c_penned.gd                     # Terminal pen-state marker
    c_pen.gd                        # Pen radius
    c_shepherd.gd                   # Shepherd tuning
  entities/
    e_sheep.gd / .tscn              # CharacterBody3D + NavigationAgent3D + FlockArea3D
    e_shepherd.gd / .tscn           # CharacterBody3D
    e_pen.gd / .tscn                # Node3D + PenArea3D
  systems/
    s_shepherd.gd                   # Input → velocity
    s_wander.gd                     # Pathfinding → velocity
    s_flee.gd                       # Flee vector → velocity
    s_velocity.gd                   # velocity → move_and_slide
  observers/
    o_penned.gd                     # On C_Penned add: strip behavior
    o_sheep_entered_pen.gd          # On event: add C_Penned
  lib/
    flocking.gd                     # Static flocking helper
    sheep_math.gd                   # face(), xz_distance_sq, cached shepherd lookup
    flock_area.gd / .tscn           # Area3D that populates C_Flockmate relationships
    pen_area_3d.gd / .tscn          # Area3D that emits &"sheep_entered_pen"
  main.gd / main.tscn               # Scene entry point
```

## Notes for Readers

- **Pathfinding:** the `NavigationRegion3D` in `main.tscn` needs to be baked in
  the editor (select the node → click "Bake NavigationMesh"). Without a baked
  mesh, NavigationAgent3D degrades gracefully to direct-line movement.
- **Frame timing:** only `_physics_process` drives the `sim` group — every
  system uses `delta` consistently at 60Hz regardless of display refresh rate.
- **One-way penning:** once a sheep has `C_Penned`, it never leaves that state.
  The win condition is all sheep penned.
