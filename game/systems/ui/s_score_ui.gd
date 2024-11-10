## Capture the balls and sticks it on the first active paddle
class_name ScoreUiSystem
extends System


func query():
	return q.with_all([C_ScoreUi, C_UiVisibility]) # add required components


func process(entity: Entity, _delta: float) -> void:
	var score_ui: ScoreUi = entity
	
	score_ui.score_text.text = str(GameState.score)
	score_ui.lives_text.text = str(GameState.lives)
