class_name Trampoline
extends Entity


@onready var bounce_center: Locator3D = %BounceCenter
@onready var exit_right: Locator3D = %ExitRight
@onready var exit_top: Locator3D = %ExitTop
@onready var exit_left: Locator3D = %ExitLeft
@onready var exit_bottom: Locator3D = %ExitBottom


func on_ready():
	Utils.sync_transform(self)
