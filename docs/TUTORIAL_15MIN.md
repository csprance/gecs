# GECS 15-min Tutorial — Recording Outline

**What you're building:** an empty Godot project with GECS installed via submodule, one component, one system, one entity that visibly moves across the screen. Then add a second entity to prove it scales.

**Final scene:** Two Godot icons sliding across a 2D viewport.

---

## [0:00 – 0:30] Intro

> "GECS is an Entity Component System for Godot 4. We're going to install it as a git submodule, build the smallest possible example — a moving sprite — run it, and you'll have everything you need to start using ECS in your own game."

---

## [0:30 – 3:00] Install via submodule

**DO NOW:**

1. New empty Godot 4.x project. Close the editor.
2. Open a terminal in the project root.
3. Run:
   ```bash
   git init
   git submodule add -b release-v7.1.0 https://github.com/csprance/gecs.git addons/gecs
   ```
4. Reopen Godot.
5. **Project → Project Settings → Plugins** → enable **GECS**.
6. **Project Settings → Autoload** → confirm **ECS** is listed (auto-added by the plugin).

**Talking points while it installs:** components are data, systems are logic, the world ties them together, queries pick which entities a system runs on.

---

## [3:00 – 4:30] Project skeleton

**DO NOW:**

1. Create `main.tscn` with **Node2D** root, name it `Main`.
2. Add child node → search **World** → add it. Name stays `World`.
3. Attach a script `main.gd` to the Main root. Empty for now.
4. Save scene. Set as main scene when prompted.

> "World is a node that GECS provides — it holds entities and runs systems. Our `main.gd` will tell ECS which world is active."

---

## [4:30 – 6:30] The Component

**DO NOW:** create `c_velocity.gd` in project root (or `components/`).

```gdscript
class_name C_Velocity
extends Component

@export var direction: Vector2 = Vector2.ZERO
@export var speed: float = 200.0
```

> "Components are plain Resources. Just data — no logic. The `@export` properties show up in the inspector if you ever attach this to a scene."

---

## [6:30 – 9:30] The System

**DO NOW:** create `s_movement.gd`.

```gdscript
class_name MovementSystem
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Velocity])

func process(entities: Array[Entity], components: Array, delta: float) -> void:
    for entity in entities:
        var vel := entity.get_component(C_Velocity) as C_Velocity
        entity.position += vel.direction * vel.speed * delta
```

**Then in the editor:**
- Select the `World` node in `main.tscn`.
- Add child node → search **MovementSystem** → add it. (Or any `Node`, attach the script.)
- Save.

> "`query()` declares which entities this system cares about — anything with a velocity component. `process()` runs every frame against just those entities."

---

## [9:30 – 12:30] Wire it up — `main.gd`

**DO NOW:** open `main.gd` and replace with:

```gdscript
extends Node2D

@onready var world: World = $World

func _ready() -> void:
    ECS.world = world

    var player := Entity.new()
    var sprite := Sprite2D.new()
    sprite.texture = preload("res://icon.svg")
    player.add_child(sprite)
    player.position = Vector2(100, 200)

    var vel := C_Velocity.new()
    vel.direction = Vector2.RIGHT
    ECS.world.add_entity(player, [vel])

func _process(delta: float) -> void:
    ECS.process(delta)
```

> "Three things to point at: `ECS.world = world` connects the singleton to our scene's World. `add_entity` registers it AND adds it to the tree — don't `add_child` first. `ECS.process(delta)` runs every system every frame."

---

## [12:30 – 14:00] Run it + add a second entity

**DO NOW:**

1. Hit Play. Godot icon slides right across the screen. ✅
2. Stop. In `_ready()`, after the player block, add:

```gdscript
    var enemy := Entity.new()
    var enemy_sprite := Sprite2D.new()
    enemy_sprite.texture = preload("res://icon.svg")
    enemy_sprite.modulate = Color.RED
    enemy.add_child(enemy_sprite)
    enemy.position = Vector2(900, 400)

    var enemy_vel := C_Velocity.new()
    enemy_vel.direction = Vector2.LEFT
    enemy_vel.speed = 120.0
    ECS.world.add_entity(enemy, [enemy_vel])
```

3. Hit Play. Two icons, opposite directions, different speeds. **Same system handled both — that's the point.**

> "I never touched MovementSystem. Adding another entity with C_Velocity was enough. That's ECS."

---

## [14:00 – 15:00] Wrap

**Mention briefly:**
- **Debug viewer** — press F12 in editor / check the GECS dock for live entity inspection.
- **Next steps:** check `addons/gecs/docs/GETTING_STARTED.md` and `CORE_CONCEPTS.md` in the repo.
- Plug the Discord link / repo.

> "Everything else — relationships, observers, command buffers — builds on these three pieces: entity, component, system. Thanks for watching."

---

## Cheat-sheet (for the corner of your second monitor)

| Step | File | One-liner |
|---|---|---|
| 1 | terminal | `git submodule add -b release-v7.1.0 https://github.com/csprance/gecs.git addons/gecs` |
| 2 | Project Settings → Plugins | Enable **GECS** |
| 3 | `main.tscn` | Node2D + child World, attach `main.gd` |
| 4 | `c_velocity.gd` | `class_name C_Velocity extends Component` |
| 5 | `s_movement.gd` | `class_name MovementSystem extends System` — attach to child of World |
| 6 | `main.gd` | `ECS.world = world` → `add_entity(...)` → `ECS.process(delta)` |
| 7 | Play | sprite moves |
| 8 | second entity | proves the system scales |
