extends GdUnitTestSuite

const C_TestA = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_TestB = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_TestC = preload("res://addons/gecs/tests/components/c_test_c.gd")
const TestA = preload("res://addons/gecs/tests/entities/e_test_a.gd")
const TestB = preload("res://addons/gecs/tests/entities/e_test_b.gd")
const TestC = preload("res://addons/gecs/tests/entities/e_test_c.gd")

func test_add_and_get_component():
	var entity = auto_free(TestA.new())
	var comp = C_TestA.new()
	entity.add_component(comp)
	# Test that the component was added
	assert_bool(entity.has_component(C_TestA)).is_true()
	# Test retrieving the component
	var retrieved_component = entity.get_component(C_TestA)
	assert_str(type_string(typeof(retrieved_component))).is_equal(type_string(typeof(comp)))

func test_add_multiple_components_and_has():
	var entity = auto_free(TestB.new())
	var comp1 = C_TestA.new()
	var comp2 = C_TestB.new()
	entity.add_components([comp1, comp2])
	# Test that the components were added
	assert_bool(entity.has_component(C_TestA)).is_true()
	assert_bool(entity.has_component(C_TestB)).is_true()
	assert_bool(entity.has_component(C_TestC)).is_false()

func test_remove_component():
	var entity = auto_free(TestB.new())
	var comp = C_TestB.new()
	entity.add_component(comp)
	entity.remove_component(C_TestB)
	# Test that the component was removed
	assert_bool(entity.has_component(comp)).is_false()


func test_add_get_has_relationship():
	var entitya = auto_free(TestC.new())
	var entityb = auto_free(TestC.new())
	var r_testa_entitya = Relationship.new(C_TestA.new(), entitya)
	# Add the relationship
	entityb.add_relationship(r_testa_entitya)
	# Test that the relationship was added
	# With the actual relationship
	assert_bool(entityb.has_relationship(r_testa_entitya)).is_true()
	# with a matching relationship
	assert_bool(entityb.has_relationship(Relationship.new(C_TestA.new(), entitya))).is_true()
	# Test retrieving the relationship
	# with the actual relationship
	var inst_retrieved_relationship = entityb.get_relationship(r_testa_entitya)
	assert_str(type_string(typeof(inst_retrieved_relationship))).is_equal(type_string(typeof(r_testa_entitya)))
	# with a matching relationship
	var class_retrieved_relationship = entityb.get_relationship(Relationship.new(C_TestA.new(), entitya))
	assert_str(type_string(typeof(class_retrieved_relationship))).is_equal(type_string(typeof(r_testa_entitya)))
	assert_str(type_string(typeof(class_retrieved_relationship))).is_equal(type_string(typeof(Relationship.new(C_TestA.new(), entitya))))



