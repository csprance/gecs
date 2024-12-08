class_name LevelResource
extends Resource

## The name of the level
@export var name: String = ""
## The quick description of the level
@export var description: String = ""
## The scene for the level
@export var packed_scene: PackedScene
## The password for the level you are shown after beating it. If empty this level has no password
@export var password: String = ''