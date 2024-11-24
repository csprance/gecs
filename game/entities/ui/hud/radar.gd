class_name Radar
extends Panel

func _ready():
    visible = false
    GameState.radar_toggled.connect(_on_radar_toggled)

func _on_radar_toggled():
    visible = not visible