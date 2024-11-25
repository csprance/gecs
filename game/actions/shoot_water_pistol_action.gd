class_name ShootWaterPistolAction
extends Action

func execute() -> void:
    var c_health = GameState.player.get_component(C_Health) as C_Health
    c_health.current = c_health.total
    GameState.health_changed.emit(c_health.current)