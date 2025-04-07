extends GdUnitTestSuite

const C_Likes = preload("res://addons/gecs/tests/components/c_test_a.gd")
const C_Loves = preload("res://addons/gecs/tests/components/c_test_b.gd")
const C_Eats = preload("res://addons/gecs/tests/components/c_test_c.gd")
const C_IsCryingInFrontOf = preload("res://addons/gecs/tests/components/c_test_d.gd")
const C_IsAttacking = preload("res://addons/gecs/tests/components/c_test_e.gd")
const Person = preload("res://addons/gecs/tests/entities/e_test_a.gd")
const TestB = preload("res://addons/gecs/tests/entities/e_test_b.gd")
const TestC = preload("res://addons/gecs/tests/entities/e_test_c.gd")


var runner : GdUnitSceneRunner
var world: World

var e_bob: Person
var e_alice: Person
var e_heather: Person
var e_apple: _GECSFOODTEST
var e_pizza: _GECSFOODTEST

func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world

func after_test():
	world.purge(false)
	
func before_test():
	e_bob = Person.new()
	e_bob.name = 'e_bob'
	e_alice = Person.new()
	e_alice.name = 'e_alice'
	e_heather = Person.new()
	e_heather.name = 'e_heather'
	e_apple = _GECSFOODTEST.new()
	e_apple.name = 'e_apple'
	e_pizza = _GECSFOODTEST.new()
	e_pizza.name = 'e_pizza'

	world.add_entity(e_bob)
	world.add_entity(e_alice)
	world.add_entity(e_heather)
	world.add_entity(e_apple)
	world.add_entity(e_pizza)

	# Create our relationships
	# bob likes alice
	e_bob.add_relationship(Relationship.new(C_Likes.new(), e_alice))
	# alice loves heather
	e_alice.add_relationship(Relationship.new(C_Loves.new(), e_heather))
	# heather likes ALL food both apples and pizza
	e_heather.add_relationship(Relationship.new(C_Likes.new(), _GECSFOODTEST))
	# heather eats 5 apples
	e_heather.add_relationship(Relationship.new(C_Eats.new(5), e_apple))
	# Alice attacks all food
	e_alice.add_relationship(Relationship.new(C_IsAttacking.new(), _GECSFOODTEST))
	# bob cries in front of everyone
	e_bob.add_relationship(Relationship.new(C_IsCryingInFrontOf.new(), Person))
	# Bob likes ONLY pizza even though there are other foods so he doesn't care for apples
	e_bob.add_relationship(Relationship.new(C_Likes.new(), e_pizza))

func test_with_relationships():
	# Any entity that likes alice
	var ents_that_likes_alice = Array(ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), e_alice)]).execute())
	assert_bool(ents_that_likes_alice.has(e_bob)).is_true() # bob likes alice
	assert_bool(ents_that_likes_alice.size() == 1).is_true() # just bob likes alice

func test_with_relationships_entity_wildcard_target_remove_relationship():
	# Any entity with any relations toward heather
	var ents_with_rel_to_heather = ECS.world.query.with_relationship([Relationship.new(null, e_heather)]).execute()
	assert_bool(Array(ents_with_rel_to_heather).has(e_alice)).is_true() # alice loves heather
	assert_bool(Array(ents_with_rel_to_heather).has(e_bob)).is_true() # bob is crying in front of people so he has a relation to heather because she's a person allegedly
	assert_bool(Array(ents_with_rel_to_heather).size() == 2).is_true() # 2 entities have relations to heather

	# alice no longer loves heather
	e_alice.remove_relationship(Relationship.new(C_Loves.new(), e_heather))
	# bob stops crying in front of people
	e_bob.remove_relationship(Relationship.new(C_IsCryingInFrontOf.new(), Person))
	ents_with_rel_to_heather = ECS.world.query.with_relationship([Relationship.new(null, e_heather)]).execute()
	assert_bool(Array(ents_with_rel_to_heather).size() == 0).is_true() # nobody has any relations with heather now :(

func test_with_relationships_entity_target():
	# Any entity that eats 5 apples
	assert_bool(Array(ECS.world.query.with_relationship([Relationship.new(C_Eats.new(5), e_apple)]).execute()).has(e_heather)).is_true() # heather eats 5 apples

func test_with_relationships_archetype_target():
	# any entity that likes the food entity archetype
	assert_bool(Array(ECS.world.query.with_relationship([Relationship.new(C_Eats.new(5), e_apple)]).execute()).has(e_heather)).is_true() # heather likes food

func test_with_relationships_wildcard_target():
	# Any entity that likes anything
	var ents_that_like_things = ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), null)]).execute()
	assert_bool(Array(ents_that_like_things).has(e_bob)).is_true() # bob likes alice
	assert_bool(Array(ents_that_like_things).has(e_heather)).is_true() # heather likes food

	# Any entity that likes anything also (Just a different way to write the query)
	var ents_that_like_things_also = ECS.world.query.with_relationship([Relationship.new(C_Likes.new())]).execute()
	assert_bool(Array(ents_that_like_things_also).has(e_bob)).is_true() # bob likes alice
	assert_bool(Array(ents_that_like_things_also).has(e_heather)).is_true() # heather likes food

func test_with_relationships_wildcard_relation():
	# Any entity with any relation to the Food archetype
	var any_relation_to_food = ECS.world.query.with_relationship([Relationship.new(ECS.wildcard, _GECSFOODTEST)]).execute()
	assert_bool(Array(any_relation_to_food).has(e_heather)).is_true() # heather likes food. but i mean cmon we all do

func test_archetype_and_entity():
	# we should be able to assign a specific entity as a target, and then match that by using the archetype class
	# we know that heather likes food, so we can use the archetype class to match that. She should like pizza and apples because they're both food and she likes food
	var entities_that_like_food = ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), _GECSFOODTEST)]).execute()
	assert_bool(entities_that_like_food.has(e_heather)).is_true() # heather likes food
	assert_bool(entities_that_like_food.has(e_bob)).is_true() # bob likes a specific food but still a food
	assert_bool(Array(entities_that_like_food).size() == 2).is_true() # only one entity likes all food 
	
	# Because heather likes food of course she likes apples
	var entities_that_like_apples = ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), e_apple)]).execute()
	assert_bool(entities_that_like_apples.has(e_heather)).is_true()

	# we also know that bob likes pizza which is also food but it's an entity so we can't use the archetype class to match that but we can match with the  entitiy pizza
	var entities_that_like_pizza = ECS.world.query.with_relationship([Relationship.new(C_Likes.new(), e_pizza)]).execute()
	assert_bool(entities_that_like_pizza.has(e_bob)).is_true() # bob only likes pizza
	assert_bool(entities_that_like_pizza.has(e_heather)).is_true() # heather likes food so of course she likes pizza
	
	
# # FIXME: This is not working
# func test_reverse_relationships_a():

# 	# Here I want to get the reverse of this relationship I want to get all the food being attacked.
# 	var food_being_attacked = ECS.world.query.with_reverse_relationship([Relationship.new(C_IsAttacking.new(), ECS.wildcard)]).execute()
# 	assert_bool(food_being_attacked.has(e_apple)).is_true() # The Apple is being attacked by alice because she's attacking all food
# 	assert_bool(food_being_attacked.has(e_pizza)).is_true() # The pizza is being attacked by alice because she's attacking all food
# 	assert_bool(Array(food_being_attacked).size() == 2).is_true() # pizza and apples are UNDER ATTACK

# # FIXME: This is not working
# func test_reverse_relationships_b():
# 	# Query 2: Find all entities that are the target of any relationship with Person archetype
# 	var entities_with_relations_to_people = ECS.world.query.with_reverse_relationship([Relationship.new(ECS.wildcard, Person)]).execute()
# 	# This returns any entity that is the TARGET of any relationship where Person is specified
# 	assert_bool(Array(entities_with_relations_to_people).has(e_heather)).is_true() # heather is loved by alice
# 	assert_bool(Array(entities_with_relations_to_people).has(e_alice)).is_true() # alice is liked by bob
# 	assert_bool(Array(entities_with_relations_to_people).size() == 2).is_true() # only two people are the targets of relations with other persons
