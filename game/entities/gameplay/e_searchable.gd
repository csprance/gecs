class_name Searchable
extends Entity

func on_ready() -> void:
	# we probably want to sync the component transform to the node transform
	Utils.sync_transform(self)
