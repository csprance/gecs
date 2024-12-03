extends Node

@export_category("Scenes")
## The base scene for the projectile entity
@export var projectile_scene: PackedScene
## The base scene for the player entity
@export var player_scene: PackedScene
## The base scene for the enemy entity
@export var enemy_scene: PackedScene

@export_category("Gameplay")
## How fast the player can move
@export var player_speed: float = 200.0
## How fast the zombies can move
@export var zombie_speed: float = 100.0
## How much faster the zombies can sprint towards you
@export var zombie_sprint_mult: float = 200.0

@export_category("Colors")
@export var color_black: Color = Color(0, 0, 0, 1)


@export_category("Levels")
@export var levels: Array[LevelResource]