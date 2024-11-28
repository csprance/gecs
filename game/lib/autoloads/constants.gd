extends Node

@export_category("Scenes")
## The base scene for the projectile entity
@export var ball_scene: PackedScene
## The base scene for the player entity
@export var paddle_scene: PackedScene


@export_category("Gameplay")
## How fast the player can move
@export var paddle_speed: float = 200.0
## How fast the zombies can move
@export var ball_speed: float = 100.0

@export_category("Colors")
@export var color_bg: Color = Color(0, 0, 0, 1)
@export var color_fg: Color = Color(1, 1, 1, 1)
@export var color_extra: Color = Color(0, 1, 0, 1)