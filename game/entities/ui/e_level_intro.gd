class_name LevelIntroUI
extends Entity

@export var level: LevelResource
@export var callback: Callable

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var level_title_label: RichTextLabel = %LevelTitle
@onready var level_number_label: RichTextLabel = %LevelNumber


func on_ready():
	level_number_label.text = level.name
	level_title_label.text = level.description
	animation_player.play('fall')


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == 'fall':
		Constants.load_level(level)
