## A Ui entity represent a UI element that has a CanvasLayer if we add a UiVisibility
## Component to the entity it will show up in the world
class_name ScoreUi
extends Ui

@onready var score_text: RichTextLabel = %ScoreValue
@onready var lives_text: RichTextLabel = %LivesValue
