class_name HealthBars
extends BoxContainer

@onready var health_pips = [
	$HealthPip1,
	$HealthPip2,
	$HealthPip3,
	$HealthPip4,
	$HealthPip5,
	$HealthPip6,
	$HealthPip7,
	$HealthPip8,
	$HealthPip9,
	$HealthPip10 
]

var positive_style = preload("res://game/entities/ui/hud/health_pip_positive.tres")
var negative_style = preload("res://game/entities/ui/hud/health_pip_negative.tres")

func _ready() -> void:
	GameState.health_changed.connect(_on_health_changed)
	GameState.health_changed.emit(10)

func _on_health_changed(health: int) -> void:
	set_health(health)

func set_health(amount: int):
	# Turn them all off
	for i in range(health_pips.size()):
		turn_off_pip(health_pips[i])

	# Turn some back on
	for i in range(amount):
		turn_on_pip(health_pips[i])

func turn_off_pip(pip: Panel):
	pip.add_theme_stylebox_override("panel", negative_style)

func turn_on_pip(pip: Panel):
	pip.add_theme_stylebox_override("panel", positive_style)
