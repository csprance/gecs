## Capture the balls and sticks it on the first active paddle
class_name ScoreUiSystem
extends System


func query():
	return q.with_all([ScoreUi, UiVisibility]) # add required components


func process(entity: Entity, _delta: float) -> void:
	var score_ui: ScoreUiEntity = entity
	var game_state = GameStateUtils.get_game_state()
	
	score_ui.score_text.text = str(game_state.score)
	score_ui.lives_text.text = str(game_state.lives)
