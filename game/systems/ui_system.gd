class_name UiSystem
extends System


func _init():
	required_components = [UiVisibility] # add required components


func process(entity: Entity, delta: float) -> void:
	# Find all the UI with the visiblity component
	var visibility = entity.get_component(UiVisibility) as UiVisibility
	# Show them if it says true otherwise hide them
	
	pass # code here....

