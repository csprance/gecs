class_name E_ComplexSerializationTest
extends Entity


func define_components() -> Array:
	return [
		C_ComplexSerializationTest.new(
			[10, 20, 30],
			["alpha", "beta", "gamma"],
			{"hp": 100, "mp": 50, "items": 3},
			[],
			{}
		),
		C_SerializationTest.new(999, 2.718, "complex_entity", false, Vector2(5.0, 10.0), Vector3(1.0, 2.0, 3.0), Color.BLUE)
	]