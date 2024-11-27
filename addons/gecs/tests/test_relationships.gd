extends GdUnitTestSuite

const C_Likes = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_Loves = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_Eats = preload("res://addons/gecs/tests/components/c_test_c.gd")
const C_TestD = preload("res://addons/gecs/tests/components/c_test_d.gd")
const C_TestE = preload("res://addons/gecs/tests/components/c_test_e.gd")
const Person = preload("res://addons/gecs/tests/entities/e_test_a.gd")
const TestB = preload("res://addons/gecs/tests/entities/e_test_b.gd")
const TestC = preload("res://addons/gecs/tests/entities/e_test_c.gd")
const Food = preload("res://addons/gecs/tests/entities/e_test_d.gd")

var runner : GdUnitSceneRunner
var world: World

func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world

func after_test():
	world.purge(false)

func test_relationships():
	var e_bob = Person.new()
	var e_alice = Person.new()
	var e_heather = Person.new()
	var e_apple = Food.new()

	world.add_entity(e_bob)
	world.add_entity(e_alice)
	world.add_entity(e_heather)
	world.add_entity(e_apple)

	# Create our relationships
	# bob likes alice
	e_bob.add_relationship(Relationship.new(C_Likes.new(), e_alice))
	# alice loves heather
	e_alice.add_relationship(Relationship.new(C_Loves.new(), e_heather))
	# heather likes food
	e_heather.add_relationship(Relationship.new(C_Likes.new(), Food))
	# heather eats 5 apples
	e_heather.add_relationship(Relationship.new(C_Eats.new(5), e_apple))

	# Any entity that likes alice
	var ents_that_likes_alice = Array(ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), e_alice)]).execute())
	assert_bool(ents_that_likes_alice.has(e_bob)).is_true() # bob likes alice
	assert_bool(ents_that_likes_alice.size() == 1).is_true() # just bob likes alice

	# Any entity with any relations toward heather
	var ents_with_rel_to_heather = ECS.world.query.with_relationship([Relationship.new(null, e_heather)]).execute()
	assert_bool(Array(ents_with_rel_to_heather).has(e_alice)).is_true() # alice loves heather
	assert_bool(Array(ents_with_rel_to_heather).size() == 1).is_true() # only alice loves heather

	# alice no longer loves heather
	e_alice.remove_relationship(Relationship.new(C_Loves.new(), e_heather))
	ents_with_rel_to_heather = ECS.world.query.with_relationship([Relationship.new(null, e_heather)]).execute()
	assert_bool(Array(ents_with_rel_to_heather).size() == 0).is_true() # alice no longer loves heather

	# Any entity that eats 5 apples
	assert_bool(Array(ECS.world.query.with_relationship([Relationship.new(C_Eats.new(5), e_apple)]).execute()).has(e_heather)).is_true() # heather eats 5 apples

	# any entity that likes the food entity archetype
	assert_bool(Array(ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), Food)]).execute()).has(e_heather)).is_true() # heather likes food

	# Any entity that likes anything
	var ents_that_like_things = ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), null)]).execute()
	assert_bool(Array(ents_that_like_things).has(e_bob)).is_true() # bob likes alice
	assert_bool(Array(ents_that_like_things).has(e_heather)).is_true() # heather likes food

	var ents_that_like_things_also = ECS.world.query.with_relationship([Relationship.new(C_Likes.new())]).execute()
	assert_bool(Array(ents_that_like_things_also).has(e_bob)).is_true() # bob likes alice
	assert_bool(Array(ents_that_like_things_also).has(e_heather)).is_true() # heather likes food

	# Any entity with any relation to the Food archetype
	var any_relation_to_food = ECS.world.query.with_relationship([Relationship.new(null, Food)]).execute()
	assert_bool(Array(any_relation_to_food).has(e_heather)).is_true() # heather likes food
