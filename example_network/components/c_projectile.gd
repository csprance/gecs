class_name C_Projectile
extends Component
## Projectile component - spawn-only sync (no continuous updates).
## Color and damage are synced at spawn time, then clients simulate locally.

## Projectile color (matches player color for visual identification)
@export var projectile_color: Color = Color.WHITE

## Damage value (for demonstration, not used in this example)
@export var damage: int = 10
