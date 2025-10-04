class_name E_SerializationTest
extends Entity


func define_components() -> Array:
	return [
		C_SerializationTest.new(),
		C_Persistent.new("TestPlayer", 5, 75.0, Vector2(10.0, 20.0), ["sword", "potion"])
	]