@icon('res://game/assets/icons/anchor.svg')
extends Node

@export_category("Scenes")
## The base scene for the projectile entity
@export var projectile_scene: PackedScene
## The base scene for the player entity
@export var player_scene: PackedScene
## The base scene for the enemy entity
@export var enemy_scene: PackedScene

@export_category("Entities")
@export var pickup_scene: PackedScene
@export var exit_door_scene: PackedScene
@export var main_menu_scene: PackedScene
@export var level_intro_screen: PackedScene

@export_category("Gameplay")


@export_category("Colors")
@export var color_black: Color = Color(0, 0, 0, 1)


@export_category("Levels")
@export var levels: Array[LevelResource]

func level_by_password(password: String) -> LevelResource:
	for level in levels:
		if level.password == password:
			return level
	
	return levels[0] # Default to the first level
	
