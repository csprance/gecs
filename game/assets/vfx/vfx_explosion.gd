class_name VfxExplosion
extends Entity

# Remember components only hold data to operate on and mutate
# They don't provide functionality outside of data operations on itself
func on_ready():
	Utils.sync_transform(self)
